import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

import '../services/route_path_planner_service.dart';
import 'route_recorder_screen.dart';

const _transportModes = <String>[
  'Walking',
  'Bicycle',
  'Motorcycle',
  'Car',
  'Bus',
  'Taxi',
  'Tricycle',
];

class _PlaceResult {
  const _PlaceResult({required this.point, required this.name});

  final ll.LatLng point;
  final String name;
}

class _RouteOption {
  const _RouteOption({
    required this.label,
    required this.transportHint,
    required this.segments,
    required this.hasBusStopsNearEndpoints,
    required this.score,
  });

  final String label;
  final String transportHint;
  final List<PathSegment> segments;
  final bool hasBusStopsNearEndpoints;
  final double score;

  double get totalDistance =>
      segments.fold<double>(0.0, (sum, segment) => sum + segment.distance);

  int get totalDuration =>
      segments.fold<int>(0, (sum, segment) => sum + segment.duration);

  List<ll.LatLng> get points {
    final all = <ll.LatLng>[];
    for (final segment in segments) {
      all.addAll(segment.points);
    }
    return all;
  }
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.userId});

  final int? userId;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  ll.LatLng? _start;
  ll.LatLng? _destination;
  bool _isLoadingSuggestions = false;
  bool _canShowUserLocation = false;
  gmaps.GoogleMapController? _mapController;
  ll.LatLng? _pendingCameraTarget;
  double _pendingCameraZoom = 15.0;
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  List<_RouteOption> _routeOptions = const [];
  int? _bestRouteIndex;
  int? _selectedRouteIndex;
  String? _selectedTransportMode;

  gmaps.LatLng _toGoogleLatLng(ll.LatLng point) {
    return gmaps.LatLng(point.latitude, point.longitude);
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    if (hrs == 0) return '$mins min';
    return '${hrs}h ${remMins}m';
  }

  Color _optionColor(int index) {
    if (_selectedRouteIndex == index) return Colors.blueAccent;
    if (_bestRouteIndex == index) return Colors.green;
    return Colors.grey.shade500;
  }

  double _scoreRoute({
    required List<PathSegment> segments,
    required bool hasBusStops,
    required String hint,
  }) {
    final totalDistance =
        segments.fold<double>(0.0, (sum, segment) => sum + segment.distance);
    final totalDuration =
        segments.fold<int>(0, (sum, segment) => sum + segment.duration);

    var score = totalDuration.toDouble();
    score += totalDistance / 120.0;

    if (hint == 'walking' && totalDistance > 3500) {
      score += 900;
    }
    if (hint == 'bicycle' && totalDistance > 12000) {
      score += 500;
    }
    if (hint == 'bus' && !hasBusStops) {
      score += 700;
    }

    return score;
  }

  PathSegment _fallbackSegment(
    ll.LatLng start,
    ll.LatLng destination,
    String mode,
  ) {
    final distanceCalc = ll.Distance();
    final dist = distanceCalc(start, destination);

    final speedMps = switch (mode) {
      'walking' => 1.4,
      'bicycle' => 4.5,
      'bus' => 6.0,
      _ => 8.5,
    };

    return PathSegment(
      transportMode: mode,
      points: [start, destination],
      distance: dist,
      duration: (dist / speedMps).round(),
    );
  }

  Future<_PlaceResult?> _geocodeLocation(String query) async {
    if (query.trim().isEmpty) return null;

    final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {
        'format': 'json',
        'q': query,
        'limit': '1',
      },
    );

    try {
      final resp = await http.get(uri, headers: {'User-Agent': 'SafeRouteDev/0.1'});
      if (resp.statusCode != 200) return null;

      final List<dynamic> data = json.decode(resp.body) as List<dynamic>;
      if (data.isEmpty) return null;

      final item = data.first as Map<String, dynamic>;
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;

      final fullName = (item['display_name']?.toString() ?? query).trim();
      final name = fullName.split(',').first.trim();

      return _PlaceResult(
        point: ll.LatLng(lat, lon),
        name: name.isEmpty ? query : name,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocodeName(ll.LatLng point) async {
    final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
      queryParameters: {
        'format': 'json',
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
      },
    );

    try {
      final resp = await http.get(uri, headers: {'User-Agent': 'SafeRouteDev/0.1'});
      if (resp.statusCode != 200) return null;

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final displayName = data['display_name']?.toString();
      if (displayName == null || displayName.trim().isEmpty) return null;
      return displayName.split(',').first.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRouteSuggestions() async {
    final start = _start;
    final destination = _destination;
    if (start == null || destination == null) return;

    if (!mounted) return;
    setState(() {
      _isLoadingSuggestions = true;
      _routeOptions = const [];
      _bestRouteIndex = null;
      _selectedRouteIndex = null;
      _selectedTransportMode = null;
    });

    final busNearStart = await RoutePathPlannerService.hasNearbyBusStop(start);
    final busNearDestination =
        await RoutePathPlannerService.hasNearbyBusStop(destination);
    final hasBusStops = busNearStart || busNearDestination;

    final futures = <Future<List<PathSegment>?>>[
      RoutePathPlannerService.calculatePath(start, destination, 'car'),
      RoutePathPlannerService.calculatePath(start, destination, 'bicycle'),
      RoutePathPlannerService.calculatePath(start, destination, 'walking'),
    ];

    final labels = <String>['Fastest road', 'Balanced', 'Eco walk'];
    final hints = <String>['car', 'bicycle', 'walking'];

    if (hasBusStops) {
      futures.add(RoutePathPlannerService.calculatePath(start, destination, 'bus'));
      labels.add('Bus friendly');
      hints.add('bus');
    }

    final results = await Future.wait(futures);
    final options = <_RouteOption>[];

    for (var i = 0; i < results.length; i++) {
      final mode = hints[i];
      final segments = results[i] ?? [_fallbackSegment(start, destination, mode)];
      options.add(
        _RouteOption(
          label: labels[i],
          transportHint: mode,
          segments: segments,
          hasBusStopsNearEndpoints: hasBusStops,
          score: _scoreRoute(
            segments: segments,
            hasBusStops: hasBusStops,
            hint: mode,
          ),
        ),
      );
    }

    if (options.length < 3) {
      final fallbackModes = <String>['car', 'bicycle', 'walking'];
      while (options.length < 3) {
        final mode = fallbackModes[options.length % fallbackModes.length];
        final segments = [_fallbackSegment(start, destination, mode)];
        options.add(
          _RouteOption(
            label: 'Alternative ${options.length + 1}',
            transportHint: mode,
            segments: segments,
            hasBusStopsNearEndpoints: hasBusStops,
            score: _scoreRoute(
              segments: segments,
              hasBusStops: hasBusStops,
              hint: mode,
            ),
          ),
        );
      }
    }

    var bestIndex = 0;
    var bestScore = options.first.score;
    for (var i = 1; i < options.length; i++) {
      if (options[i].score < bestScore) {
        bestScore = options[i].score;
        bestIndex = i;
      }
    }

    if (!mounted) return;
    setState(() {
      _routeOptions = options;
      _bestRouteIndex = bestIndex;
      _selectedRouteIndex = bestIndex;
      _isLoadingSuggestions = false;
    });
  }

  List<String> _recommendedModes(_RouteOption option) {
    final distanceKm = option.totalDistance / 1000.0;
    final recommendations = <String>{};

    if (distanceKm <= 2) {
      recommendations.addAll(<String>['Walking', 'Bicycle', 'Motorcycle']);
    } else if (distanceKm <= 8) {
      recommendations.addAll(<String>['Bicycle', 'Motorcycle', 'Car', 'Taxi']);
    } else {
      recommendations.addAll(<String>['Car', 'Taxi', 'Motorcycle']);
    }

    if (distanceKm > 10) {
      recommendations.remove('Walking');
      recommendations.add('Bus');
    }

    if (option.hasBusStopsNearEndpoints) {
      recommendations.add('Bus');
      recommendations.add('Tricycle');
    }

    recommendations.add('Car');

    final ordered = <String>[];
    for (final mode in _transportModes) {
      if (recommendations.contains(mode)) ordered.add(mode);
    }
    return ordered;
  }

  Future<void> _moveCamera(ll.LatLng target, {double zoom = 16.0}) async {
    _pendingCameraTarget = target;
    _pendingCameraZoom = zoom;

    final controller = _mapController;
    if (controller == null) return;

    await controller.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: _toGoogleLatLng(target),
          zoom: zoom,
        ),
      ),
    );
  }

  void _onMapCreated(gmaps.GoogleMapController controller) {
    _mapController = controller;
    final target = _pendingCameraTarget;
    if (target != null) {
      controller.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(
            target: _toGoogleLatLng(target),
            zoom: _pendingCameraZoom,
          ),
        ),
      );
    }
  }

  Future<void> _setOrigin(ll.LatLng point, {String? preferredName}) async {
    final resolvedName = preferredName ?? await _reverseGeocodeName(point);
    if (!mounted) return;

    setState(() {
      _start = point;
      _originController.text = resolvedName?.isNotEmpty == true
          ? resolvedName!
          : 'Selected location';
      _routeOptions = const [];
      _bestRouteIndex = null;
      _selectedRouteIndex = null;
      _selectedTransportMode = null;
    });

    if (_start != null && _destination != null) {
      await _loadRouteSuggestions();
    }
  }

  Future<void> _setDestination(ll.LatLng point, {String? preferredName}) async {
    final resolvedName = preferredName ?? await _reverseGeocodeName(point);
    if (!mounted) return;

    setState(() {
      _destination = point;
      _destinationController.text = resolvedName?.isNotEmpty == true
          ? resolvedName!
          : 'Selected location';
      _routeOptions = const [];
      _bestRouteIndex = null;
      _selectedRouteIndex = null;
      _selectedTransportMode = null;
    });

    if (_start != null && _destination != null) {
      await _loadRouteSuggestions();
    }
  }

  Future<void> _resolveOrigin() async {
    final query = _originController.text.trim();
    final found = await _geocodeLocation(query);
    if (found == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find the origin location')),
        );
      }
      return;
    }

    await _moveCamera(found.point, zoom: 16.0);
    await _setOrigin(found.point, preferredName: found.name);
  }

  Future<void> _resolveDestination() async {
    final query = _destinationController.text.trim();
    final found = await _geocodeLocation(query);
    if (found == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find the destination location')),
        );
      }
      return;
    }

    await _moveCamera(found.point, zoom: 16.0);
    await _setDestination(found.point, preferredName: found.name);
  }

  Future<void> _onTap(ll.LatLng latlng) async {
    if (_start == null) {
      await _setOrigin(latlng);
      return;
    }

    if (_destination == null) {
      await _setDestination(latlng);
      return;
    }

    // Once both points are set, the next tap updates destination for quick replanning.
    await _setDestination(latlng);
  }

  Future<void> _bootstrapLocation() async {
    final pos = await _determinePosition();
    if (pos == null || !mounted) return;

    final userLatLng = ll.LatLng(pos.latitude, pos.longitude);
    await _moveCamera(userLatLng, zoom: 16.0);
    await _setOrigin(userLatLng, preferredName: 'My current location');

    if (!mounted) return;
    setState(() {
      _canShowUserLocation = true;
    });
  }

  Future<Position?> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _showTransportCard() async {
    final selectedIndex = _selectedRouteIndex;
    if (selectedIndex == null || selectedIndex >= _routeOptions.length) return;
    final option = _routeOptions[selectedIndex];
    final availableModes = _recommendedModes(option);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, modalSetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm Route',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('From: ${_originController.text.trim()}'),
                Text('To: ${_destinationController.text.trim()}'),
                const SizedBox(height: 8),
                Text('Route: ${option.label}${selectedIndex == _bestRouteIndex ? ' (Best)' : ''}'),
                Text('Distance: ${_formatDistance(option.totalDistance)}'),
                Text('Duration: ${_formatDuration(option.totalDuration)}'),
                Text(
                  option.hasBusStopsNearEndpoints
                      ? 'Bus stops: available near endpoints'
                      : 'Bus stops: not detected near endpoints',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Available transportation modes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in availableModes)
                      ChoiceChip(
                        label: Text(mode),
                        selected: _selectedTransportMode == mode,
                        onSelected: (_) {
                          modalSetState(() {
                            _selectedTransportMode = mode;
                          });
                          setState(() {
                            _selectedTransportMode = mode;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selectedTransportMode == null
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => RouteRecorderScreen(
                                  startPoint: _start!,
                                  destination: _destination!,
                                  startLocationName: _originController.text.trim(),
                                  endLocationName: _destinationController.text.trim(),
                                  transportMode: _selectedTransportMode!,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                    child: const Text('Start Recording'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrapLocation();
  }

  @override
  Widget build(BuildContext context) {
    final hasBothPoints = _start != null && _destination != null;
    final hasSuggestedRoutes = _routeOptions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick start and destination'),
      ),
      body: Stack(
        children: [
          gmaps.GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: gmaps.CameraPosition(
              target: _toGoogleLatLng(_start ?? ll.LatLng(0, 0)),
              zoom: _start == null ? 2.0 : 16.0,
            ),
            onTap: (latlng) => _onTap(ll.LatLng(latlng.latitude, latlng.longitude)),
            myLocationEnabled: _canShowUserLocation,
            myLocationButtonEnabled: _canShowUserLocation,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              if (_start != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('start'),
                  position: _toGoogleLatLng(_start!),
                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                    gmaps.BitmapDescriptor.hueGreen,
                  ),
                  infoWindow: gmaps.InfoWindow(
                    title: _originController.text.trim().isEmpty
                        ? 'Origin'
                        : _originController.text.trim(),
                  ),
                ),
              if (_destination != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('destination'),
                  position: _toGoogleLatLng(_destination!),
                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                    gmaps.BitmapDescriptor.hueRed,
                  ),
                  infoWindow: gmaps.InfoWindow(
                    title: _destinationController.text.trim().isEmpty
                        ? 'Destination'
                        : _destinationController.text.trim(),
                  ),
                ),
            },
            polylines: {
              for (var index = 0; index < _routeOptions.length; index++)
                gmaps.Polyline(
                  polylineId: gmaps.PolylineId('option_$index'),
                  points: _routeOptions[index].points.map(_toGoogleLatLng).toList(),
                  width: _selectedRouteIndex == index ? 5 : 3,
                  color: _optionColor(index),
                ),
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _originController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Origin location name',
                      prefixIcon: const Icon(Icons.trip_origin),
                      suffixIcon: IconButton(
                        onPressed: _resolveOrigin,
                        icon: const Icon(Icons.search),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _resolveOrigin(),
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _destinationController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Destination location name',
                      prefixIcon: const Icon(Icons.place),
                      suffixIcon: IconButton(
                        onPressed: _resolveDestination,
                        icon: const Icon(Icons.search),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _resolveDestination(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 128,
            left: 12,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.92),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _isLoadingSuggestions
                    ? const SizedBox(
                        width: 150,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Building routes...',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        _start == null
                            ? 'Tap/search origin'
                            : _destination == null
                                ? 'Tap/search destination'
                                : hasSuggestedRoutes
                                  ? 'Choose one of ${_routeOptions.length} route options'
                                    : 'Ready to build route options',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
          if (hasSuggestedRoutes)
            Positioned(
              left: 12,
              right: 12,
              bottom: 90,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withValues(alpha: 0.96),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Route Suggestions',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _routeOptions.length; i++)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedRouteIndex = i;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedRouteIndex == i
                                    ? Colors.blueAccent
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_routeOptions[i].label}${_bestRouteIndex == i ? ' (Best)' : ''}',
                                    style: TextStyle(
                                      fontWeight: _bestRouteIndex == i
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_formatDistance(_routeOptions[i].totalDistance)} • ${_formatDuration(_routeOptions[i].totalDuration)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _resolveOrigin,
                icon: const Icon(Icons.trip_origin),
                label: const Text('Resolve origin'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _resolveDestination,
                icon: const Icon(Icons.place),
                label: const Text('Resolve destination'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: hasBothPoints && hasSuggestedRoutes
                  ? _showTransportCard
                  : null,
              child: const Text('Confirm route'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}

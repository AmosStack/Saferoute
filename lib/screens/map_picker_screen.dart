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

const _primaryTransportCards = <_TransportCardData>[
  _TransportCardData(label: 'Walking', icon: Icons.directions_walk, mode: 'walking'),
  _TransportCardData(label: 'Bicycle', icon: Icons.pedal_bike, mode: 'bicycle'),
  _TransportCardData(label: 'Car', icon: Icons.directions_car, mode: 'car'),
  _TransportCardData(label: 'Bus', icon: Icons.directions_bus, mode: 'bus'),
];

class _TransportCardData {
  const _TransportCardData({required this.label, required this.icon, required this.mode});

  final String label;
  final IconData icon;
  final String mode;
}

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
    required this.safetyScore,
  });

  final String label;
  final String transportHint;
  final List<PathSegment> segments;
  final bool hasBusStopsNearEndpoints;
  final double safetyScore;

  double get totalDistance => segments.fold<double>(0.0, (sum, segment) => sum + segment.distance);
  int get totalDuration => segments.fold<int>(0, (sum, segment) => sum + segment.duration);
  List<ll.LatLng> get points {
    final all = <ll.LatLng>[];
    for (final segment in segments) {
      all.addAll(segment.points);
    }
    return all;
  }
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.userId, this.embedded = false});

  final int? userId;
  final bool embedded;

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

  gmaps.LatLng _toGoogleLatLng(ll.LatLng point) => gmaps.LatLng(point.latitude, point.longitude);

  String _formatDistance(double meters) => meters < 1000 ? '${meters.toStringAsFixed(0)} m' : '${(meters / 1000).toStringAsFixed(2)} km';

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return hrs == 0 ? '$mins min' : '${hrs}h ${remMins}m';
  }

  Color _optionColor(int index) {
    if (_selectedRouteIndex == index) return Colors.blueAccent;
    if (_bestRouteIndex == index) return const Color(0xFF0E7C7B);
    return Colors.grey.shade500;
  }

  double _scoreRoute({
    required List<PathSegment> segments,
    required bool hasBusStops,
    required String hint,
  }) {
    final totalDistance = segments.fold<double>(0.0, (sum, segment) => sum + segment.distance);
    final totalDuration = segments.fold<int>(0, (sum, segment) => sum + segment.duration);

    var score = 100.0;
    score -= totalDuration / 90.0;
    score -= totalDistance / 2500.0;

    if (hint == 'walking') {
      score += totalDistance <= 1800 ? 12 : -18;
      score += totalDuration <= 1200 ? 4 : -10;
    } else if (hint == 'bicycle') {
      score += totalDistance <= 8000 ? 10 : -14;
    } else if (hint == 'bus') {
      score += hasBusStops ? 18 : -40;
      score += segments.length <= 3 ? 6 : -4;
    } else if (hint == 'car' || hint == 'taxi') {
      score += 8;
    } else if (hint == 'motorcycle' || hint == 'tricycle') {
      score += 4;
    }

    return score.clamp(0, 100).toDouble();
  }

  PathSegment _fallbackSegment(ll.LatLng start, ll.LatLng destination, String mode) {
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
      queryParameters: {'format': 'json', 'q': query, 'limit': '1'},
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

      return _PlaceResult(point: ll.LatLng(lat, lon), name: name.isEmpty ? query : name);
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

  Future<void> _moveCamera(ll.LatLng target, {double zoom = 16.0}) async {
    _pendingCameraTarget = target;
    _pendingCameraZoom = zoom;

    final controller = _mapController;
    if (controller == null) return;

    await controller.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(target: _toGoogleLatLng(target), zoom: zoom),
      ),
    );
  }

  void _onMapCreated(gmaps.GoogleMapController controller) {
    _mapController = controller;
    final target = _pendingCameraTarget;
    if (target != null) {
      controller.animateCamera(
        gmaps.CameraUpdate.newCameraPosition(
          gmaps.CameraPosition(target: _toGoogleLatLng(target), zoom: _pendingCameraZoom),
        ),
      );
    }
  }

  Future<void> _setOrigin(ll.LatLng point, {String? preferredName}) async {
    final resolvedName = preferredName ?? await _reverseGeocodeName(point);
    if (!mounted) return;

    setState(() {
      _start = point;
      _originController.text = resolvedName?.isNotEmpty == true ? resolvedName! : 'Selected location';
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
      _destinationController.text = resolvedName?.isNotEmpty == true ? resolvedName! : 'Selected location';
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find the origin location')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find the destination location')));
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
    });

    final busNearStart = await RoutePathPlannerService.hasNearbyBusStop(start);
    final busNearDestination = await RoutePathPlannerService.hasNearbyBusStop(destination);
    final hasBusStops = busNearStart || busNearDestination;

    final candidateModes = <String>[];
    final selectedMode = _selectedTransportMode?.toLowerCase();
    if (selectedMode != null && selectedMode.isNotEmpty) {
      candidateModes.add(selectedMode);
    }
    candidateModes.addAll(<String>['car', 'bicycle', 'walking']);
    if (hasBusStops) candidateModes.add('bus');

    final uniqueModes = <String>[];
    for (final mode in candidateModes) {
      if (!uniqueModes.contains(mode)) uniqueModes.add(mode);
    }

    final labels = <String, String>{
      'car': 'Fastest road',
      'bicycle': 'Balanced',
      'walking': 'Eco walk',
      'bus': 'Bus friendly',
    };
    if (selectedMode != null) {
      labels[selectedMode] = 'Selected transport';
    }

    final results = await Future.wait(
      uniqueModes.map((mode) => RoutePathPlannerService.calculatePath(start, destination, mode)),
    );

    final options = <_RouteOption>[];
    for (var i = 0; i < uniqueModes.length; i++) {
      final mode = uniqueModes[i];
      final segments = results[i] ?? [_fallbackSegment(start, destination, mode)];
      options.add(
        _RouteOption(
          label: labels[mode] ?? 'Alternative ${i + 1}',
          transportHint: mode,
          segments: segments,
          hasBusStopsNearEndpoints: hasBusStops,
          safetyScore: _scoreRoute(segments: segments, hasBusStops: hasBusStops, hint: mode),
        ),
      );
    }

    while (options.length < 3) {
      final mode = ['car', 'bicycle', 'walking'][options.length % 3];
      final segments = [_fallbackSegment(start, destination, mode)];
      options.add(
        _RouteOption(
          label: 'Alternative ${options.length + 1}',
          transportHint: mode,
          segments: segments,
          hasBusStopsNearEndpoints: hasBusStops,
          safetyScore: _scoreRoute(segments: segments, hasBusStops: hasBusStops, hint: mode),
        ),
      );
    }

    options.sort((a, b) => b.safetyScore.compareTo(a.safetyScore));
    final bestIndex = 0;

    if (!mounted) return;
    setState(() {
      _routeOptions = options;
      _bestRouteIndex = bestIndex;
      _selectedRouteIndex = bestIndex;
      _isLoadingSuggestions = false;
      _selectedTransportMode ??= options[bestIndex].transportHint;
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

  Future<void> _showConfirmSheet() async {
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
                Text('Confirm Route', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('From: ${_originController.text.trim()}'),
                Text('To: ${_destinationController.text.trim()}'),
                const SizedBox(height: 8),
                Text('Route: ${option.label}${selectedIndex == _bestRouteIndex ? ' (Safest)' : ''}'),
                Text('Safety score: ${option.safetyScore.toStringAsFixed(0)} / 100'),
                Text('Distance: ${_formatDistance(option.totalDistance)}'),
                Text('Duration: ${_formatDuration(option.totalDuration)}'),
                Text(
                  option.hasBusStopsNearEndpoints ? 'Bus stops: available near endpoints' : 'Bus stops: not detected near endpoints',
                ),
                const SizedBox(height: 12),
                const Text('Available transportation modes', style: TextStyle(fontWeight: FontWeight.w700)),
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
                                  plannedRoutePoints: option.points,
                                  plannedRouteLabel: option.label,
                                  plannedRouteSafetyScore: option.safetyScore,
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                    child: const Text('Start'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportCardGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white.withValues(alpha: 0.94);
    final textColor = isDark ? Colors.white : Colors.black;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: [
        for (final card in _primaryTransportCards)
          InkWell(
            onTap: () {
              setState(() {
                _selectedTransportMode = card.mode;
              });
              if (_start != null && _destination != null) {
                _loadRouteSuggestions();
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: _selectedTransportMode == card.mode ? const Color(0xFF0E7C7B).withValues(alpha: 0.22) : surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedTransportMode == card.mode ? const Color(0xFF0E7C7B) : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF0E7C7B).withValues(alpha: 0.12),
                    child: Icon(card.icon, color: const Color(0xFF0E7C7B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      card.label,
                      style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 4,
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose transport mode first or later', style: TextStyle(fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 10),
                _buildTransportCardGrid(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          elevation: 4,
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          child: TextField(
            controller: _originController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Origin location name',
              prefixIcon: const Icon(Icons.trip_origin),
              suffixIcon: IconButton(onPressed: _resolveOrigin, icon: const Icon(Icons.search)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            onSubmitted: (_) => _resolveOrigin(),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          elevation: 4,
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          child: TextField(
            controller: _destinationController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Destination location name',
              prefixIcon: const Icon(Icons.place),
              suffixIcon: IconButton(onPressed: _resolveDestination, icon: const Icon(Icons.search)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            onSubmitted: (_) => _resolveDestination(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(999),
      color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _isLoadingSuggestions
            ? SizedBox(
                width: 150,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('Building routes...', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                  ],
                ),
              )
            : Text(
                _start == null
                    ? 'Tap/search origin'
                    : _destination == null
                        ? 'Tap/search destination'
                        : _routeOptions.isNotEmpty
                            ? 'Choose one of ${_routeOptions.length} route options'
                            : 'Ready to build route options',
                style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
              ),
      ),
    );
  }

  Widget _buildRouteList() {
    if (_routeOptions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white.withValues(alpha: 0.96);
    final textColor = isDark ? Colors.white : Colors.black;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Route Suggestions', style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 8),
            for (var i = 0; i < _routeOptions.length; i++)
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedRouteIndex = i;
                    _selectedTransportMode = _routeOptions[i].transportHint;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _selectedRouteIndex == i ? Colors.blueAccent : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_routeOptions[i].label}${_bestRouteIndex == i ? ' (Safest)' : ''}',
                          style: TextStyle(fontWeight: _bestRouteIndex == i ? FontWeight.w700 : FontWeight.w500, color: textColor),
                        ),
                      ),
                      Text(
                        'Safety ${_routeOptions[i].safetyScore.toStringAsFixed(0)} • ${_formatDistance(_routeOptions[i].totalDistance)} • ${_formatDuration(_routeOptions[i].totalDuration)}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.72) : null),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final canConfirm = _start != null && _destination != null && _routeOptions.isNotEmpty;

    return Padding(
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
            onPressed: canConfirm ? _showConfirmSheet : null,
            child: const Text('Confirm route'),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    return Stack(
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
                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
                infoWindow: gmaps.InfoWindow(
                  title: _originController.text.trim().isEmpty ? 'Origin' : _originController.text.trim(),
                ),
              ),
            if (_destination != null)
              gmaps.Marker(
                markerId: const gmaps.MarkerId('destination'),
                position: _toGoogleLatLng(_destination!),
                icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
                infoWindow: gmaps.InfoWindow(
                  title: _destinationController.text.trim().isEmpty ? 'Destination' : _destinationController.text.trim(),
                ),
              ),
          },
          polylines: {
            for (var index = 0; index < _routeOptions.length; index++)
              gmaps.Polyline(
                polylineId: gmaps.PolylineId('option_$index'),
                points: _routeOptions[index].points.map(_toGoogleLatLng).toList(),
                width: _selectedRouteIndex == index ? 5 : 3,
                color: _optionColor(index).withValues(alpha: _selectedRouteIndex == index ? 1.0 : 0.7),
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
              _buildTopPanel(context),
              const SizedBox(height: 10),
              _buildStatusPill(),
            ],
          ),
        ),
        if (_routeOptions.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 90,
            child: _buildRouteList(),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomActions(),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrapLocation();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildPage(context);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pick start and destination')),
      body: _buildPage(context),
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

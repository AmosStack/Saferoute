import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'route_recorder_screen.dart';
import '../services/route_path_planner_service.dart';

const _transportModes = <String>[
  'Walking',
  'Bicycle',
  'Motorcycle',
  'Car',
  'Bus',
  'Taxi',
  'Tricycle',
];

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.userId});

  final int? userId;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _start;
  LatLng? _destination;
  List<PathSegment>? _pathSegments;
  String? _selectedTransportMode;
  bool _isLoadingRoute = false;
  final MapController _mapController = MapController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  List<LatLng> get _allRoutePoints {
    if (_pathSegments == null || _pathSegments!.isEmpty) {
      if (_start == null || _destination == null) return const [];
      return [_start!, _destination!];
    }
    final points = <LatLng>[];
    for (final segment in _pathSegments!) {
      points.addAll(segment.points);
    }
    return points;
  }

  /// Get color based on transport mode
  Color _getModeColor(String transportMode) {
    switch (transportMode.toLowerCase()) {
      case 'walking':
        return Colors.green;
      case 'bus':
        return Colors.purple;
      case 'bicycle':
        return Colors.orange;
      case 'driving':
      case 'car':
      case 'taxi':
      case 'motorcycle':
      case 'tricycle':
        return Colors.blue;
      default:
        return Colors.blueAccent;
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng destination, String transportMode) async {
    if (mounted) {
      setState(() {
        _isLoadingRoute = true;
      });
    }

    final segments = await RoutePathPlannerService.calculatePath(start, destination, transportMode);

    if (mounted) {
      setState(() {
        _pathSegments = segments;
        _isLoadingRoute = false;
      });
    }
  }

  Future<LatLng?> _geocodeLocation(String query) async {
    if (query.trim().isEmpty) return null;
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
        .replace(queryParameters: {'format': 'json', 'q': query, 'limit': '1'});
    try {
      final resp = await http.get(uri, headers: {'User-Agent': 'SafeRouteDev/0.1'});
      if (resp.statusCode != 200) return null;
      final List data = json.decode(resp.body) as List;
      if (data.isEmpty) return null;
      final item = data.first as Map<String, dynamic>;
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
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

    _mapController.move(found, 16.0);
    setState(() {
      _start = found;
    });

    if (_start != null && _destination != null && _selectedTransportMode != null) {
      _fetchRoute(_start!, _destination!, _selectedTransportMode!);
    }
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

    _mapController.move(found, 16.0);
    setState(() {
      _destination = found;
    });

    if (_start != null && _destination != null && _selectedTransportMode != null) {
      _fetchRoute(_start!, _destination!, _selectedTransportMode!);
    }
  }

  void _onTap(LatLng latlng) {
    setState(() {
      if (_start == null) {
        _start = latlng;
        _originController.text = '${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}';
      } else {
        _destination = latlng;
        _destinationController.text = '${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}';
      }
    });
    // Fetch road route when both points are set and transport mode is selected
    if (_start != null && _destination != null && _selectedTransportMode != null) {
      _fetchRoute(_start!, _destination!, _selectedTransportMode!);
    }
  }

  @override
  void initState() {
    super.initState();
    _determinePosition().then((pos) {
      if (pos != null) {
        final userLatLng = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          _mapController.move(userLatLng, 15.0);
          setState(() {
            _start ??= userLatLng;
          });
        }
      }
    });
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
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

  void _confirm() {
    if (_start == null || _destination == null || _selectedTransportMode == null) return;

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
  }

  void _selectTransportMode(String mode) {
    setState(() {
      _selectedTransportMode = mode;
    });

    // Fetch route when transport mode is selected
    if (_start != null && _destination != null) {
      _fetchRoute(_start!, _destination!, mode);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick start and destination'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(0, 0),
              initialZoom: 2.0,
              onTap: (tap, latlng) {
                _onTap(latlng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'SafeRouteDev/0.1 (dev@yourdomain.com)'
                  },
                ),
              ),
              // Display multi-segment route
              if (_pathSegments != null && _pathSegments!.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final segment in _pathSegments!)
                      Polyline(
                        points: segment.points,
                        strokeWidth: 4,
                        color: _getModeColor(segment.transportMode),
                      ),
                  ],
                )
              else if (_allRoutePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _allRoutePoints,
                      strokeWidth: 4,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_start != null)
                    Marker(
                      point: _start!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.green, size: 36),
                    ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag, color: Colors.red, size: 34),
                    ),
                ],
              ),
            ],
          ),

          // Search fields overlay
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onSubmitted: (_) => _resolveDestination(),
                  ),
                ),
              ],
            ),
          ),

          // Status indicator
          if (_isLoadingRoute)
            Positioned(
              top: 128,
              left: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.92),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(
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
                        Text('Calculating route...', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              top: 128,
              left: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.92),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    _start == null
                        ? 'Tap map or search origin'
                        : _destination == null
                            ? 'Tap map or search destination'
                            : _selectedTransportMode == null
                                ? 'Select a transport mode'
                                : 'Ready to record',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

          // Route info when available
          if (_pathSegments != null && _pathSegments!.isNotEmpty)
            Positioned(
              top: 165,
              left: 12,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.95),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final segment in _pathSegments!)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getModeColor(segment.transportMode),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${segment.transportMode.toUpperCase()}: ${(segment.distance / 1000).toStringAsFixed(2)}km, ${(segment.duration / 60).toStringAsFixed(0)}min',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
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
              onPressed: (_start == null || _destination == null || _originController.text.trim().isEmpty || _destinationController.text.trim().isEmpty)
                  ? null
                  : () {
                      showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (sheetContext) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                                child: Text(
                                  'Select transport mode',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ),
                              for (final mode in _transportModes)
                                ListTile(
                                  leading: Icon(Icons.directions_transit, color: _getModeColor(mode)),
                                  title: Text(mode),
                                  selected: _selectedTransportMode == mode,
                                  onTap: () {
                                    _selectTransportMode(mode);
                                  },
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
              child: const Text('Select transport'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: (_start == null || _destination == null || _selectedTransportMode == null) ? null : _confirm,
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}

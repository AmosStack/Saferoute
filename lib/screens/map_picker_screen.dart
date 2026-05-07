import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'route_recorder_screen.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.userId});

  final int? userId;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _start;
  LatLng? _destination;
  List<LatLng>? _routePolyline;
  final MapController _mapController = MapController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  List<LatLng> get _routePoints {
    if (_start == null || _destination == null) {
      return const [];
    }
    // Return fetched route if available, otherwise straight line
    return _routePolyline ?? [_start!, _destination!];
  }

  Future<void> _fetchRoute(LatLng start, LatLng destination) async {
    try {
      // Use OSRM (Open Source Routing Machine) for road-following routing
      final uri = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}',
      ).replace(queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
      });
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;
      final points = coordinates
          .cast<List>()
          .map((coord) => LatLng(coord[1] as double, coord[0] as double))
          .toList();
      if (mounted) {
        setState(() {
          _routePolyline = points;
        });
      }
    } catch (_) {
      // Silently fail; straight line will show instead
    }
  }

  Future<LatLng?> _geocodeLocation(String query) async {
    if (query.trim().isEmpty) return null;
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
        .replace(queryParameters: {'format': 'json', 'q': query, 'limit': '1'});
    final resp = await http.get(uri, headers: {'User-Agent': 'SafeRouteDev/0.1'});
    if (resp.statusCode != 200) return null;
    final List data = json.decode(resp.body) as List;
    if (data.isEmpty) return null;
    final item = data.first as Map<String, dynamic>;
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
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

    if (_start != null && _destination != null) {
      _fetchRoute(_start!, _destination!);
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

    if (_start != null && _destination != null) {
      _fetchRoute(_start!, _destination!);
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
    // Fetch road route when both points are set
    if (_start != null && _destination != null) {
      _fetchRoute(_start!, _destination!);
    }
  }

  @override
  void initState() {
    super.initState();
    _determinePosition().then((pos) {
      if (pos != null) {
        final userLatLng = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          // Center map and set a reasonable zoom
          _mapController.move(userLatLng, 15.0);
          setState(() {
            // If no start set yet, populate start with user location
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
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  void _confirm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RouteRecorderScreen(
          startPoint: _start!,
          destination: _destination!,
          startLocationName: _originController.text.trim(),
          endLocationName: _destinationController.text.trim(),
          userId: widget.userId,
        ),
      ),
    );
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
                // Use the single host endpoint to avoid the flutter_map warning
                // about subdomains and to be nicer to the public tile servers.
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // OSM tile servers require a descriptive User-Agent or Referer
                // including contact info for identification. Replace the
                // placeholder email below with a real contact for your app.
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'SafeRouteDev/0.1 (dev@yourdomain.com)'
                  },
                ),
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
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
                  _start == null ? 'Tap map or search origin' : 'Tap map or search destination',
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
              onPressed: (_start == null || _destination == null || _originController.text.trim().isEmpty || _destinationController.text.trim().isEmpty) ? null : _confirm,
              child: const Text('Confirm'),
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

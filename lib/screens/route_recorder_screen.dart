import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/recorded_route.dart';
import '../services/route_recorder_service.dart';
import '../services/backend_service.dart';

class RouteRecorderScreen extends StatefulWidget {
  const RouteRecorderScreen({
    super.key,
    required this.startPoint,
    required this.destination,
    required this.startLocationName,
    required this.endLocationName,
    required this.transportMode,
    this.userId,
  });

  final LatLng startPoint;
  final LatLng destination;
  final String startLocationName;
  final String endLocationName;
  final String transportMode;
  final int? userId;

  @override
  State<RouteRecorderScreen> createState() => _RouteRecorderScreenState();
}

class _RouteRecorderScreenState extends State<RouteRecorderScreen> {
  late final RouteRecorderService _recorderService;
  late final MapController _mapController;
  bool _hasArrivedNotified = false;
  int _selectedRating = 0;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recorderService = RouteRecorderService();
    _mapController = MapController();
    _recorderService.addListener(_onLocationUpdate);
    _startRecording();
  }

  Future<void> _startRecording() async {
    await _recorderService.startRecording(widget.startPoint);
    _mapController.move(widget.startPoint, 16.0);
  }

  void _onLocationUpdate() {
    setState(() {});

    // Check if user reached destination
    if (!_hasArrivedNotified && _recorderService.isNearDestination(widget.destination)) {
      _hasArrivedNotified = true;
      _showArrivalDialog();
    }
  }

  void _showArrivalDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${widget.endLocationName} reached'),
        content: Text(
          'Distance: ${_recorderService.totalDistance.toStringAsFixed(0)} m\n'
          'Duration: ${_formatDuration(_recorderService.totalDistance)}',
        ),
        actions: [
          TextButton(
            onPressed: _stopRecording,
            child: const Text('Save Route'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double distance) {
    // Rough estimate: 1.4 m/s average walking speed
    final seconds = (distance / 1.4).toInt();
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins == 0) return '${secs}s';
    return '${mins}m ${secs}s';
  }

  Future<void> _stopRecording() async {
    Navigator.of(context).pop(); // Close arrival dialog
    await _recorderService.dispose();

    if (mounted) {
      _showRatingDialog();
    }
  }

  void _showRatingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          title: const Text('Rate This Route'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How safe was this journey?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      Icons.star,
                      color: i < _selectedRating ? Colors.amber : Colors.grey,
                      size: 32,
                    ),
                    onPressed: () {
                      dialogSetState(() {
                        _selectedRating = i + 1;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Any safety notes or observations?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _saveRoute();
              },
              child: const Text('Save & Finish'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRoute() async {
    final route = await _recorderService.stopRecording(
      widget.destination,
      startLocationName: widget.startLocationName,
      endLocationName: widget.endLocationName,
      transportMode: widget.transportMode,
      rating: _selectedRating,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    // Save to backend if userId is available
    if (widget.userId != null) {
      final saved = await BackendService.saveRoute(
        userId: widget.userId!,
        route: route,
      );
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save route to server')),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop({'route': route});
    }
  }

  @override
  void dispose() {
    _recorderService.removeListener(_onLocationUpdate);
    _recorderService.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coords = _recorderService.coordinates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Route'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.startPoint,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(
                  headers: {'User-Agent': 'SafeRoute/0.1'},
                ),
              ),
              // Draw recorded polyline
              if (coords.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: coords,
                      strokeWidth: 4,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              // Start & destination markers
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.startPoint,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.green, size: 36),
                  ),
                  Marker(
                    point: widget.destination,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag, color: Colors.red, size: 34),
                  ),
                ],
              ),
            ],
          ),
          // Stats overlay
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.startLocationName} → ${widget.endLocationName}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mode: ${widget.transportMode}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Distance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              _recorderService.totalDistance < 1000
                                  ? '${_recorderService.totalDistance.toStringAsFixed(0)} m'
                                  : '${(_recorderService.totalDistance / 1000).toStringAsFixed(2)} km',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Points Recorded', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              '${coords.length}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Arrived button
          Positioned(
            bottom: 24,
            left: 12,
            right: 12,
            child: FilledButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.flag),
              label: const Text('Arrived'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

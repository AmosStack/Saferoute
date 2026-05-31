import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:async';

import '../models/recorded_route.dart';

class RouteRecorderService {
  RouteRecorderService();

  StreamSubscription<Position>? _positionStream;
  final List<LatLng> _coordinates = [];
  Position? _currentPosition;
  DateTime? _startTime;
  double _totalDistance = 0;

  bool get isRecording => _positionStream != null;
  List<LatLng> get coordinates => _coordinates;
  double get totalDistance => _totalDistance;
  Position? get currentPosition => _currentPosition;
  bool get hasRecordedPoints => _coordinates.length > 1;
  LatLng? get currentLatLng {
    final position = _currentPosition;
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback callback) => _listeners.add(callback);
  void removeListener(VoidCallback callback) => _listeners.remove(callback);

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'SafeRoute is recording your trip',
          notificationText: 'Location tracking stays active while you move',
          setOngoing: true,
          enableWakeLock: true,
          enableWifiLock: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
  }

  /// Calculate distance between two points using Haversine formula (in meters)
  double _calculateDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000; // meters
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLon = _toRadians(p2.longitude - p1.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(p1.latitude)) * math.cos(_toRadians(p2.latitude)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Starts recording route from start to destination
  Future<void> startRecording(LatLng startPoint) async {
    _coordinates.clear();
    _totalDistance = 0;
    _startTime = DateTime.now();
    _currentPosition = null;
    _coordinates.add(startPoint);

    // Listen to position updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen((Position position) {
      if (position.accuracy > 45 && _coordinates.length > 1) {
        _currentPosition = position;
        _notifyListeners();
        return;
      }

      _currentPosition = position;
      final newPoint = LatLng(position.latitude, position.longitude);

      // Calculate distance from last point
      if (_coordinates.isNotEmpty) {
        final lastPoint = _coordinates.last;
        final distance = _calculateDistance(lastPoint, newPoint);
        if (distance >= 1.5) {
          _totalDistance += distance;
        } else {
          _notifyListeners();
          return;
        }
      }

      _coordinates.add(newPoint);
      _notifyListeners();
    });
  }

  Future<void> cancelRecording() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _coordinates.clear();
    _currentPosition = null;
    _startTime = null;
    _totalDistance = 0;
    _notifyListeners();
  }

  /// Stops recording and returns the recorded route
  Future<RecordedRoute> stopRecording(
    LatLng endPoint, {
    required String startLocationName,
    required String endLocationName,
    required String transportMode,
    int? rating,
    String? notes,
    double? fareCost,
    int? waitingTimeMinutes,
    int? transferCount,
    Map<String, int> safetyAssessment = const <String, int>{},
    bool consentAccepted = false,
  }) async {
    _positionStream?.cancel();
    _positionStream = null;

    final endTime = DateTime.now();
    
    // Add end point if not already there
    if (_coordinates.isEmpty || _coordinates.last != endPoint) {
      if (_coordinates.isNotEmpty) {
        final lastPoint = _coordinates.last;
        final distance = _calculateDistance(lastPoint, endPoint);
        _totalDistance += distance;
      }
      _coordinates.add(endPoint);
    }

    return RecordedRoute(
      startLocationName: startLocationName,
      endLocationName: endLocationName,
      transportMode: transportMode,
      startPoint: _coordinates.first,
      endPoint: endPoint,
      coordinates: _coordinates,
      startTime: _startTime ?? endTime,
      endTime: endTime,
      distance: _totalDistance,
      rating: rating,
      notes: notes,
      fareCost: fareCost,
      waitingTimeMinutes: waitingTimeMinutes,
      transferCount: transferCount,
      safetyAssessment: safetyAssessment,
      consentAccepted: consentAccepted,
    );
  }

  /// Checks if user is close to destination using the live position and GPS accuracy.
  bool isNearDestination(LatLng destination, {double thresholdMeters = 50}) {
    final livePoint = currentLatLng ?? (_coordinates.isNotEmpty ? _coordinates.last : null);
    if (livePoint == null) return false;

    final accuracyThreshold = _currentPosition?.accuracy != null
        ? math.max(thresholdMeters, _currentPosition!.accuracy * 2)
        : thresholdMeters;
    final distance = _calculateDistance(livePoint, destination);
    return distance <= accuracyThreshold;
  }

  /// Cleanup
  Future<void> dispose() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _listeners.clear();
  }
}

import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'google_maps_api_service.dart';

/// Represents a segment of a journey with a specific transport mode
class PathSegment {
  PathSegment({
    required this.transportMode,
    required this.points,
    required this.distance,
    required this.duration,
  });

  final String transportMode; // 'walking', 'bus', 'driving', etc.
  final List<LatLng> points;
  final double distance; // in meters
  final int duration; // in seconds

  @override
  String toString() =>
      'PathSegment($transportMode, ${points.length} points, ${distance.toStringAsFixed(0)}m, ${(duration / 60).toStringAsFixed(0)}min)';
}

/// Route planner that supports multi-modal transport including buses
class RoutePathPlannerService {
  static const Map<String, double> _fallbackSpeedMps = {
    'walking': 1.4,
    'bicycle': 4.5,
    'bus': 6.0,
    'car': 11.5,
    'driving': 11.5,
    'taxi': 11.5,
    'motorcycle': 13.5,
    'tricycle': 6.5,
  };

  /// Calculate a path based on transport mode
  /// For bus: uses Google transit directions with bus preference.
  /// For others: returns a single segment with the calculated route
  static Future<List<PathSegment>?> calculatePath(
    LatLng start,
    LatLng destination,
    String transportMode,
  ) async {
    final alternatives = await calculatePathAlternatives(
      start,
      destination,
      transportMode,
    );
    return alternatives.isEmpty ? null : alternatives.first;
  }

  static Future<List<List<PathSegment>>> calculatePathAlternatives(
    LatLng start,
    LatLng destination,
    String transportMode,
  ) async {
    try {
      final mode = transportMode.toLowerCase().trim();

      if (mode == 'bus') {
        return await _calculateBusPaths(start, destination);
      } else if (mode == 'bicycle') {
        return await _calculateRoutes(start, destination, 'bike');
      } else if (mode == 'walking') {
        return await _calculateRoutes(start, destination, 'foot');
      } else if (mode == 'motorcycle' || mode == 'car' || mode == 'taxi') {
        return await _calculateRoutes(start, destination, mode);
      } else if (mode == 'tricycle') {
        return await _calculateRoutes(start, destination, 'tricycle');
      } else {
        return await _calculateRoutes(start, destination, 'driving');
      }
    } catch (e) {
      debugPrint('Error calculating path: $e');
      return const <List<PathSegment>>[];
    }
  }

  static Future<List<List<PathSegment>>> _calculateRoutes(
    LatLng start,
    LatLng destination,
    String profile,
  ) async {
    try {
      final transportMode = _profileToMode(profile);
      final routes = await GoogleMapsApiService.directionsAlternatives(
        start: start,
        destination: destination,
        transportMode: transportMode,
      );
      if (routes.isEmpty) return const <List<PathSegment>>[];

      return routes
          .where((route) => route.points.length >= 2)
          .map(
            (route) => [
              PathSegment(
                transportMode: transportMode,
                points: route.points,
                distance: route.distanceMeters,
                duration: _routeDurationSeconds(
                  route.durationSeconds,
                  route.points,
                  transportMode,
                ),
              ),
            ],
          )
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error calculating route: $e');
      return const <List<PathSegment>>[];
    }
  }

  static int _estimateDurationSeconds(List<LatLng> points, String transportMode) {
    if (points.length < 2) return 0;

    var distanceMeters = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final lat1 = a.latitude * (3.141592653589793 / 180.0);
      final lat2 = b.latitude * (3.141592653589793 / 180.0);
      final dLat = (b.latitude - a.latitude) * (3.141592653589793 / 180.0);
      final dLon = (b.longitude - a.longitude) * (3.141592653589793 / 180.0);
      final sinLat = math.sin(dLat / 2);
      final sinLon = math.sin(dLon / 2);
      final h = sinLat * sinLat + (sinLon * sinLon) * (math.cos(lat1) * math.cos(lat2));
      distanceMeters += 2 * 6371000.0 * math.asin(math.sqrt(h));
    }

    final speed = _fallbackSpeedMps[transportMode] ?? _fallbackSpeedMps['driving']!;
    return (distanceMeters / speed).round();
  }

  static int _routeDurationSeconds(Object? rawDuration, List<LatLng> points, String transportMode) {
    final duration = (rawDuration as num?)?.toInt();
    if (duration != null && duration > 0) {
      return duration;
    }
    return _estimateDurationSeconds(points, transportMode);
  }

  static Future<List<List<PathSegment>>> _calculateBusPaths(
    LatLng start,
    LatLng destination,
  ) async {
    try {
      return await _calculateRoutes(start, destination, 'transit_bus');
    } catch (e) {
      debugPrint('Error calculating bus path: $e');
      return const <List<PathSegment>>[];
    }
  }

  /// True when at least one bus stop can be found near the given location.
  static Future<bool> hasNearbyBusStop(
    LatLng location, {
    int radiusMeters = 700,
  }) async {
    return GoogleMapsApiService.hasNearbyBusStop(location, radiusMeters: radiusMeters);
  }

  /// Convert legacy profile names to transport modes used by Google Directions.
  static String _profileToMode(String profile) {
    switch (profile) {
      case 'foot':
        return 'walking';
      case 'bike':
        return 'bicycle';
      case 'driving':
      case 'transit_bus':
      default:
        if (profile == 'taxi' ||
            profile == 'motorcycle' ||
            profile == 'tricycle' ||
            profile == 'car') {
          return profile;
        }
        return profile == 'transit_bus' ? 'bus' : 'driving';
    }
  }
}

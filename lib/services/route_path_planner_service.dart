import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:convert';

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

/// Bus stop location
class BusStop {
  BusStop({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  final double latitude;
  final double longitude;
  final String name;

  LatLng get location => LatLng(latitude, longitude);

  factory BusStop.fromOSM(Map<String, dynamic> json) {
    return BusStop(
      latitude: double.parse(json['lat']?.toString() ?? '0'),
      longitude: double.parse(json['lon']?.toString() ?? '0'),
      name: json['name'] ?? json['display_name'] ?? 'Bus Stop',
    );
  }
}

/// Route planner that supports multi-modal transport including buses
class RoutePathPlannerService {
  static const String _osrmUrl = 'http://router.project-osrm.org/route/v1';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/search';

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
  /// For bus: returns walk -> bus -> walk segments
  /// For others: returns a single segment with the calculated route
  static Future<List<PathSegment>?> calculatePath(
    LatLng start,
    LatLng destination,
    String transportMode,
  ) async {
    try {
      // Normalize transport mode
      final mode = transportMode.toLowerCase().trim();

      if (mode == 'bus') {
        return await _calculateBusPath(start, destination);
      } else if (mode == 'bicycle') {
        return await _calculateRoute(start, destination, 'bike');
      } else if (mode == 'walking') {
        return await _calculateRoute(start, destination, 'foot');
      } else if (mode == 'motorcycle' || mode == 'car' || mode == 'taxi') {
        return await _calculateRoute(start, destination, 'driving');
      } else if (mode == 'tricycle') {
        // Tricycle: use driving profile but could be more nuanced
        return await _calculateRoute(start, destination, 'driving');
      } else {
        // Default to driving
        return await _calculateRoute(start, destination, 'driving');
      }
    } catch (e) {
      debugPrint('Error calculating path: $e');
      return null;
    }
  }

  /// Calculate a single-segment route using OSRM
  static Future<List<PathSegment>?> _calculateRoute(
    LatLng start,
    LatLng destination,
    String profile,
  ) async {
    try {
      final uri = Uri.parse(
        '$_osrmUrl/$profile/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}',
      ).replace(queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;
      final points = coordinates
          .cast<List>()
          .map((coord) => LatLng(coord[1] as double, coord[0] as double))
          .toList();

      final distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (route['duration'] as num?)?.toInt() ?? _estimateDurationSeconds(points, _profileToMode(profile));

      return [
        PathSegment(
          transportMode: _profileToMode(profile),
          points: points,
          distance: distance,
          duration: duration,
        ),
      ];
    } catch (e) {
      debugPrint('Error calculating route: $e');
      return null;
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

  /// Calculate a multi-segment bus path:
  /// 1. Walk from start to nearest bus stop
  /// 2. Bus from stop A to stop B
  /// 3. Walk from bus stop to destination
  static Future<List<PathSegment>?> _calculateBusPath(
    LatLng start,
    LatLng destination,
  ) async {
    try {
      // Find nearest bus stops
      final nearestStartStop = await _findNearestBusStop(start);
      final nearestDestStop = await _findNearestBusStop(destination);

      if (nearestStartStop == null || nearestDestStop == null) {
        debugPrint('Could not find bus stops, falling back to driving');
        return await _calculateRoute(start, destination, 'driving');
      }

      final segments = <PathSegment>[];

      // Segment 1: Walk from start to bus stop
      final walkToStop =
          await _calculateRoute(start, nearestStartStop.location, 'foot');
      if (walkToStop != null && walkToStop.isNotEmpty) {
        segments.add(walkToStop.first);
      }

      // Segment 2: Bus ride (use driving profile as proxy for bus route)
      final busRide = await _calculateRoute(
        nearestStartStop.location,
        nearestDestStop.location,
        'driving',
      );
      if (busRide != null && busRide.isNotEmpty) {
        // Change the transport mode to 'bus'
        final busSegment = busRide.first;
        segments.add(
          PathSegment(
            transportMode: 'bus',
            points: busSegment.points,
            distance: busSegment.distance,
            duration: busSegment.duration,
          ),
        );
      }

      // Segment 3: Walk from bus stop to destination
      final walkFromStop =
          await _calculateRoute(nearestDestStop.location, destination, 'foot');
      if (walkFromStop != null && walkFromStop.isNotEmpty) {
        segments.add(walkFromStop.first);
      }

      return segments.isNotEmpty ? segments : null;
    } catch (e) {
      debugPrint('Error calculating bus path: $e');
      return null;
    }
  }

  /// Find the nearest bus stop to a given location
  static Future<BusStop?> _findNearestBusStop(
    LatLng location, {
    int radiusMeters = 500,
  }) async {
    try {
      // Search for bus stops near the location using Nominatim
      final uri = Uri.parse(_nominatimUrl).replace(queryParameters: {
        'format': 'json',
        'q': 'amenity=bus_stop',
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'radius': radiusMeters.toString(),
        'limit': '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'SafeRoute/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final List data = jsonDecode(response.body) as List;
      if (data.isEmpty) return null;

      return BusStop.fromOSM(data.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error finding bus stop: $e');
      return null;
    }
  }

  /// True when at least one bus stop can be found near the given location.
  static Future<bool> hasNearbyBusStop(
    LatLng location, {
    int radiusMeters = 700,
  }) async {
    final stop = await _findNearestBusStop(location, radiusMeters: radiusMeters);
    return stop != null;
  }

  /// Convert OSRM profile to transport mode
  static String _profileToMode(String profile) {
    switch (profile) {
      case 'foot':
        return 'walking';
      case 'bike':
        return 'bicycle';
      case 'driving':
      default:
        return 'driving';
    }
  }
}

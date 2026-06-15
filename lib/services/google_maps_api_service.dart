import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GooglePlaceResult {
  const GooglePlaceResult({required this.point, required this.name});

  final LatLng point;
  final String name;
}

class GoogleRouteResult {
  const GoogleRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
}

class GoogleMapsApiService {
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _geocodeUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  static const String _directionsUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _nearbySearchUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  static bool get hasApiKey => apiKey.trim().isNotEmpty;

  static Uri _uri(String baseUrl, Map<String, String> queryParameters) {
    return Uri.parse(baseUrl).replace(
      queryParameters: <String, String>{...queryParameters, 'key': apiKey},
    );
  }

  static Future<GooglePlaceResult?> geocode(String query) async {
    if (!hasApiKey || query.trim().isEmpty) return null;

    try {
      final response = await http
          .get(_uri(_geocodeUrl, <String, String>{'address': query.trim()}))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final item = results.first as Map<String, dynamic>;
      final geometry = item['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final formattedAddress = item['formatted_address']?.toString().trim();
      final name = formattedAddress == null || formattedAddress.isEmpty
          ? query.trim()
          : formattedAddress.split(',').first.trim();

      return GooglePlaceResult(point: LatLng(lat, lng), name: name.isEmpty ? query.trim() : name);
    } catch (e) {
      debugPrint('Google geocode failed: $e');
      return null;
    }
  }

  static Future<String?> reverseGeocodeName(LatLng point) async {
    if (!hasApiKey) return null;

    try {
      final response = await http
          .get(_uri(_geocodeUrl, <String, String>{
            'latlng': '${point.latitude},${point.longitude}',
          }))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final formattedAddress = (results.first as Map<String, dynamic>)['formatted_address']?.toString().trim();
      if (formattedAddress == null || formattedAddress.isEmpty) return null;
      return formattedAddress.split(',').first.trim();
    } catch (e) {
      debugPrint('Google reverse geocode failed: $e');
      return null;
    }
  }

  static Future<GoogleRouteResult?> directions({
    required LatLng start,
    required LatLng destination,
    required String transportMode,
  }) async {
    if (!hasApiKey) return null;

    final mode = _directionsMode(transportMode);
    final query = <String, String>{
      'origin': '${start.latitude},${start.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': mode,
      'alternatives': 'false',
    };
    if (transportMode.toLowerCase().trim() == 'bus') {
      query['transit_mode'] = 'bus';
    }

    try {
      final response = await http.get(_uri(_directionsUrl, query)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List?;
      if (legs == null || legs.isEmpty) return null;

      var distanceMeters = 0.0;
      var durationSeconds = 0;
      for (final rawLeg in legs) {
        final leg = rawLeg as Map<String, dynamic>;
        distanceMeters += ((leg['distance'] as Map<String, dynamic>?)?['value'] as num?)?.toDouble() ?? 0.0;
        durationSeconds += ((leg['duration'] as Map<String, dynamic>?)?['value'] as num?)?.toInt() ?? 0;
      }

      final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>?;
      final encodedPolyline = overviewPolyline?['points']?.toString();
      final points = encodedPolyline == null ? const <LatLng>[] : _decodePolyline(encodedPolyline);
      if (points.length < 2) return null;

      return GoogleRouteResult(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      debugPrint('Google directions failed: $e');
      return null;
    }
  }

  static Future<bool> hasNearbyBusStop(
    LatLng location, {
    int radiusMeters = 700,
  }) async {
    if (!hasApiKey) return false;

    try {
      final response = await http
          .get(_uri(_nearbySearchUrl, <String, String>{
            'location': '${location.latitude},${location.longitude}',
            'radius': radiusMeters.toString(),
            'type': 'bus_station',
          }))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') return false;
      final results = data['results'] as List?;
      return results != null && results.isNotEmpty;
    } catch (e) {
      debugPrint('Google nearby bus stop lookup failed: $e');
      return false;
    }
  }

  static String _directionsMode(String transportMode) {
    switch (transportMode.toLowerCase().trim()) {
      case 'walking':
        return 'walking';
      case 'bicycle':
        return 'bicycling';
      case 'bus':
        return 'transit';
      case 'car':
      case 'taxi':
      case 'motorcycle':
      case 'tricycle':
      default:
        return 'driving';
    }
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lng += deltaLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

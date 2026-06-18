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
  static const String _geocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const String _directionsUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const String _nearbySearchUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String _nominatimSearchUrl =
      'https://nominatim.openstreetmap.org/search';
  static const String _nominatimReverseUrl =
      'https://nominatim.openstreetmap.org/reverse';
  static const String _osrmRouteUrl =
      'https://router.project-osrm.org/route/v1';
  static const Map<String, String> _osmHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'SafeRoute/1.0',
  };

  static bool get hasApiKey => apiKey.trim().isNotEmpty;

  static Uri _uri(String baseUrl, Map<String, String> queryParameters) {
    return Uri.parse(baseUrl).replace(
      queryParameters: <String, String>{...queryParameters, 'key': apiKey},
    );
  }

  static Future<GooglePlaceResult?> geocode(String query) async {
    if (query.trim().isEmpty) return null;
    if (!hasApiKey) return _nominatimGeocode(query);

    try {
      final response = await http
          .get(_uri(_geocodeUrl, <String, String>{'address': query.trim()}))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final item = results.first as Map<String, dynamic>;
            final geometry = item['geometry'] as Map<String, dynamic>?;
            final location = geometry?['location'] as Map<String, dynamic>?;
            final lat = (location?['lat'] as num?)?.toDouble();
            final lng = (location?['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              final formattedAddress = item['formatted_address']
                  ?.toString()
                  .trim();
              final name = formattedAddress == null || formattedAddress.isEmpty
                  ? query.trim()
                  : formattedAddress.split(',').first.trim();

              return GooglePlaceResult(
                point: LatLng(lat, lng),
                name: name.isEmpty ? query.trim() : name,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google geocode failed: $e');
    }

    return _nominatimGeocode(query);
  }

  static Future<String?> reverseGeocodeName(LatLng point) async {
    if (!hasApiKey) return _nominatimReverseGeocodeName(point);

    try {
      final response = await http
          .get(
            _uri(_geocodeUrl, <String, String>{
              'latlng': '${point.latitude},${point.longitude}',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final formattedAddress =
                (results.first as Map<String, dynamic>)['formatted_address']
                    ?.toString()
                    .trim();
            if (formattedAddress != null && formattedAddress.isNotEmpty) {
              return formattedAddress.split(',').first.trim();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google reverse geocode failed: $e');
    }

    return _nominatimReverseGeocodeName(point);
  }

  static Future<GoogleRouteResult?> directions({
    required LatLng start,
    required LatLng destination,
    required String transportMode,
  }) async {
    if (!hasApiKey) {
      return _osrmDirections(
        start: start,
        destination: destination,
        transportMode: transportMode,
      );
    }

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
      final response = await http
          .get(_uri(_directionsUrl, query))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final route = routes.first as Map<String, dynamic>;
            final legs = route['legs'] as List?;
            if (legs != null && legs.isNotEmpty) {
              var distanceMeters = 0.0;
              var durationSeconds = 0;
              for (final rawLeg in legs) {
                final leg = rawLeg as Map<String, dynamic>;
                distanceMeters +=
                    ((leg['distance'] as Map<String, dynamic>?)?['value']
                            as num?)
                        ?.toDouble() ??
                    0.0;
                durationSeconds +=
                    ((leg['duration'] as Map<String, dynamic>?)?['value']
                            as num?)
                        ?.toInt() ??
                    0;
              }

              final overviewPolyline =
                  route['overview_polyline'] as Map<String, dynamic>?;
              final encodedPolyline = overviewPolyline?['points']?.toString();
              final points = encodedPolyline == null
                  ? const <LatLng>[]
                  : _decodePolyline(encodedPolyline);
              if (points.length >= 2) {
                return GoogleRouteResult(
                  points: points,
                  distanceMeters: distanceMeters,
                  durationSeconds: durationSeconds,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Google directions failed: $e');
    }

    return _osrmDirections(
      start: start,
      destination: destination,
      transportMode: transportMode,
    );
  }

  static Future<bool> hasNearbyBusStop(
    LatLng location, {
    int radiusMeters = 700,
  }) async {
    if (!hasApiKey) {
      return _nominatimHasNearbyBusStop(location, radiusMeters: radiusMeters);
    }

    try {
      final response = await http
          .get(
            _uri(_nearbySearchUrl, <String, String>{
              'location': '${location.latitude},${location.longitude}',
              'radius': radiusMeters.toString(),
              'type': 'bus_station',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final results = data['results'] as List?;
          return results != null && results.isNotEmpty;
        }
      }
    } catch (e) {
      debugPrint('Google nearby bus stop lookup failed: $e');
    }

    return _nominatimHasNearbyBusStop(location, radiusMeters: radiusMeters);
  }

  static Future<GooglePlaceResult?> _nominatimGeocode(String query) async {
    final trimmed = query.trim();
    final queries = <String>[
      trimmed,
      if (!trimmed.toLowerCase().contains('tanzania'))
        '$trimmed, Dar es Salaam, Tanzania',
    ];

    for (final searchQuery in queries) {
      try {
        final uri = Uri.parse(_nominatimSearchUrl).replace(
          queryParameters: <String, String>{
            'q': searchQuery,
            'format': 'jsonv2',
            'addressdetails': '1',
            'limit': '1',
          },
        );
        final response = await http
            .get(uri, headers: _osmHeaders)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;

        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isEmpty) continue;

        final item = results.first as Map<String, dynamic>;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final displayName = item['display_name']?.toString().trim();
        final name =
            _shortOsmName(item) ??
            displayName?.split(',').first.trim() ??
            trimmed;
        return GooglePlaceResult(
          point: LatLng(lat, lon),
          name: name.isEmpty ? trimmed : name,
        );
      } catch (e) {
        debugPrint('Nominatim geocode failed: $e');
      }
    }

    return null;
  }

  static Future<String?> _nominatimReverseGeocodeName(LatLng point) async {
    try {
      final uri = Uri.parse(_nominatimReverseUrl).replace(
        queryParameters: <String, String>{
          'lat': point.latitude.toString(),
          'lon': point.longitude.toString(),
          'format': 'jsonv2',
          'zoom': '18',
          'addressdetails': '1',
        },
      );
      final response = await http
          .get(uri, headers: _osmHeaders)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = _shortOsmName(data);
      if (name != null && name.isNotEmpty) return name;

      final displayName = data['display_name']?.toString().trim();
      if (displayName == null || displayName.isEmpty) return null;
      return displayName.split(',').first.trim();
    } catch (e) {
      debugPrint('Nominatim reverse geocode failed: $e');
      return null;
    }
  }

  static Future<bool> _nominatimHasNearbyBusStop(
    LatLng location, {
    required int radiusMeters,
  }) async {
    try {
      final degrees = radiusMeters / 111320.0;
      final uri = Uri.parse(_nominatimSearchUrl).replace(
        queryParameters: <String, String>{
          'q': 'bus stop',
          'format': 'jsonv2',
          'limit': '1',
          'viewbox':
              '${location.longitude - degrees},${location.latitude + degrees},'
              '${location.longitude + degrees},${location.latitude - degrees}',
          'bounded': '1',
        },
      );
      final response = await http
          .get(uri, headers: _osmHeaders)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final results = jsonDecode(response.body) as List<dynamic>;
      return results.isNotEmpty;
    } catch (e) {
      debugPrint('Nominatim bus stop lookup failed: $e');
      return false;
    }
  }

  static Future<GoogleRouteResult?> _osrmDirections({
    required LatLng start,
    required LatLng destination,
    required String transportMode,
  }) async {
    final preferredProfile = _osrmProfile(transportMode);
    final profiles = <String>[
      preferredProfile,
      if (preferredProfile != 'driving') 'driving',
    ];

    for (final profile in profiles) {
      try {
        final uri =
            Uri.parse(
              '$_osrmRouteUrl/$profile/'
              '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}',
            ).replace(
              queryParameters: const <String, String>{
                'overview': 'full',
                'geometries': 'geojson',
                'steps': 'false',
              },
            );

        final response = await http
            .get(uri, headers: _osmHeaders)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] != 'Ok') continue;

        final routes = data['routes'] as List?;
        if (routes == null || routes.isEmpty) continue;

        final route = routes.first as Map<String, dynamic>;
        final geometry = route['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List?;
        if (coordinates == null || coordinates.length < 2) continue;

        final points = <LatLng>[];
        for (final coordinate in coordinates) {
          final pair = coordinate as List;
          final lng = (pair[0] as num).toDouble();
          final lat = (pair[1] as num).toDouble();
          points.add(LatLng(lat, lng));
        }

        return GoogleRouteResult(
          points: points,
          distanceMeters: ((route['distance'] as num?) ?? 0).toDouble(),
          durationSeconds: ((route['duration'] as num?) ?? 0).round(),
        );
      } catch (e) {
        debugPrint('OSRM directions failed for $profile: $e');
      }
    }

    return null;
  }

  static String? _shortOsmName(Map<String, dynamic> item) {
    final named = item['name']?.toString().trim();
    if (named != null && named.isNotEmpty) return named;

    final address = item['address'];
    if (address is! Map<String, dynamic>) return null;
    for (final key in <String>[
      'road',
      'suburb',
      'neighbourhood',
      'village',
      'city',
      'town',
    ]) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _osrmProfile(String transportMode) {
    switch (transportMode.toLowerCase().trim()) {
      case 'walking':
        return 'foot';
      case 'bicycle':
        return 'bike';
      case 'bus':
      case 'car':
      case 'taxi':
      case 'motorcycle':
      case 'tricycle':
      default:
        return 'driving';
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

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recorded_route.dart';

class BackendService {
  static const String _baseUrlPrefKey = 'backend_base_url';
  static const Duration _requestTimeout = Duration(seconds: 3);
  static const String _defaultLanFallbackHost = String.fromEnvironment(
    'SAFE_ROUTE_LAN_FALLBACK_HOST',
    defaultValue: '192.168.1.20',
  );
  static String? _configuredBaseUrl;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _configuredBaseUrl = prefs.getString(_baseUrlPrefKey)?.trim();
    if (_configuredBaseUrl != null && _configuredBaseUrl!.isEmpty) {
      _configuredBaseUrl = null;
    }
  }

  static Future<String?> getStoredBaseUrl() async {
    if (_configuredBaseUrl != null) {
      return _configuredBaseUrl;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_baseUrlPrefKey)?.trim();
    return stored == null || stored.isEmpty ? null : stored;
  }

  static Future<void> setStoredBaseUrl(String? value) async {
    final trimmed = value?.trim();
    final prefs = await SharedPreferences.getInstance();

    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_baseUrlPrefKey);
      _configuredBaseUrl = null;
      return;
    }

    await prefs.setString(_baseUrlPrefKey, trimmed);
    _configuredBaseUrl = trimmed;
  }

  static String _baseUrlFromHost(String hostOrUrl) {
    final trimmed = hostOrUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _stripTrailingSlash(trimmed);
    }

    return 'http://$trimmed:3000';
  }

  static String _stripTrailingSlash(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static void _addCandidate(List<String> candidates, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }

    final normalized = _stripTrailingSlash(trimmed);
    if (!candidates.contains(normalized)) {
      candidates.add(normalized);
    }
  }

  static List<String> get _baseUrlCandidates {
    const override = String.fromEnvironment('SAFE_ROUTE_API_BASE_URL');
    if (override.isNotEmpty) {
      return [_stripTrailingSlash(override)];
    }

    final candidates = <String>[];

    const serverHost = String.fromEnvironment('SAFE_ROUTE_SERVER_HOST');
    if (serverHost.isNotEmpty) {
      _addCandidate(candidates, _baseUrlFromHost(serverHost));
    }

    if (_configuredBaseUrl != null && _configuredBaseUrl!.isNotEmpty) {
      _addCandidate(candidates, _configuredBaseUrl);
    }

    if (kIsWeb) {
      _addCandidate(candidates, 'http://localhost:3000');
      return candidates;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _addCandidate(candidates, _baseUrlFromHost(_defaultLanFallbackHost));
        _addCandidate(candidates, 'http://10.0.2.2:3000');
        return candidates;
      default:
        _addCandidate(candidates, 'http://localhost:3000');
        return candidates;
    }
  }

  static String get _baseUrl => _baseUrlCandidates.first;

  static Future<http.Response> _postWithFallback(
    String path,
    Map<String, dynamic> body,
  ) async {
    Object? lastError;

    for (final baseUrl in _baseUrlCandidates) {
      try {
        final uri = Uri.parse('$baseUrl$path');
        return await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(_requestTimeout);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(lastError?.toString() ?? 'Unknown connection error');
  }

  static Future<http.Response> _getWithFallback(String path) async {
    Object? lastError;

    for (final baseUrl in _baseUrlCandidates) {
      try {
        final uri = Uri.parse('$baseUrl$path');
        return await http.get(uri).timeout(_requestTimeout);
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(lastError?.toString() ?? 'Unknown connection error');
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _postWithFallback(path, body);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {'error': response.body, 'statusCode': response.statusCode};
    } catch (e) {
      return {
        'error': kIsWeb
            ? 'Unable to connect to the backend. Check the server URL and make sure the backend is running.'
            : 'Unable to connect to the backend. If the phone is on mobile data or a different network, use a public HTTPS API URL with `SAFE_ROUTE_API_BASE_URL` or set the in-app Backend URL.',
        'exception': e.toString(),
      };
    }
  }

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

  /// Register a new user with the backend
  static Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _postJson('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });

    if (result['error'] != null) {
      print('Registration failed: ${result['error']}');
    }

    return result;
  }

  /// Login user with the backend
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final result = await _postJson('/auth/login', {
      'email': email,
      'password': password,
    });

    if (result['error'] != null) {
      print('Login failed: ${result['error']}');
    }

    return result;
  }

  // ============================================================================
  // ROUTES
  // ============================================================================

  /// Save a recorded route to the backend
  static Future<bool> saveRoute({
    required int userId,
    required RecordedRoute route,
  }) async {
    try {
      final response = await _postWithFallback('/routes/record', {
        'userId': userId,
        'startLocationName': route.startLocationName,
        'endLocationName': route.endLocationName,
        'transportMode': route.transportMode,
        'startLatitude': route.startPoint.latitude,
        'startLongitude': route.startPoint.longitude,
        'endLatitude': route.endPoint.latitude,
        'endLongitude': route.endPoint.longitude,
        'coordinates': route.coordinates
            .map((c) => {'lat': c.latitude, 'lng': c.longitude})
            .toList(),
        'distance': route.distance,
        'duration': route.duration.inSeconds,
        'rating': route.rating,
        'notes': route.notes,
        'startedAt': route.startTime.toIso8601String(),
        'endedAt': route.endTime.toIso8601String(),
      });

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to save route: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error saving route: $e');
      return false;
    }
  }

  /// Fetch user's recorded routes
  static Future<List<RecordedRoute>?> getUserRoutes(int userId) async {
    try {
      final response = await _getWithFallback('/routes/user/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = (data['routes'] as List?)
            ?.map(
              (routeJson) =>
                  RecordedRoute.fromJson(routeJson as Map<String, dynamic>),
            )
            .toList();
        return routes ?? [];
      } else {
        print('Failed to fetch routes: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching routes: $e');
      return null;
    }
  }

  /// Create a route metadata in the database
  static Future<String?> createRoute({
    required int userId,
    required String name,
    String? description,
  }) async {
    try {
      final response = await _postWithFallback('/routes', {
        'userId': userId,
        'name': name,
        'description': description,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as String?;
      } else {
        print('Failed to create route: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating route: $e');
      return null;
    }
  }

  // ============================================================================
  // TRANSPORT MODES
  // ============================================================================

  /// Create or get transport mode
  static Future<int?> createTransportMode(String name) async {
    try {
      final response = await _postWithFallback('/transport-modes', {
        'name': name,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int?;
      } else {
        print('Failed to create transport mode: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating transport mode: $e');
      return null;
    }
  }

  // ============================================================================
  // LOCATIONS
  // ============================================================================

  /// Create a location in the database
  static Future<int?> createLocation({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _postWithFallback('/locations', {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int?;
      } else {
        print('Failed to create location: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating location: $e');
      return null;
    }
  }

  // ============================================================================
  // TRAVEL LOGS
  // ============================================================================

  /// Create a travel log entry
  static Future<int?> createTravelLog({
    required int userId,
    String? routeId,
    String? recordedRouteId,
    int? transportModeId,
    required DateTime startedAt,
    required DateTime endedAt,
    required double distanceMeters,
    required int durationSeconds,
    String? notes,
  }) async {
    try {
      final response = await _postWithFallback('/travel_logs', {
        'userId': userId,
        'routeId': routeId,
        'recordedRouteId': recordedRouteId,
        'transportModeId': transportModeId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distance': distanceMeters,
        'duration': durationSeconds,
        'notes': notes,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int?;
      } else {
        print('Failed to create travel log: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating travel log: $e');
      return null;
    }
  }

  // ============================================================================
  // SAFETY REPORTS
  // ============================================================================

  /// Create a safety report
  static Future<int?> createSafetyReport({
    required int userId,
    String? routeId,
    int? locationId,
    required String description,
    int? severity,
  }) async {
    try {
      final response = await _postWithFallback('/safety_reports', {
        'userId': userId,
        'routeId': routeId,
        'locationId': locationId,
        'description': description,
        'severity': severity,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int?;
      } else {
        print('Failed to create safety report: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating safety report: $e');
      return null;
    }
  }

  // ============================================================================
  // INCIDENTS
  // ============================================================================

  /// Create an incident report
  static Future<int?> createIncident({
    int? safetyReportId,
    required String incidentType,
    required String description,
    int? locationId,
    required DateTime occurredAt,
  }) async {
    try {
      final response = await _postWithFallback('/incidents', {
        'safetyReportId': safetyReportId,
        'incidentType': incidentType,
        'description': description,
        'locationId': locationId,
        'occurredAt': occurredAt.toIso8601String(),
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as int?;
      } else {
        print('Failed to create incident: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating incident: $e');
      return null;
    }
  }
}

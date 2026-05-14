import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';

import '../models/recorded_route.dart';

class BackendService {
  static const String _baseUrl = 'http://localhost:3000'; // Change for production

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

  /// Register a new user with the backend
  static Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/register');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Registration failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error registering: $e');
      return null;
    }
  }

  /// Login user with the backend
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Login failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error logging in: $e');
      return null;
    }
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
      final uri = Uri.parse('$_baseUrl/routes/record');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
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
        }),
      );

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
      final uri = Uri.parse('$_baseUrl/routes/user/$userId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = (data['routes'] as List?)
            ?.map((routeJson) => RecordedRoute.fromJson(routeJson as Map<String, dynamic>))
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
      final uri = Uri.parse('$_baseUrl/routes');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'name': name,
          'description': description,
        }),
      );

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
      final uri = Uri.parse('$_baseUrl/transport-modes');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );

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
      final uri = Uri.parse('$_baseUrl/locations');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

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
      final uri = Uri.parse('$_baseUrl/travel_logs');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'routeId': routeId,
          'recordedRouteId': recordedRouteId,
          'transportModeId': transportModeId,
          'startedAt': startedAt.toIso8601String(),
          'endedAt': endedAt.toIso8601String(),
          'distance': distanceMeters,
          'duration': durationSeconds,
          'notes': notes,
        }),
      );

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
      final uri = Uri.parse('$_baseUrl/safety_reports');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'routeId': routeId,
          'locationId': locationId,
          'description': description,
          'severity': severity,
        }),
      );

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
      final uri = Uri.parse('$_baseUrl/incidents');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'safetyReportId': safetyReportId,
          'incidentType': incidentType,
          'description': description,
          'locationId': locationId,
          'occurredAt': occurredAt.toIso8601String(),
        }),
      );

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

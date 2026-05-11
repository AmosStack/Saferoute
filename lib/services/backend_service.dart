import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/recorded_route.dart';

class BackendService {
  static const String _baseUrl = 'http://localhost:3000'; // Change for production

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
}

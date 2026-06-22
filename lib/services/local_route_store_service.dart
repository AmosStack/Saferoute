import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recorded_route.dart';

class LocalRouteStoreService {
  LocalRouteStoreService._();

  static const String _routesKey = 'safe_route_recorded_routes';

  static Future<List<RecordedRoute>> loadRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_routesKey);
    if (raw == null || raw.isEmpty) {
      return const <RecordedRoute>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => RecordedRoute.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const <RecordedRoute>[];
    }
  }

  static Future<void> saveRoute(RecordedRoute route) async {
    final routes = await loadRoutes();
    final updated = <RecordedRoute>[route, ...routes];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _routesKey,
      jsonEncode(updated.map((entry) => entry.toJson()).toList()),
    );
  }
}

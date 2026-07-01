import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../l10n/app_strings.dart';
import '../models/recorded_route.dart';
import '../services/backend_service.dart';
import '../services/local_route_store_service.dart';
import 'map_picker_screen.dart';
import 'profile_settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
    this.user,
    this.onSignOut,
    required this.localeCode,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final AuthUser? user;
  final VoidCallback? onSignOut;
  final String localeCode;
  final ValueChanged<String> onLocaleChanged;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeModeChanged;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late Future<List<RecordedRoute>?> _routesFuture;
  String? _selectedTransportMode;

  @override
  void initState() {
    super.initState();
    _routesFuture = _loadRoutes();
  }

  Future<List<RecordedRoute>?> _loadRoutes() async {
    final localRoutes = await LocalRouteStoreService.loadRoutes();
    final userId = widget.user?.id;
    if (userId == null) {
      return localRoutes;
    }
    final backendRoutes = await BackendService.getUserRoutes(userId);
    if (backendRoutes == null || backendRoutes.isEmpty) {
      return localRoutes;
    }

    final merged = <RecordedRoute>[];
    final seen = <String>{};
    for (final route in [...localRoutes, ...backendRoutes]) {
      final key = [
        route.startTime.toIso8601String(),
        route.endTime.toIso8601String(),
        route.startPoint.latitude.toStringAsFixed(5),
        route.startPoint.longitude.toStringAsFixed(5),
        route.endPoint.latitude.toStringAsFixed(5),
        route.endPoint.longitude.toStringAsFixed(5),
      ].join('|');
      if (seen.add(key)) {
        merged.add(route);
      }
    }
    return merged;
  }

  Future<void> _reloadRoutes() async {
    setState(() {
      _routesFuture = _loadRoutes();
    });
    await _routesFuture;
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) {
      _reloadRoutes();
    }
  }

  void _showRouteOnMap(RecordedRoute route) {
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.localeCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = [
      MapPickerScreen(
        userId: widget.user?.id,
        initialTransportMode: _selectedTransportMode,
        embedded: true,
      ),
      _RouteHistoryPage(
        localeCode: widget.localeCode,
        routesFuture: _routesFuture,
        onRefresh: _reloadRoutes,
        onRouteSelected: _showRouteOnMap,
      ),
      ProfileSettingsScreen(
        user: widget.user,
        localeCode: widget.localeCode,
        onLocaleChanged: widget.onLocaleChanged,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? strings.appName
              : (_currentIndex == 1 ? strings.routes : strings.account),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _switchTab,
        backgroundColor: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.88),
        indicatorColor: const Color(0xFF0E7C7B)
            .withValues(alpha: isDark ? 0.26 : 0.16),
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.08),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.location_on_outlined),
            selectedIcon: const Icon(Icons.location_on),
            label: strings.map,
          ),
          NavigationDestination(
            icon: const Icon(Icons.alt_route_outlined),
            selectedIcon: const Icon(Icons.alt_route),
            label: strings.routes,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: strings.account,
          ),
        ],
      ),
    );
  }
}

class _RouteHistoryPage extends StatefulWidget {
  const _RouteHistoryPage({
    required this.localeCode,
    required this.routesFuture,
    required this.onRefresh,
    required this.onRouteSelected,
  });

  final String localeCode;
  final Future<List<RecordedRoute>?> routesFuture;
  final VoidCallback onRefresh;
  final ValueChanged<RecordedRoute> onRouteSelected;

  @override
  State<_RouteHistoryPage> createState() => _RouteHistoryPageState();
}

class _RouteHistoryPageState extends State<_RouteHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.localeCode);

    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
      },
      child: FutureBuilder<List<RecordedRoute>?>(
        future: widget.routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = snapshot.data ?? [];
          if (routes.isEmpty) {
            return Center(
              child: Text(strings.noSavedRoutes),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              final distance = route.distance;
              final distanceStr = distance < 1000
                  ? '${distance.toStringAsFixed(0)} m'
                  : '${(distance / 1000).toStringAsFixed(2)} km';
              final timeStr = route.durationStr;
              final dateStr =
                  route.startTime.toString().split(' ')[0];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: InkWell(
                    onTap: () {
                      widget.onRouteSelected(route);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // Route endpoints
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    // Start location
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons
                                              .location_on_outlined,
                                          size: 16,
                                          color: Color(
                                              0xFF0E7C7B),
                                        ),
                                        const SizedBox(
                                            width: 6),
                                        Expanded(
                                          child: Text(
                                            route
                                                .startLocationName,
                                            style: const TextStyle(
                                              fontSize:
                                                  13,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              color: Color(
                                                  0xFF0E7C7B),
                                            ),
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Arrow
                                    Padding(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal:
                                                  8),
                                      child: Icon(
                                        Icons
                                            .arrow_downward,
                                        size: 16,
                                        color: Colors
                                            .grey
                                            .shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // End location
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons
                                              .location_on,
                                          size: 16,
                                          color: Colors
                                              .red,
                                        ),
                                        const SizedBox(
                                            width: 6),
                                        Expanded(
                                          child: Text(
                                            route
                                                .endLocationName,
                                            style: const TextStyle(
                                              fontSize:
                                                  13,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          // Route details
                          Row(
                            children: [
                              Icon(
                                Icons.straighten,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                distanceStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.grey.shade600,
                                ),
                              ),
                              const Spacer(),
                              // Transport mode icon
                              Icon(
                                _getTransportModeIcon(
                                    route.transportMode),
                                size: 18,
                                color: const Color(0xFF0E7C7B),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getTransportModeIcon(String mode) {
    return switch (mode.toLowerCase()) {
      'walking' => Icons.directions_walk,
      'bicycle' => Icons.pedal_bike,
      'car' => Icons.directions_car,
      'bus' => Icons.directions_bus,
      'taxi' => Icons.local_taxi,
      'motorcycle' => Icons.two_wheeler,
      'tricycle' => Icons.agriculture,
      _ => Icons.route,
    };
  }
}

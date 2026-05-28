import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../l10n/app_strings.dart';
import '../models/recorded_route.dart';
import '../services/backend_service.dart';
import 'map_picker_screen.dart';
import 'profile_settings_screen.dart';
import '../widgets/modern_surface.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.user,
    this.onSignOut,
    required this.localeCode,
    required this.onLocaleChanged,
  });

  final AuthUser? user;
  final VoidCallback? onSignOut;
  final String localeCode;
  final ValueChanged<String> onLocaleChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late Future<List<RecordedRoute>?> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _loadRoutes();
  }

  Future<List<RecordedRoute>?> _loadRoutes() {
    final userId = widget.user?.id;
    if (userId == null) {
      return Future.value(const <RecordedRoute>[]);
    }
    return BackendService.getUserRoutes(userId);
  }

  Future<void> _reloadRoutes() async {
    setState(() {
      _routesFuture = _loadRoutes();
    });
    await _routesFuture;
  }

  void _openRouteMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(userId: widget.user?.id),
      ),
    );
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) {
      _reloadRoutes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.localeCode);
    final pages = [
      _HomeLandingPage(
        localeCode: widget.localeCode,
        user: widget.user,
        onOpenMap: _openRouteMap,
        onGoToRoutes: () => _switchTab(1),
        onGoToCommunity: () => _switchTab(2),
      ),
      _RouteHistoryPage(
        localeCode: widget.localeCode,
        routesFuture: _routesFuture,
        onRefresh: _reloadRoutes,
      ),
      ProfileSettingsScreen(
        user: widget.user,
        localeCode: widget.localeCode,
        onLocaleChanged: widget.onLocaleChanged,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.user == null ? strings.appName : '${strings.appName} - ${widget.user!.name}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout_outlined),
              tooltip: strings.signOut,
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _switchTab,
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        indicatorColor: const Color(0xFF0E7C7B).withValues(alpha: 0.16),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.alt_route_outlined),
            selectedIcon: const Icon(Icons.alt_route),
            label: strings.routes,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: strings.community,
          ),
        ],
      ),
    );
  }
}

class _HomeLandingPage extends StatelessWidget {
  const _HomeLandingPage({
    required this.localeCode,
    required this.user,
    required this.onOpenMap,
    required this.onGoToRoutes,
    required this.onGoToCommunity,
  });

  final String localeCode;
  final AuthUser? user;
  final VoidCallback onOpenMap;
  final VoidCallback onGoToRoutes;
  final VoidCallback onGoToCommunity;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(localeCode);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _HeroCard(localeCode: localeCode, user: user, onOpenMap: onOpenMap),
        const SizedBox(height: 14),
        GreenSectionHeader(
          title: strings.quickActions,
          subtitle: strings.heroSubtitle,
          trailing: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            _ActionTile(
              title: strings.selectLocation,
              subtitle: strings.selectLocationSubtitle,
              icon: Icons.place_outlined,
              onTap: onOpenMap,
            ),
            _ActionTile(
              title: strings.chooseTransport,
              subtitle: strings.chooseTransportSubtitle,
              icon: Icons.directions_car_outlined,
              onTap: onOpenMap,
            ),
            _ActionTile(
              title: strings.trustedPeople,
              subtitle: strings.trustedPeopleSubtitle,
              icon: Icons.shield_outlined,
              onTap: onGoToCommunity,
            ),
            _ActionTile(
              title: strings.travelHistory,
              subtitle: strings.travelHistorySubtitle,
              icon: Icons.route_outlined,
              onTap: onGoToRoutes,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _InfoCard(
          title: strings.safetyFirst,
          subtitle: strings.safetyFirstSubtitle,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.localeCode,
    required this.user,
    required this.onOpenMap,
  });

  final String localeCode;
  final AuthUser? user;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(localeCode);
    return HoverSurface(
      padding: const EdgeInsets.all(18),
      borderRadius: 26,
      backgroundColor: Colors.transparent,
      gradient: const LinearGradient(
        colors: [Color(0xFF0E7C7B), Color(0xFF274060)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Colors.white.withValues(alpha: 0.12),
      shadowColor: const Color(0xFF0E7C7B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user == null ? strings.planTrip : strings.welcomeUser(user!.name),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            strings.heroSubtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onOpenMap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0E7C7B),
            ),
            child: Text(strings.openRouteMap),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0E7C7B).withValues(alpha: 0.12),
            child: Icon(icon, color: const Color(0xFF0E7C7B)),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _RouteHistoryPage extends StatelessWidget {
  const _RouteHistoryPage({
    required this.localeCode,
    required this.routesFuture,
    required this.onRefresh,
  });

  final String localeCode;
  final Future<List<RecordedRoute>?> routesFuture;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(localeCode);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<List<RecordedRoute>?>(
        future: routesFuture,
        builder: (context, snapshot) {
          final routes = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              GreenSectionHeader(
                title: strings.previousRoutes,
                subtitle: strings.previousRoutesSubtitle,
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _EmptyState(
                  title: strings.couldNotLoadRoutes,
                  subtitle: '${snapshot.error}',
                  icon: Icons.error_outline,
                )
              else if (routes == null || routes.isEmpty)
                _EmptyState(
                  title: strings.noSavedRoutes,
                  subtitle: strings.noSavedRoutesSubtitle,
                  icon: Icons.route_outlined,
                )
              else
                ...routes.map(
                  (route) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SavedRouteCard(localeCode: localeCode, route: route),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({required this.localeCode, required this.route});

  final String localeCode;
  final RecordedRoute route;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(localeCode);
    return HoverSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${route.startLocationName} → ${route.endLocationName}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusPill(label: route.transportMode),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${strings.distance}: ${route.distanceStr} - ${strings.duration}: ${route.durationStr}',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 6),
          Text(
            '${strings.saved}: ${route.startTime.toLocal()} - ${route.endTime.toLocal()}',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.55), fontSize: 12),
          ),
          if (route.notes != null && route.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(route.notes!, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.star, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text(route.rating?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(strings.points(route.coordinates.length)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xFF274060)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0E7C7B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

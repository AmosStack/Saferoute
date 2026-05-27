import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../data/mock_data.dart';
import '../models/recorded_route.dart';
import '../models/safe_route.dart';
import '../services/backend_service.dart';
import 'backend_url_dialog.dart';
import 'map_picker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.user, this.onSignOut});

  final AuthUser? user;
  final VoidCallback? onSignOut;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.user == null ? 'SafeRoute' : 'SafeRoute · ${widget.user!.name}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => showBackendUrlDialog(context),
            icon: const Icon(Icons.link_outlined),
            tooltip: 'Backend URL',
          ),
          if (widget.onSignOut != null)
            IconButton(
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout_outlined),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_currentIndex) {
          0 => _RouteSelectionPage(
              key: const ValueKey('route-selection'),
              userId: widget.user?.id,
            ),
          1 => _RouteHistoryPage(
              key: const ValueKey('route-history'),
              routesFuture: _routesFuture,
              onRefresh: _reloadRoutes,
            ),
          _ => const _CommunityPage(
              key: ValueKey('community'),
            ),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            _reloadRoutes();
          }
        },
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        indicatorColor: const Color(0xFF0E7C7B).withValues(alpha: 0.16),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Route select',
          ),
          NavigationDestination(
            icon: Icon(Icons.alt_route_outlined),
            selectedIcon: Icon(Icons.alt_route),
            label: 'Routes',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}

class _RouteSelectionPage extends StatelessWidget {
  const _RouteSelectionPage({super.key, this.userId});

  final int? userId;

  @override
  Widget build(BuildContext context) {
    return MapPickerScreen(userId: userId, embedded: true);
  }
}

class _RouteHistoryPage extends StatelessWidget {
  const _RouteHistoryPage({super.key, required this.routesFuture, required this.onRefresh});

  final Future<List<RecordedRoute>?> routesFuture;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<List<RecordedRoute>?>(
        future: routesFuture,
        builder: (context, snapshot) {
          final routes = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              const _SectionHeader(
                title: 'All previous routes',
                subtitle: 'Every route you have traveled before, pulled from the backend.',
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _EmptyState(
                  title: 'Could not load routes',
                  subtitle: '${snapshot.error}',
                  icon: Icons.error_outline,
                )
              else if (routes == null || routes.isEmpty)
                const _EmptyState(
                  title: 'No saved routes yet',
                  subtitle: 'When you finish a trip, it will appear here automatically.',
                  icon: Icons.route_outlined,
                )
              else
                ...routes.map(
                  (route) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SavedRouteCard(route: route),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CommunityPage extends StatelessWidget {
  const _CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        const _SectionHeader(
          title: 'Community safety toolkit',
          subtitle: 'Keep support and emergency contacts nearby.',
        ),
        const SizedBox(height: 12),
        ...communityActions.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ActionCard(action: action),
          ),
        ),
        const SizedBox(height: 8),
        const _SectionHeader(
          title: 'Emergency and trusted contacts',
          subtitle: 'Use these when you need help before or during travel.',
        ),
        const SizedBox(height: 12),
        ...emergencyContacts.map(
          (contact) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ContactCard(contact: contact),
          ),
        ),
      ],
    );
  }
}

class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({required this.route});

  final RecordedRoute route;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
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
            'Distance: ${route.distanceStr} · Duration: ${route.durationStr}',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 6),
          Text(
            'Saved: ${route.startTime.toLocal()} - ${route.endTime.toLocal()}',
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
              Text('${route.coordinates.length} points'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final CommunityAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: action.tint.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: action.tint.withValues(alpha: 0.15), child: Icon(action.icon, color: action.tint)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(action.subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.black.withValues(alpha: 0.06), child: Icon(contact.icon, color: const Color(0xFF274060))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(contact.note),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(contact.number, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.black.withValues(alpha: 0.58))),
      ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
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

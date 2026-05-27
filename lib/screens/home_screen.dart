import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import 'map_picker_screen.dart';
import '../data/mock_data.dart';
import '../models/safe_route.dart';
import 'backend_url_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.user, this.onSignOut});

  final AuthUser? user;
  final VoidCallback? onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  CommutePeriod _selectedPeriod = CommutePeriod.evening;
  final List<Map<String, dynamic>> _myRoutes = [];

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
      extendBody: true,
      body: Stack(
        children: [
          const _AppBackdrop(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (_currentIndex) {
                0 => _OverviewTab(
                    key: const ValueKey('overview'),
                    routes: safeRouteRecommendations,
                    insights: transportInsights,
                    userName: widget.user?.name,
                    myRoutes: _myRoutes,
                    onSaveRoute: (route) {
                      setState(() {
                        _myRoutes.insert(0, route);
                      });
                    },
                  ),
                1 => _RoutesTab(
                    key: const ValueKey('routes'),
                    selectedPeriod: _selectedPeriod,
                    onPeriodSelected: (period) {
                      setState(() {
                        _selectedPeriod = period;
                      });
                    },
                    routes: safeRouteRecommendations,
                  ),
                _ => const _CommunityTab(
                    key: ValueKey('community'),
                    actions: communityActions,
                    contacts: emergencyContacts,
                  ),
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        indicatorColor: const Color(0xFF0E7C7B).withValues(alpha: 0.16),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
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

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({super.key, required this.routes, required this.insights, this.userName, required this.myRoutes, this.onSaveRoute});

  final List<SafeRouteRecommendation> routes;
  final List<TransportInsight> insights;
  final String? userName;
  final List<Map<String, dynamic>> myRoutes;
  final ValueChanged<Map<String, dynamic>>? onSaveRoute;

  @override
  Widget build(BuildContext context) {
    final featuredRoute = routes.firstWhere((route) => route.communityVerified);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        _HeroCard(featuredRoute: featuredRoute, userName: userName, onSaveRoute: onSaveRoute),
        const SizedBox(height: 18),
        _InsightGrid(insights: insights),
        _MyRoutesList(routes: myRoutes),
      ],
    );
  }
}

class _MyRoutesList extends StatelessWidget {
  const _MyRoutesList({required this.routes});

  final List<Map<String, dynamic>> routes;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'My routes history',
          subtitle: 'Recent saved route searches',
        ),
        const SizedBox(height: 12),
        ...routes.map((r) {
          final start = r['start'];
          final dest = r['destination'];
          final ts = r['timestamp'] ?? '';
          final startStr = start != null ? '${start.latitude.toStringAsFixed(4)}, ${start.longitude.toStringAsFixed(4)}' : 'Unknown';
          final destStr = dest != null ? '${dest.latitude.toStringAsFixed(4)}, ${dest.longitude.toStringAsFixed(4)}' : 'Unknown';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFF274060)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$startStr → $destStr', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(ts, style: TextStyle(color: Colors.black.withValues(alpha: 0.64))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RoutesTab extends StatelessWidget {
  const _RoutesTab({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodSelected,
    required this.routes,
  });

  final CommutePeriod selectedPeriod;
  final ValueChanged<CommutePeriod> onPeriodSelected;
  final List<SafeRouteRecommendation> routes;

  @override
  Widget build(BuildContext context) {
    final filteredRoutes = routes.where((route) => route.period == selectedPeriod).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        const _SectionHeader(
          title: 'Route recommendation engine',
          subtitle: 'Prioritize well-lit corridors, manageable transfers, and short last-mile walks.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final period = CommutePeriod.values[index];
              return FilterChip(
                label: Text(period.window),
                avatar: Icon(period.icon, size: 18),
                selected: period == selectedPeriod,
                onSelected: (_) => onPeriodSelected(period),
              );
            },
            separatorBuilder: (context, _) => const SizedBox(width: 10),
            itemCount: CommutePeriod.values.length,
          ),
        ),
        const SizedBox(height: 16),
        ...filteredRoutes.map(
          (route) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _RouteCard(route: route),
          ),
        ),
        if (filteredRoutes.isEmpty)
          const _EmptyState(
            title: 'No routes matched this time window',
            subtitle: 'Try another commute period to see verified alternatives.',
            icon: Icons.route_outlined,
          ),
      ],
    );
  }
}

class _CommunityTab extends StatelessWidget {
  const _CommunityTab({
    super.key,
    required this.actions,
    required this.contacts,
  });

  final List<CommunityAction> actions;
  final List<EmergencyContact> contacts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        const _SectionHeader(
          title: 'Community safety toolkit',
          subtitle: 'Turn rider reports into better schedules, safer stops, and faster support.',
        ),
        const SizedBox(height: 12),
        ...actions.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ActionCard(action: action),
          ),
        ),
        const SizedBox(height: 8),
        const _SectionHeader(
          title: 'Emergency and trusted contacts',
          subtitle: 'Keep these details close before you travel and when you arrive.',
        ),
        const SizedBox(height: 12),
        ...contacts.map(
          (contact) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ContactCard(contact: contact),
          ),
        ),
        const SizedBox(height: 8),
        const _SafetyBanner(),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.featuredRoute, this.userName, this.onSaveRoute});

  final SafeRouteRecommendation featuredRoute;
  final String? userName;
  final ValueChanged<Map<String, dynamic>>? onSaveRoute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 13, 172, 84), Color.fromARGB(255, 14, 124, 56), Color.fromARGB(255, 88, 184, 75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.volunteer_activism_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SafeRoute',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ScorePill(score: featuredRoute.safetyScore, lightMode: true),
            ],
          ),
          const SizedBox(height: 20),
          if (featuredRoute.communityVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                userName == null
                    ? 'Session secured through MySQL-backed authentication'
                    : 'Session secured for $userName through MySQL-backed authentication',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Women-centered transport mapping for safer, cheaper, and more predictable commutes.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Route ${featuredRoute.title} is currently the strongest option for the evening window, with verified riders confirming a stable corridor and low-transfer journey${userName == null ? '.' : ' for $userName.'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context)
                      .push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => const MapPickerScreen()))
                      .then((result) {
                    if (result != null) {
                      final start = result['start'];
                      final dest = result['destination'];
                      final saved = {
                        'start': start,
                        'destination': dest,
                        'timestamp': DateTime.now().toIso8601String(),
                      };
                      try {
                        onSaveRoute?.call(saved);
                      } catch (_) {}
                      messenger.showSnackBar(SnackBar(
                        content: Text('Start: ${start?.latitude.toStringAsFixed(4)}, ${start?.longitude.toStringAsFixed(4)}; '
                            'Dest: ${dest?.latitude.toStringAsFixed(4)}, ${dest?.longitude.toStringAsFixed(4)}'),
                      ));
                    }
                  });
                },
                icon: const Icon(Icons.alt_route),
                label: const Text('Find safe route'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                onPressed: () {},
                icon: const Icon(Icons.share_location_outlined),
                label: const Text('Share live trip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightGrid extends StatelessWidget {
  const _InsightGrid({required this.insights});

  final List<TransportInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: insights
          .map(
            (insight) => SizedBox(
              width: 160,
              child: _InsightCard(insight: insight),
            ),
          )
          .toList(),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final TransportInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: insight.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(insight.icon, color: insight.accent),
          ),
          const SizedBox(height: 12),
          Text(
            insight.value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            insight.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            insight.note,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.64),
              height: 1.35,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});

  final SafeRouteRecommendation route;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${route.origin} to ${route.destination}',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _ScorePill(score: route.safetyScore),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: route.period.label, icon: route.period.icon),
              _Tag(label: route.duration, icon: Icons.schedule_outlined),
              _Tag(label: '${route.walkMinutes} min walk', icon: Icons.directions_walk_outlined),
              _Tag(label: '${route.transfers} transfer${route.transfers == 1 ? '' : 's'}', icon: Icons.compare_arrows_outlined),
              if (route.communityVerified)
                const _Tag(label: 'Community verified', icon: Icons.verified_outlined),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            route.summary,
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          _BulletList(title: 'Why it is recommended', items: route.highlights),
          if (route.cautions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _BulletList(
              title: 'Cautions',
              items: route.cautions,
              accent: const Color(0xFFB83B5E),
            ),
          ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: action.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(action.icon, color: action.tint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  action.subtitle,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.64),
                    height: 1.35,
                  ),
                ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF274060).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(contact.icon, color: const Color(0xFF274060)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.number,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E7C7B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  contact.note,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.64),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102B43), Color(0xFF274060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Travel with a plan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Confirm your route before leaving, share your trip with a trusted contact, and avoid low-visibility cut-throughs after dark.',
            style: TextStyle(
              color: Colors.white,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.title, required this.items, this.accent = const Color(0xFF0E7C7B)});

  final String title;
  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.76),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, this.lightMode = false});

  final int score;
  final bool lightMode;

  @override
  Widget build(BuildContext context) {
    final background = lightMode ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF0E7C7B).withValues(alpha: 0.1);
    final foreground = lightMode ? Colors.white : const Color(0xFF0E7C7B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score/100',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF102B43).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF102B43)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF102B43),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
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
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.64),
            height: 1.35,
          ),
        ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF0E7C7B)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black.withValues(alpha: 0.64)),
          ),
        ],
      ),
    );
  }
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F2EA), Color(0xFFE7F0EE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -10,
            child: _BackdropCircle(color: const Color(0xFF0E7C7B).withValues(alpha: 0.12), size: 170),
          ),
          Positioned(
            top: 160,
            left: -40,
            child: _BackdropCircle(color: const Color(0xFFC96B5C).withValues(alpha: 0.1), size: 130),
          ),
          Positioned(
            bottom: 120,
            right: -30,
            child: _BackdropCircle(color: const Color(0xFF274060).withValues(alpha: 0.08), size: 150),
          ),
        ],
      ),
    );
  }
}

class _BackdropCircle extends StatelessWidget {
  const _BackdropCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

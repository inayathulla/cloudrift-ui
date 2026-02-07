import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Persistent layout shell wrapping all screens with a 72px-wide NavigationRail.
///
/// Displays the "CR" logo at the top and six navigation destinations
/// (Dashboard, Scan, Resources, Policies, Compliance, Settings). The
/// selected index is derived from the current [GoRouter] location.
class AppShell extends StatelessWidget {
  /// The routed screen content rendered to the right of the rail.
  final Widget child;

  const AppShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/scan')) return 1;
    if (location.startsWith('/resources')) return 2;
    if (location.startsWith('/policies')) return 3;
    if (location.startsWith('/compliance')) return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    const routes = [
      '/dashboard',
      '/scan',
      '/resources',
      '/policies',
      '/compliance',
      '/settings',
    ];
    if (index < routes.length) {
      context.go(routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 72,
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                right: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accentBlue, AppColors.accentPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'CR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Navigation items
                Expanded(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) =>
                        _onDestinationSelected(context, index),
                    backgroundColor: Colors.transparent,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Dashboard'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.radar_outlined),
                        selectedIcon: Icon(Icons.radar),
                        label: Text('Scan'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.dns_outlined),
                        selectedIcon: Icon(Icons.dns),
                        label: Text('Resources'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.policy_outlined),
                        selectedIcon: Icon(Icons.policy),
                        label: Text('Policies'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.verified_outlined),
                        selectedIcon: Icon(Icons.verified),
                        label: Text('Compliance'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

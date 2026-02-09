import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Persistent layout shell wrapping all screens with a 88px-wide sidebar.
///
/// Displays the "CR" logo at the top and seven navigation destinations
/// (Dashboard, Scan, Builder, Resources, Policies, Compliance, Settings).
/// Each destination has a unique accent color when selected.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _destinations = [
    _NavItem(
      route: '/dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
      color: AppColors.accentBlue,
    ),
    _NavItem(
      route: '/scan',
      icon: Icons.radar_outlined,
      selectedIcon: Icons.radar,
      label: 'Scan',
      color: AppColors.accentTeal,
    ),
    _NavItem(
      route: '/resource-builder',
      icon: Icons.build_outlined,
      selectedIcon: Icons.build,
      label: 'Builder',
      color: AppColors.accentPurple,
    ),
    _NavItem(
      route: '/resources',
      icon: Icons.dns_outlined,
      selectedIcon: Icons.dns,
      label: 'Resources',
      color: Color(0xFFFF6B8A),
    ),
    _NavItem(
      route: '/policies',
      icon: Icons.policy_outlined,
      selectedIcon: Icons.policy,
      label: 'Policies',
      color: AppColors.high,
    ),
    _NavItem(
      route: '/compliance',
      icon: Icons.verified_outlined,
      selectedIcon: Icons.verified,
      label: 'Compliance',
      color: AppColors.low,
    ),
    _NavItem(
      route: '/settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
      color: AppColors.textSecondary,
    ),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 88,
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
                  child: ListView.builder(
                    itemCount: _destinations.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final item = _destinations[index];
                      final isSelected = index == selectedIndex;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => context.go(item.route),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? item.color.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(
                                      color: item.color.withValues(alpha: 0.25))
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? item.selectedIcon : item.icon,
                                  size: 22,
                                  color: isSelected
                                      ? item.color
                                      : AppColors.textTertiary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? item.color
                                        : AppColors.textTertiary,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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

class _NavItem {
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;

  const _NavItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
  });
}

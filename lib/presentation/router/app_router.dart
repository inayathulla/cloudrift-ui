import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/compliance/compliance_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/policies/policies_screen.dart';
import '../screens/resource_detail/resource_detail_screen.dart';
import '../screens/resource_builder/resource_builder_screen.dart';
import '../screens/resources/resources_screen.dart';
import '../screens/scan/scan_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../shell/app_shell.dart';

/// Global navigator key shared with the router.
final routerKey = GlobalKey<NavigatorState>();

/// Application-level [GoRouter] configuration.
///
/// Uses a [ShellRoute] to wrap all screens in [AppShell] (persistent
/// NavigationRail sidebar). All pages use [NoTransitionPage] to avoid
/// slide/fade animations when switching between destinations.
///
/// Routes:
/// - `/dashboard` — [DashboardScreen]
/// - `/scan` — [ScanScreen]
/// - `/resources` — [ResourcesScreen]
/// - `/resources/:resourceId` — [ResourceDetailScreen]
/// - `/policies` — [PoliciesScreen]
/// - `/compliance` — [ComplianceScreen]
/// - `/settings` — [SettingsScreen]
final appRouter = GoRouter(
  navigatorKey: routerKey,
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/scan',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ScanScreen(),
          ),
        ),
        GoRoute(
          path: '/resource-builder',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ResourceBuilderScreen(),
          ),
        ),
        GoRoute(
          path: '/resources',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ResourcesScreen(),
          ),
        ),
        GoRoute(
          path: '/resources/:resourceId',
          pageBuilder: (context, state) => NoTransitionPage(
            child: ResourceDetailScreen(
              resourceId: state.pathParameters['resourceId'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: '/policies',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PoliciesScreen(),
          ),
        ),
        GoRoute(
          path: '/compliance',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ComplianceScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);

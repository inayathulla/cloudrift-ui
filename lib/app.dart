import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/router/app_router.dart';

/// Root widget of the Cloudrift desktop application.
///
/// Configures [MaterialApp.router] with the [CloudriftTheme.dark] theme
/// and [appRouter] for declarative GoRouter navigation.
class CloudriftApp extends StatelessWidget {
  const CloudriftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cloudrift',
      debugShowCheckedModeBanner: false,
      theme: CloudriftTheme.dark(),
      routerConfig: appRouter,
    );
  }
}

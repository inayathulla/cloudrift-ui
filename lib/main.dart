import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/datasources/local_storage_datasource.dart';
import 'data/demo_data.dart';
import 'providers/providers.dart';

/// Application entry point.
///
/// Initializes Flutter bindings and Hive local storage, then launches the
/// app inside a Riverpod [ProviderScope]. The pre-initialized
/// [LocalStorageDatasource] is injected via provider override to avoid
/// late-initialization errors.
///
/// Seeds demo scan data on first launch so all dashboard screens are
/// populated without needing a real CLI scan. Skips if history already exists.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = LocalStorageDatasource();
  await storage.init();

  // Seed demo data on first launch (both web and desktop) so all screens
  // render with meaningful data before a real scan is performed.
  await seedDemoData(storage);

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
      ],
      child: const CloudriftApp(),
    ),
  );
}

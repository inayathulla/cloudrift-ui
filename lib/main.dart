import 'package:flutter/foundation.dart' show kIsWeb;
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
/// On web, seeds demo scan data so all dashboard screens are populated
/// without needing the Cloudrift CLI.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = LocalStorageDatasource();
  await storage.init();

  if (kIsWeb) {
    await seedDemoData(storage);
  }

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
      ],
      child: const CloudriftApp(),
    ),
  );
}

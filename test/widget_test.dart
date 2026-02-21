import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:cloudrift_ui/data/datasources/local_storage_datasource.dart';
import 'package:cloudrift_ui/presentation/router/app_router.dart';
import 'package:cloudrift_ui/providers/providers.dart';

void main() {
  late Directory tempDir;
  late LocalStorageDatasource storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cloudrift_test_');

    // Mock path_provider so Hive.initFlutter can resolve a directory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );

    storage = LocalStorageDatasource();
    await storage.init();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // Use ThemeData.dark() instead of CloudriftTheme.dark() to avoid
  // GoogleFonts HTTP requests that fail in the test binding.
  Widget buildTestApp() {
    return ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage)],
      child: MaterialApp.router(
        title: 'Cloudrift',
        theme: ThemeData.dark(),
        routerConfig: appRouter,
      ),
    );
  }

  testWidgets('App renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    // Pump a few frames (don't use pumpAndSettle — the dashboard has a
    // TweenAnimationBuilder that keeps the framework busy for 1 second).
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('App shell shows all navigation items',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Scan'), findsWidgets);
    expect(find.text('Resources'), findsWidgets);
    expect(find.text('Policies'), findsWidgets);
  });
}

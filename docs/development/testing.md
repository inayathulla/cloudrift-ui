# Testing

## Running Tests

```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/my_test.dart

# Run with verbose output
flutter test --reporter expanded

# Run with coverage
flutter test --coverage
```

## Code Analysis

```bash
# Run the Dart analyzer
flutter analyze

# Fix auto-fixable issues
dart fix --apply
```

The project uses `flutter_lints` for code quality rules defined in `analysis_options.yaml`.

## Test Patterns

### Widget Tests

Test individual screen widgets using `WidgetTester`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Dashboard shows KPI cards', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    expect(find.text('Total Resources'), findsOneWidget);
    expect(find.text('Drifted Resources'), findsOneWidget);
  });
}
```

Wrap widgets in `ProviderScope` to enable Riverpod providers.

### Provider Tests

Test Riverpod providers using a `ProviderContainer`:

```dart
void main() {
  test('complianceScoreProvider computes correct scores', () {
    final container = ProviderContainer(
      overrides: [
        latestScanResultProvider.overrideWithValue(mockScanResult),
      ],
    );

    final score = container.read(complianceScoreProvider);
    expect(score.hipaa, greaterThan(0));
    expect(score.soc2, greaterThan(0));
  });
}
```

### Model Tests

Test JSON serialization/deserialization:

```dart
void main() {
  test('ScanResult.fromJson parses correctly', () {
    final json = {
      'scan_summary': {'service': 's3', 'total_resources': 5},
      'resources': [],
    };

    final result = ScanResult.fromJson(json);
    expect(result.scanSummary.service, 's3');
    expect(result.scanSummary.totalResources, 5);
  });
}
```

## Docker Testing

Test the full Docker deployment with the API server:

```bash
# Build and run
docker build -t cloudrift-ui . && docker run -p 8080:80 cloudrift-ui

# Test health endpoint
curl http://localhost:8080/api/health

# Test scan endpoint
curl -X POST http://localhost:8080/api/scan \
  -H "Content-Type: application/json" \
  -d '{"service":"s3","config_path":"/etc/cloudrift/config/cloudrift-s3.yml"}'
```

## Screenshot Testing

Automated screenshots can be captured with Playwright:

```javascript
const { chromium } = require('playwright');

const routes = [
  '/#/dashboard', '/#/scan', '/#/resource-builder',
  '/#/resources', '/#/policies', '/#/compliance', '/#/settings'
];

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  for (const route of routes) {
    await page.goto(`http://localhost:8080${route}`);
    await page.waitForTimeout(2000);
    await page.screenshot({ path: `screenshot_${route.replace(/[/#]/g, '')}.png` });
  }

  await browser.close();
})();
```

!!! warning "Verify before pushing"
    Always review screenshots manually before committing. Check that all routes render correctly and no "Page Not Found" errors appear.

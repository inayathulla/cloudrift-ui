# Adding Screens

This guide walks through adding a new screen to the Cloudrift UI, following the existing patterns.

## Step 1: Create the Screen Widget

Create a new directory and file under `lib/presentation/screens/`:

```dart
// lib/presentation/screens/my_feature/my_feature_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';

class MyFeatureScreen extends ConsumerWidget {
  const MyFeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Feature',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            // Your content here
          ],
        ),
      ),
    );
  }
}
```

Use `ConsumerWidget` (not `StatelessWidget`) to access Riverpod providers via `ref`.

## Step 2: Add a Route

Register the screen in `lib/presentation/router/app_router.dart`:

```dart
import '../screens/my_feature/my_feature_screen.dart';

// Inside the ShellRoute routes list:
GoRoute(
  path: '/my-feature',
  pageBuilder: (context, state) => const NoTransitionPage(
    child: MyFeatureScreen(),
  ),
),
```

All routes use `NoTransitionPage` to avoid slide/fade animations when switching screens.

## Step 3: Add Navigation Item

Add an entry to the navigation rail in `lib/presentation/shell/app_shell.dart`:

```dart
_NavItem(
  route: '/my-feature',
  icon: Icons.star_outline,
  selectedIcon: Icons.star,
  label: 'Feature',
  color: AppColors.accentTeal,  // Choose an accent color
),
```

Available accent colors:

| Color | Hex | Used By |
|-------|-----|---------|
| `accentBlue` | `#4A9EFF` | Dashboard |
| `accentPurple` | `#9B6DFF` | Builder |
| `accentTeal` | `#00D4AA` | Resources |
| `critical` | `#FF3B30` | — |
| `high` | `#FF9500` | — |
| `info` | `#00B4D8` | — |

## Step 4: Add Provider (if needed)

If your screen needs state management, add a provider to `lib/providers/providers.dart`:

```dart
final myFeatureProvider = StateNotifierProvider<MyFeatureNotifier, MyFeatureState>(
  (ref) {
    final datasource = ref.watch(cliDatasourceProvider);
    return MyFeatureNotifier(datasource);
  },
);
```

## Step 5: Update the Route Comment

Update the doc comment at the top of `app_router.dart` to include the new route:

```dart
/// Routes:
/// - `/dashboard` — [DashboardScreen]
/// - `/my-feature` — [MyFeatureScreen]  // Add this
```

## Patterns to Follow

### Dark Theme

Always use `AppColors` constants — never hardcode colors:

```dart
// Good
color: AppColors.textPrimary

// Bad
color: Color(0xFFE8EAED)
```

### Card Styling

Use the standard card pattern:

```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  ),
  child: // ...
)
```

### Loading States

Use shimmer loading placeholders:

```dart
Shimmer.fromColors(
  baseColor: AppColors.cardBackground,
  highlightColor: AppColors.surfaceElevated,
  child: Container(
    height: 200,
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

### Data Access

Always go through providers — never instantiate datasources directly:

```dart
// Good
final result = ref.watch(latestScanResultProvider);

// Bad
final ds = CliDatasource();
final result = await ds.runScan(...);
```

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Centered placeholder shown when a screen has no data to display.
///
/// Renders a circular icon container, title text, optional subtitle, and an
/// optional action button. Used on the dashboard, resources, and scan
/// screens before the first scan has been run.
class EmptyState extends StatelessWidget {
  /// Large icon displayed inside a tinted circle.
  final IconData icon;

  /// Primary message (e.g. "No scan data yet").
  final String title;

  /// Optional secondary explanation text.
  final String? subtitle;

  /// Label for the optional CTA button.
  final String? actionLabel;

  /// Callback invoked when the CTA button is tapped.
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// KPI card showing a large animated number, label, icon, and optional trend.
///
/// Used on the dashboard to display metrics like "Total Resources" or
/// "Drifts Detected". The value animates from 0 on first render using
/// [TweenAnimationBuilder]. When [previousValue] is provided, a colored
/// trend arrow (up/down) shows the delta since the last scan.
class MetricCard extends StatelessWidget {
  /// Descriptive label below the number (e.g. "Total Resources").
  final String label;

  /// The numeric value to display, as a string.
  final String value;

  /// Icon displayed in the top-left corner.
  final IconData icon;

  /// Override color for the icon. Defaults to [AppColors.accentBlue].
  final Color? iconColor;

  /// Value from the previous scan, used to compute and display a trend arrow.
  final int? previousValue;

  /// When `true`, an upward trend is colored red (bad) and downward green.
  /// Useful for metrics where lower is better (e.g. drift count).
  final bool invertTrend;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.previousValue,
    this.invertTrend = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentNum = int.tryParse(value);
    Widget? trendWidget;

    if (previousValue != null && currentNum != null) {
      final diff = currentNum - previousValue!;
      if (diff != 0) {
        final isUp = diff > 0;
        final isPositive = invertTrend ? !isUp : isUp;
        trendWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUp ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: isPositive ? AppColors.low : AppColors.critical,
            ),
            Text(
              '${diff.abs()}',
              style: TextStyle(
                fontSize: 11,
                color: isPositive ? AppColors.low : AppColors.critical,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.accentBlue)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? AppColors.accentBlue,
                ),
              ),
              const Spacer(),
              if (trendWidget != null) trendWidget,
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, _) {
              return Text(
                animValue.toInt().toString(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

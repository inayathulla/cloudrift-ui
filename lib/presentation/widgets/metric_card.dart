import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// KPI card showing a large animated number, label, icon, and optional trend.
///
/// Used on the dashboard to display metrics like "Total Resources" or
/// "Drifts Detected". The value animates from 0 on first render using
/// [TweenAnimationBuilder]. When [previousValue] is provided, a colored
/// trend arrow (up/down) shows the delta since the last scan.
///
/// When [onTap] is provided, the card becomes clickable with a hover effect
/// and a subtle navigation indicator.
class MetricCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final int? previousValue;
  final bool invertTrend;

  /// Optional suffix displayed after the number (e.g. "%" for compliance).
  final String? suffix;

  /// Optional contextual subtitle shown below the label.
  final String? subtitle;

  /// Navigation callback when the card is tapped.
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.previousValue,
    this.invertTrend = false,
    this.suffix,
    this.subtitle,
    this.onTap,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ?? AppColors.accentBlue;
    final currentNum = int.tryParse(widget.value);
    Widget? trendWidget;

    if (widget.previousValue != null && currentNum != null) {
      final diff = currentNum - widget.previousValue!;
      if (diff != 0) {
        final isUp = diff > 0;
        final isPositive = widget.invertTrend ? !isUp : isUp;
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

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _hovered && widget.onTap != null
            ? color.withValues(alpha: 0.06)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hovered && widget.onTap != null
              ? color.withValues(alpha: 0.3)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: color,
                ),
              ),
              const Spacer(),
              if (trendWidget != null) trendWidget,
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(widget.value) ?? 0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    animValue.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  if (widget.suffix != null)
                    Text(
                      widget.suffix!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: color,
                        height: 1,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onTap != null)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _hovered ? 1.0 : 0.4,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: color,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (widget.onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: card,
        ),
      );
    }

    return card;
  }
}

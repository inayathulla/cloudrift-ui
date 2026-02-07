import 'package:flutter/material.dart';

import '../../data/models/severity.dart';

/// Colored chip displaying a severity level with icon and label.
///
/// Renders the severity's icon and uppercase label on a tinted background.
/// Use [compact] for inline placement within tables or list tiles.
class SeverityBadge extends StatelessWidget {
  /// The severity level to display.
  final Severity severity;

  /// When `true`, uses smaller padding and font size for inline contexts.
  final bool compact;

  const SeverityBadge({
    super.key,
    required this.severity,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: severity.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: severity.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            severity.icon,
            size: compact ? 12 : 14,
            color: severity.color,
          ),
          const SizedBox(width: 4),
          Text(
            severity.label,
            style: TextStyle(
              color: severity.color,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

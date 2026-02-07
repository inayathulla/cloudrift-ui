import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Severity levels for drift detections and policy violations.
///
/// Ordered from most severe (`critical`) to least (`info`).
/// Each level carries associated UI properties: [color], [backgroundColor],
/// [icon], and display [label].
enum Severity {
  critical,
  high,
  medium,
  low,
  info;

  /// Parses a severity string from CLI JSON output, defaulting to [info].
  factory Severity.fromString(String value) {
    return Severity.values.firstWhere(
      (s) => s.name == value.toLowerCase(),
      orElse: () => Severity.info,
    );
  }

  /// Numeric ordering for sorting (lower = more severe).
  int get sortOrder => switch (this) {
    Severity.critical => 0,
    Severity.high => 1,
    Severity.medium => 2,
    Severity.low => 3,
    Severity.info => 4,
  };

  /// Theme color associated with this severity level.
  Color get color => switch (this) {
    Severity.critical => AppColors.critical,
    Severity.high => AppColors.high,
    Severity.medium => AppColors.medium,
    Severity.low => AppColors.low,
    Severity.info => AppColors.info,
  };

  /// Translucent tint color used for badge and chip backgrounds.
  Color get backgroundColor => color.withValues(alpha: 0.12);

  /// Material icon representing this severity level.
  IconData get icon => switch (this) {
    Severity.critical => Icons.error,
    Severity.high => Icons.warning_amber_rounded,
    Severity.medium => Icons.info_outline,
    Severity.low => Icons.check_circle_outline,
    Severity.info => Icons.info_outline,
  };

  /// Capitalized display label (e.g. `Critical`, `High`).
  String get label => switch (this) {
    Severity.critical => 'Critical',
    Severity.high => 'High',
    Severity.medium => 'Medium',
    Severity.low => 'Low',
    Severity.info => 'Info',
  };
}

import 'package:flutter/material.dart';

/// Centralized color palette for the Cloudrift dark theme.
///
/// Organized into: backgrounds, severity levels, text tiers,
/// accent colors, and chart series. All colors are static constants
/// to enable `const` widget usage throughout the app.
class AppColors {
  AppColors._();

  // Backgrounds
  static const background = Color(0xFF0F1419);
  static const cardBackground = Color(0xFF1A1F28);
  static const surfaceElevated = Color(0xFF212832);
  static const border = Color(0xFF2A3441);

  // Severity
  static const critical = Color(0xFFFF3B30);
  static const high = Color(0xFFFF9500);
  static const medium = Color(0xFFFFCC00);
  static const low = Color(0xFF34C759);
  static const info = Color(0xFF00B4D8);

  // Text
  static const textPrimary = Color(0xFFE8EAED);
  static const textSecondary = Color(0xFF8B95A5);
  static const textTertiary = Color(0xFF5A6577);

  // Accents
  static const accentBlue = Color(0xFF4A9EFF);
  static const accentPurple = Color(0xFF9B6DFF);
  static const accentTeal = Color(0xFF00D4AA);

  // Charts
  static const chartLine1 = Color(0xFF4A9EFF);
  static const chartLine2 = Color(0xFF9B6DFF);
  static const chartLine3 = Color(0xFF00D4AA);
  static const chartLine4 = Color(0xFFFF6B8A);
}

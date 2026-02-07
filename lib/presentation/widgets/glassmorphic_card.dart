import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Styled container with card background, 1px border, and 12px radius.
///
/// When [accentColor] is provided, a subtle top-left-to-bottom-right
/// gradient overlay tints the card. Used throughout the dashboard as
/// the primary content container.
class GlassmorphicCard extends StatelessWidget {
  /// Content rendered inside the card.
  final Widget child;

  /// Override padding. Defaults to `EdgeInsets.all(20)`.
  final EdgeInsetsGeometry? padding;

  /// Optional accent tint applied as a linear gradient overlay.
  final Color? accentColor;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
        gradient: accentColor != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor!.withValues(alpha: 0.05),
                  AppColors.cardBackground,
                ],
              )
            : null,
      ),
      child: child,
    );
  }
}

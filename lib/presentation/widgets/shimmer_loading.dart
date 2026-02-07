import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';

/// Dark-themed shimmer placeholder for loading states.
///
/// Renders a rectangular skeleton with a subtle shimmer animation.
/// Configurable [width], [height], and [borderRadius].
class ShimmerLoading extends StatelessWidget {
  /// Width of the placeholder. Defaults to `double.infinity`.
  final double width;

  /// Height of the placeholder. Defaults to `16`.
  final double height;

  /// Corner radius. Defaults to `4`.
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.border,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Card-shaped shimmer placeholder matching the standard card dimensions.
class ShimmerCard extends StatelessWidget {
  /// Height of the placeholder card. Defaults to `120`.
  final double height;

  const ShimmerCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.border,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/compliance_score.dart';
import '../../../providers/providers.dart';
import '../../widgets/glassmorphic_card.dart';

/// Compliance posture overview with animated ring chart and category breakdowns.
///
/// Displays a large animated compliance ring showing the overall pass rate,
/// per-category cards (Security, Tagging, Cost) with mini rings, and a
/// compliance trend line chart derived from scan history.
class ComplianceScreen extends ConsumerWidget {
  const ComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compliance = ref.watch(complianceScoreProvider);
    final history = ref.watch(scanHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compliance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),

            // Main compliance ring
            Center(
              child: _ComplianceRing(
                percentage: compliance.overallPercentage,
                size: 220,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${compliance.passingPolicies} of ${compliance.totalPolicies} policies passing',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Category cards
            Row(
              children: [
                _CategoryCard(
                  name: 'Security',
                  icon: Icons.shield_outlined,
                  score: compliance.categories['security'],
                  color: AppColors.accentBlue,
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  name: 'Tagging',
                  icon: Icons.label_outline,
                  score: compliance.categories['tagging'],
                  color: AppColors.accentPurple,
                ),
                const SizedBox(width: 16),
                _CategoryCard(
                  name: 'Cost',
                  icon: Icons.attach_money,
                  score: compliance.categories['cost'],
                  color: AppColors.accentTeal,
                ),
              ].map((child) => Expanded(child: child)).toList(),
            ),
            const SizedBox(height: 32),

            // Compliance trend
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compliance Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Policy pass rate over time',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: _buildTrendChart(history),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(List history) {
    if (history.length < 2) {
      return const Center(
        child: Text(
          'Need at least 2 scans for trend data',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      );
    }

    final entries = history.take(30).toList().reversed.toList();
    final spots = entries.asMap().entries.map((e) {
      final total =
          e.value.totalResources > 0 ? e.value.totalResources : 1;
      final clean = total - e.value.driftCount;
      final pct = (clean / total * 100).clamp(0.0, 100.0);
      return FlSpot(e.key.toDouble(), pct);
    }).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border,
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value % 25 != 0) return const SizedBox.shrink();
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary),
                );
              },
            ),
          ),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.low,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.low.withValues(alpha: 0.08),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated,
          ),
        ),
      ),
    );
  }
}

/// Animated circular gauge displaying compliance percentage.
///
/// Uses [_RingPainter] to draw a track arc and a foreground sweep arc.
/// Color adapts based on threshold: green (>=90%), amber (>=70%), red (<70%).
class _ComplianceRing extends StatelessWidget {
  final double percentage;
  final double size;

  const _ComplianceRing({required this.percentage, this.size = 200});

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 90
        ? AppColors.low
        : percentage >= 70
            ? AppColors.medium
            : AppColors.critical;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percentage),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              percentage: value,
              color: color,
              trackColor: AppColors.surfaceElevated,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.round()}%',
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Compliant',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [CustomPainter] that draws a circular compliance gauge.
///
/// Paints a full-circle track in [trackColor] and a foreground arc in
/// [color] whose sweep angle is proportional to [percentage].
class _RingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.percentage,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 12.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Arc
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * (percentage / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color;
  }
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final CategoryScore? score;
  final Color color;

  const _CategoryCard({
    required this.name,
    required this.icon,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = score?.percentage ?? 100.0;
    final pctColor = pct >= 90
        ? AppColors.low
        : pct >= 70
            ? AppColors.medium
            : AppColors.critical;

    return GlassmorphicCard(
      accentColor: color,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mini ring
          SizedBox(
            width: 80,
            height: 80,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  painter: _RingPainter(
                    percentage: value,
                    color: pctColor,
                    trackColor: AppColors.surfaceElevated,
                  ),
                  child: Center(
                    child: Text(
                      '${value.round()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: pctColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniStat(
                  label: 'Pass', value: score?.passed ?? 0, color: AppColors.low),
              const SizedBox(width: 16),
              _MiniStat(
                  label: 'Fail',
                  value: score?.failed ?? 0,
                  color: AppColors.critical),
            ],
          ),
          if (score != null && score!.failingPolicyIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: score!.failingPolicyIds.take(5).map((id) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.critical.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    id,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.critical,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

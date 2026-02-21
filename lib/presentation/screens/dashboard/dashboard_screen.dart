import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/policy_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/resource_summary.dart';
import '../../../data/models/severity.dart';
import '../../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/severity_badge.dart';

/// Main dashboard showing KPI cards, drift trend chart, severity breakdown
/// pie chart, framework compliance, top failing policies, recent alerts,
/// and per-service health summaries.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(latestScanResultProvider);
    final history = ref.watch(scanHistoryProvider);
    final compliance = ref.watch(complianceScoreProvider);
    final resources = ref.watch(resourceSummariesProvider);

    if (result == null) {
      return EmptyState(
        icon: Icons.dashboard_outlined,
        title: 'No scan data yet',
        subtitle: 'Run your first scan to see the dashboard',
        actionLabel: 'Go to Scan',
        onAction: () => context.go('/scan'),
      );
    }

    // Compute findings by policy for framework compliance
    final violations = result.policyResult?.violations ?? [];
    final warnings = result.policyResult?.warnings ?? [];
    final allFindings = [...violations, ...warnings];
    final findingsByPolicy = <String, int>{};
    for (final f in allFindings) {
      findingsByPolicy[f.policyId] = (findingsByPolicy[f.policyId] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (result.scanDurationMs > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(result.scanDurationMs),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (result.timestamp.isNotEmpty)
                  Text(
                    'Last scan: ${_formatTimestamp(result.timestamp)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // KPI Cards
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Total Resources',
                    value: result.totalResources.toString(),
                    icon: Icons.dns,
                    iconColor: AppColors.accentBlue,
                    subtitle: result.service.isNotEmpty
                        ? '${result.service} \u2022 ${result.region}'
                        : null,
                    onTap: () => context.go('/resources'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(
                    label: 'Drifts Detected',
                    value: result.driftCount.toString(),
                    icon: Icons.compare_arrows,
                    iconColor: AppColors.high,
                    invertTrend: true,
                    subtitle: result.totalResources > 0
                        ? '${(result.driftCount / result.totalResources * 100).round()}% of resources'
                        : null,
                    onTap: () => context.go('/resources'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(
                    label: 'Policy Violations',
                    value:
                        (result.policyResult?.violations.length ?? 0).toString(),
                    icon: Icons.gpp_bad,
                    iconColor: AppColors.critical,
                    invertTrend: true,
                    subtitle:
                        '${result.policyResult?.passed ?? 0} of ${(result.policyResult?.passed ?? 0) + (result.policyResult?.failed ?? 0)} policies passing',
                    onTap: () => context.go('/policies'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(
                    label: 'Compliance Score',
                    value: compliance.overallPercentage.round().toString(),
                    suffix: '%',
                    icon: Icons.verified_user,
                    iconColor: AppColors.low,
                    subtitle:
                        '${compliance.passingPolicies}/${compliance.totalPolicies} policies',
                    onTap: () => context.go('/compliance'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Charts row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drift Trend
                Expanded(
                  flex: 3,
                  child: GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Drift Trend',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Last 30 scans',
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
                ),
                const SizedBox(width: 16),
                // Severity Breakdown
                Expanded(
                  flex: 2,
                  child: GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Severity Breakdown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: _buildSeverityPie(result),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Framework Compliance + Top Failing Policies
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Framework Compliance
                Expanded(
                  flex: 3,
                  child: GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Framework Compliance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/policies'),
                              child: const Text('View Policies'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: ComplianceFramework.values.map((fw) {
                            final stats =
                                _frameworkStats(fw, findingsByPolicy);
                            return Expanded(
                              child: _FrameworkCard(
                                framework: fw,
                                passing: stats.passing,
                                total: stats.total,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Top Failing Policies
                Expanded(
                  flex: 2,
                  child: GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top Failing Policies',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTopFailingPolicies(findingsByPolicy),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bottom panels
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Alerts
                Expanded(
                  child: GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Recent Alerts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/resources'),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (resources.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No alerts',
                                style:
                                    TextStyle(color: AppColors.textTertiary),
                              ),
                            ),
                          )
                        else
                          ...resources
                              .where((r) => !r.isClean)
                              .take(8)
                              .map((r) => _AlertRow(resource: r)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Service Health
                Expanded(
                  child: GlassmorphicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Service Health',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ServiceHealthCard(
                          service: 'S3',
                          icon: Icons.cloud_outlined,
                          total: result.service == 'S3'
                              ? result.totalResources
                              : 0,
                          withDrift:
                              result.service == 'S3' ? result.driftCount : 0,
                        ),
                        const SizedBox(height: 12),
                        _ServiceHealthCard(
                          service: 'EC2',
                          icon: Icons.computer_outlined,
                          total: result.service == 'EC2'
                              ? result.totalResources
                              : 0,
                          withDrift:
                              result.service == 'EC2' ? result.driftCount : 0,
                        ),
                        const SizedBox(height: 12),
                        _ServiceHealthCard(
                          service: 'IAM',
                          icon: Icons.shield_outlined,
                          total: result.service == 'IAM'
                              ? result.totalResources
                              : 0,
                          withDrift:
                              result.service == 'IAM' ? result.driftCount : 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
      return FlSpot(e.key.toDouble(), e.value.driftCount.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border,
            strokeWidth: 0.5,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accentBlue,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accentBlue.withValues(alpha: 0.08),
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

  Widget _buildSeverityPie(result) {
    final violations = result.policyResult?.violations ?? [];
    final warnings = result.policyResult?.warnings ?? [];
    final all = [...violations, ...warnings];

    if (all.isEmpty && result.driftCount == 0) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 48, color: AppColors.low),
            SizedBox(height: 8),
            Text('All Clear',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final counts = <Severity, int>{};
    for (final v in all) {
      final s = Severity.fromString(v.severity);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    if (counts.isEmpty && result.driftCount > 0) {
      counts[Severity.medium] = result.driftCount;
    }

    final sections = counts.entries.map((e) {
      return PieChartSectionData(
        color: e.key.color,
        value: e.value.toDouble(),
        title: '${e.value}',
        radius: 36,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  _FrameworkStat _frameworkStats(
    ComplianceFramework fw,
    Map<String, int> findingsByPolicy,
  ) {
    final policies = PolicyCatalog.policies.values
        .where((p) => p.frameworks.contains(fw))
        .toList();
    final total = policies.length;
    final failing =
        policies.where((p) => (findingsByPolicy[p.id] ?? 0) > 0).length;
    return _FrameworkStat(passing: total - failing, total: total);
  }

  Widget _buildTopFailingPolicies(Map<String, int> findingsByPolicy) {
    final failing = findingsByPolicy.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (failing.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 36, color: AppColors.low),
              SizedBox(height: 8),
              Text(
                'All policies passing',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: failing.take(5).map((entry) {
        final policy = PolicyCatalog.policies[entry.key];
        if (policy == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: policy.defaultSeverity.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policy.id,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentBlue,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        policy.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.critical.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.critical,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  String _formatDuration(int ms) {
    final totalSeconds = ms / 1000;
    if (totalSeconds < 60) {
      return '${totalSeconds.toStringAsFixed(1)}s';
    }
    final mins = totalSeconds ~/ 60;
    final secs = (totalSeconds % 60).toStringAsFixed(1);
    return '${mins}m ${secs}s';
  }
}

// ---------------------------------------------------------------------------
// Framework compliance card with circular progress
// ---------------------------------------------------------------------------

class _FrameworkStat {
  final int passing;
  final int total;
  const _FrameworkStat({required this.passing, required this.total});
}

class _FrameworkCard extends StatelessWidget {
  final ComplianceFramework framework;
  final int passing;
  final int total;

  const _FrameworkCard({
    required this.framework,
    required this.passing,
    required this.total,
  });

  Color get _color => switch (framework) {
    ComplianceFramework.hipaa => const Color(0xFF4FC3F7),
    ComplianceFramework.gdpr => const Color(0xFF81C784),
    ComplianceFramework.iso27001 => const Color(0xFFFFB74D),
    ComplianceFramework.pciDss => const Color(0xFFE57373),
    ComplianceFramework.soc2 => const Color(0xFFCE93D8),
  };

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (passing / total * 100) : 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percentage / 100),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  painter: _CircularProgressPainter(
                    progress: value,
                    color: _color,
                    trackColor: AppColors.border,
                    strokeWidth: 5,
                  ),
                  child: Center(
                    child: Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _color,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            framework.shortLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
          Text(
            '$passing/$total',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter old) =>
      old.progress != progress;
}

// ---------------------------------------------------------------------------
// Alert row
// ---------------------------------------------------------------------------

class _AlertRow extends StatelessWidget {
  final ResourceSummary resource;

  const _AlertRow({required this.resource});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: resource.highestSeverity.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.resourceName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${resource.driftCount} drifts, ${resource.violationCount} violations',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SeverityBadge(severity: resource.highestSeverity, compact: true),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service health card
// ---------------------------------------------------------------------------

class _ServiceHealthCard extends StatelessWidget {
  final String service;
  final IconData icon;
  final int total;
  final int withDrift;

  const _ServiceHealthCard({
    required this.service,
    required this.icon,
    required this.total,
    required this.withDrift,
  });

  @override
  Widget build(BuildContext context) {
    final clean = total - withDrift;
    final percentage = total > 0 ? (clean / total * 100) : 100.0;
    final color = percentage >= 90
        ? AppColors.low
        : percentage >= 70
            ? AppColors.medium
            : AppColors.critical;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$total resources',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${percentage.round()}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

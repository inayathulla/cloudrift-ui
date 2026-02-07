import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/resource_summary.dart';
import '../../../data/models/severity.dart';
import '../../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/severity_badge.dart';

/// Main dashboard showing KPI cards, drift trend chart, severity breakdown
/// pie chart, recent alerts, and per-service health summaries.
///
/// Displays an [EmptyState] when no scan data exists, prompting navigation
/// to the Scan screen. All data is derived reactively from
/// [latestScanResultProvider], [scanHistoryProvider],
/// [complianceScoreProvider], and [resourceSummariesProvider].
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
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(
                    label: 'Compliance',
                    value: compliance.overallPercentage.round().toString(),
                    icon: Icons.verified_user,
                    iconColor: AppColors.low,
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

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

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

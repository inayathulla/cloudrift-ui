import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/resource_summary.dart';
import '../../../data/models/severity.dart';
import '../../../providers/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/severity_badge.dart';

/// Filterable list of all scanned AWS resources with drift/violation summaries.
///
/// Displays stat chips (total, with drift, clean) and filter controls for
/// service type, severity level, and text search. Each resource card shows
/// a severity-colored accent bar, service icon, drift count, and navigates
/// to [ResourceDetailScreen] on tap.
class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  String _serviceFilter = 'All';
  Severity? _severityFilter;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final resources = ref.watch(resourceSummariesProvider);

    final queryLower = _searchQuery.toLowerCase();
    final filtered = resources.where((r) {
      if (_serviceFilter != 'All' &&
          !r.service.toUpperCase().startsWith(_serviceFilter.toUpperCase())) {
        return false;
      }
      if (_severityFilter != null && r.highestSeverity != _severityFilter) {
        return false;
      }
      if (queryLower.isNotEmpty &&
          !r.resourceName.toLowerCase().contains(queryLower) &&
          !r.resourceId.toLowerCase().contains(queryLower)) {
        return false;
      }
      return true;
    }).toList();

    var withDrift = 0;
    var clean = 0;
    for (final r in resources) {
      if (r.hasDrift) withDrift++;
      if (r.isClean) clean++;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resources',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats row
                Row(
                  children: [
                    _StatChip(
                      label: 'Total',
                      value: resources.length.toString(),
                      color: AppColors.accentBlue,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'With Drift',
                      value: withDrift.toString(),
                      color: AppColors.high,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Clean',
                      value: clean.toString(),
                      color: AppColors.low,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filter bar
                Row(
                  children: [
                    // Service chips
                    ...['All', 'S3', 'EC2', 'IAM'].map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: _serviceFilter == s,
                            onSelected: (_) =>
                                setState(() => _serviceFilter = s),
                          ),
                        )),
                    const SizedBox(width: 8),
                    // Severity chips
                    ...[Severity.critical, Severity.high, Severity.medium]
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(s.label),
                                selected: _severityFilter == s,
                                onSelected: (selected) {
                                  setState(() {
                                    _severityFilter = selected ? s : null;
                                  });
                                },
                                selectedColor: s.backgroundColor,
                                side: BorderSide(
                                  color: _severityFilter == s
                                      ? s.color
                                      : AppColors.border,
                                ),
                              ),
                            )),
                    const Spacer(),
                    // Search
                    SizedBox(
                      width: 240,
                      child: TextField(
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search resources...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Resource list
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.dns_outlined,
                    title: 'No resources found',
                    subtitle: 'Run a scan or adjust your filters',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      return _ResourceCard(
                        resource: r,
                        onTap: () => context.go(
                            '/resources/${Uri.encodeComponent(r.resourceId)}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final ResourceSummary resource;
  final VoidCallback onTap;

  const _ResourceCard({required this.resource, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final severity = resource.highestSeverity;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Severity accent bar
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: severity.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                // Service icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    switch (resource.service) {
                      'S3' => Icons.cloud_outlined,
                      'IAM' => Icons.admin_panel_settings_outlined,
                      _ => Icons.computer_outlined,
                    },
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                // Name & type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.resourceName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resource.resourceType,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Drift count
                if (resource.driftCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.high.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${resource.driftCount} drifts',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.high,
                      ),
                    ),
                  ),
                SeverityBadge(severity: severity, compact: true),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/policy_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/severity.dart';
import '../../../providers/providers.dart';
import '../../widgets/severity_badge.dart';

/// Tabbed view of all 21 OPA policies with pass/fail status, violation counts,
/// framework badges, severity sorting, and filters.
///
/// Tabs: All, Security, Tagging, Cost. Each tab shows a badge with the number
/// of active violations. Policies are listed as expandable tiles showing
/// description, remediation guidance, framework tags, and affected resources.
class PoliciesScreen extends ConsumerStatefulWidget {
  const PoliciesScreen({super.key});

  @override
  ConsumerState<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends ConsumerState<PoliciesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sorting
  bool _sortBySeverity = false;

  // Filters
  Severity? _severityFilter;
  ComplianceFramework? _frameworkFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<PolicyDefinition> _applyFiltersAndSort(
    List<PolicyDefinition> policies,
    Map<String, int> findingsByPolicy,
  ) {
    var filtered = policies.toList();

    // Filter by severity
    if (_severityFilter != null) {
      filtered = filtered
          .where((p) => p.defaultSeverity == _severityFilter)
          .toList();
    }

    // Filter by framework
    if (_frameworkFilter != null) {
      filtered = filtered
          .where((p) => p.frameworks.contains(_frameworkFilter))
          .toList();
    }

    // Filter by status
    if (_statusFilter == _StatusFilter.violated) {
      filtered = filtered
          .where((p) => (findingsByPolicy[p.id] ?? 0) > 0)
          .toList();
    } else if (_statusFilter == _StatusFilter.passed) {
      filtered = filtered
          .where((p) => (findingsByPolicy[p.id] ?? 0) == 0)
          .toList();
    }

    // Sort by severity
    if (_sortBySeverity) {
      filtered.sort(
          (a, b) => a.defaultSeverity.sortOrder.compareTo(b.defaultSeverity.sortOrder));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(latestScanResultProvider);
    final violations = result?.policyResult?.violations ?? [];
    final warnings = result?.policyResult?.warnings ?? [];
    final allFindings = [...violations, ...warnings];

    // Group findings by policy ID
    final findingsByPolicy = <String, int>{};
    for (final f in allFindings) {
      findingsByPolicy[f.policyId] = (findingsByPolicy[f.policyId] ?? 0) + 1;
    }

    final allPolicies = PolicyCatalog.policies.values.toList();
    final securityPolicies =
        PolicyCatalog.byCategory(PolicyCategory.security);
    final taggingPolicies =
        PolicyCatalog.byCategory(PolicyCategory.tagging);
    final costPolicies = PolicyCatalog.byCategory(PolicyCategory.cost);

    int countFindings(List<PolicyDefinition> policies) {
      return policies.fold<int>(
          0, (sum, p) => sum + (findingsByPolicy[p.id] ?? 0));
    }

    final hasActiveFilters =
        _severityFilter != null || _frameworkFilter != null || _statusFilter != _StatusFilter.all;

    // Cache filtered results once per build (avoids 8x recalculation)
    final filteredAll = _applyFiltersAndSort(allPolicies, findingsByPolicy);
    final filteredSecurity = _applyFiltersAndSort(securityPolicies, findingsByPolicy);
    final filteredTagging = _applyFiltersAndSort(taggingPolicies, findingsByPolicy);
    final filteredCost = _applyFiltersAndSort(costPolicies, findingsByPolicy);

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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Policies',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Sort toggle
                    _ActionChip(
                      icon: Icons.sort,
                      label: 'Severity',
                      active: _sortBySeverity,
                      onTap: () => setState(() => _sortBySeverity = !_sortBySeverity),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filters row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Severity filter
                      _FilterDropdown<Severity>(
                        label: 'Severity',
                        value: _severityFilter,
                        items: Severity.values,
                        itemLabel: (s) => s.label,
                        itemColor: (s) => s.color,
                        onChanged: (v) => setState(() => _severityFilter = v),
                      ),
                      const SizedBox(width: 8),
                      // Framework filter
                      _FilterDropdown<ComplianceFramework>(
                        label: 'Framework',
                        value: _frameworkFilter,
                        items: ComplianceFramework.values,
                        itemLabel: (f) => f.label,
                        onChanged: (v) => setState(() => _frameworkFilter = v),
                      ),
                      const SizedBox(width: 8),
                      // Status filter
                      _FilterDropdown<_StatusFilter>(
                        label: 'Status',
                        value: _statusFilter == _StatusFilter.all ? null : _statusFilter,
                        items: [_StatusFilter.violated, _StatusFilter.passed],
                        itemLabel: (s) => s.label,
                        onChanged: (v) => setState(() => _statusFilter = v ?? _StatusFilter.all),
                      ),
                      if (hasActiveFilters) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() {
                            _severityFilter = null;
                            _frameworkFilter = null;
                            _statusFilter = _StatusFilter.all;
                          }),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.critical.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.critical.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.clear, size: 14, color: AppColors.critical),
                                SizedBox(width: 4),
                                Text(
                                  'Clear filters',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.critical,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.accentBlue,
                  labelColor: AppColors.accentBlue,
                  unselectedLabelColor: AppColors.textTertiary,
                  dividerColor: AppColors.border,
                  tabs: [
                    _TabWithBadge(
                      'All',
                      countFindings(allPolicies),
                      filteredAll.length,
                      allPolicies.length,
                    ),
                    _TabWithBadge(
                      'Security',
                      countFindings(securityPolicies),
                      filteredSecurity.length,
                      securityPolicies.length,
                    ),
                    _TabWithBadge(
                      'Tagging',
                      countFindings(taggingPolicies),
                      filteredTagging.length,
                      taggingPolicies.length,
                    ),
                    _TabWithBadge(
                      'Cost',
                      countFindings(costPolicies),
                      filteredCost.length,
                      costPolicies.length,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PolicyList(
                    policies: filteredAll,
                    findingsByPolicy: findingsByPolicy),
                _PolicyList(
                    policies: filteredSecurity,
                    findingsByPolicy: findingsByPolicy),
                _PolicyList(
                    policies: filteredTagging,
                    findingsByPolicy: findingsByPolicy),
                _PolicyList(
                    policies: filteredCost,
                    findingsByPolicy: findingsByPolicy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status filter enum
// ---------------------------------------------------------------------------

enum _StatusFilter {
  all,
  violated,
  passed;

  String get label => switch (this) {
    _StatusFilter.all => 'All',
    _StatusFilter.violated => 'Violated',
    _StatusFilter.passed => 'Passed',
  };
}

// ---------------------------------------------------------------------------
// Action chip (sort toggle)
// ---------------------------------------------------------------------------

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accentBlue.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppColors.accentBlue.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: active ? AppColors.accentBlue : AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.accentBlue : AppColors.textSecondary,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_downward, size: 12, color: AppColors.accentBlue),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter dropdown
// ---------------------------------------------------------------------------

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final Color Function(T)? itemColor;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    this.itemColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;

    return PopupMenuButton<T?>(
      onSelected: (v) => onChanged(v),
      offset: const Offset(0, 36),
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<T?>(
          value: null,
          child: Text(
            'All',
            style: TextStyle(
              fontSize: 13,
              color: value == null ? AppColors.accentBlue : AppColors.textSecondary,
              fontWeight: value == null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        ...items.map((item) => PopupMenuItem<T?>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (itemColor != null)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: itemColor!(item),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    itemLabel(item),
                    style: TextStyle(
                      fontSize: 13,
                      color: value == item
                          ? AppColors.accentBlue
                          : AppColors.textSecondary,
                      fontWeight:
                          value == item ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentBlue.withValues(alpha: 0.1)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? AppColors.accentBlue.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? itemLabel(value as T) : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.accentBlue : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 14,
              color: isActive ? AppColors.accentBlue : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab with badge (count of violations + total policy count)
// ---------------------------------------------------------------------------

class _TabWithBadge extends StatelessWidget {
  final String label;
  final int violationCount;
  final int filteredCount;
  final int totalCount;

  const _TabWithBadge(this.label, this.violationCount, this.filteredCount, this.totalCount);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          // Total policy count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$filteredCount',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          if (violationCount > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.critical.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$violationCount',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.critical,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Framework badge chip
// ---------------------------------------------------------------------------

class _FrameworkBadge extends StatelessWidget {
  final ComplianceFramework framework;

  const _FrameworkBadge(this.framework);

  Color get _color => switch (framework) {
    ComplianceFramework.hipaa => const Color(0xFF4FC3F7),
    ComplianceFramework.gdpr => const Color(0xFF81C784),
    ComplianceFramework.iso27001 => const Color(0xFFFFB74D),
    ComplianceFramework.pciDss => const Color(0xFFE57373),
    ComplianceFramework.soc2 => const Color(0xFFCE93D8),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        framework.shortLabel,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Policy list
// ---------------------------------------------------------------------------

class _PolicyList extends StatelessWidget {
  final List<PolicyDefinition> policies;
  final Map<String, int> findingsByPolicy;

  const _PolicyList({
    required this.policies,
    required this.findingsByPolicy,
  });

  @override
  Widget build(BuildContext context) {
    if (policies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'No policies match the current filters',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: policies.length,
      itemBuilder: (context, index) {
        final policy = policies[index];
        final findings = findingsByPolicy[policy.id] ?? 0;
        final passed = findings == 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            collapsedBackgroundColor: AppColors.cardBackground,
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            leading: Icon(
              passed ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: passed ? AppColors.low : AppColors.critical,
            ),
            title: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    policy.id,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentBlue,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    policy.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: policy.frameworks.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: policy.frameworks
                          .map((f) => _FrameworkBadge(f))
                          .toList(),
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (findings > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.critical.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$findings',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.critical,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                SeverityBadge(
                    severity: policy.defaultSeverity, compact: true),
              ],
            ),
            children: [
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              // Framework badges row in expanded view
              if (policy.frameworks.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'FRAMEWORKS',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ...policy.frameworks.map((f) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _frameworkColor(f).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: _frameworkColor(f).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              f.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _frameworkColor(f),
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (policy.frameworks.isEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'FRAMEWORKS',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Best Practice',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DESCRIPTION',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          policy.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REMEDIATION',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            policy.remediation,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (findings > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.critical.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.critical.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 16, color: AppColors.critical),
                      const SizedBox(width: 8),
                      Text(
                        '$findings resource(s) violating this policy',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.critical,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

Color _frameworkColor(ComplianceFramework f) => switch (f) {
  ComplianceFramework.hipaa => const Color(0xFF4FC3F7),
  ComplianceFramework.gdpr => const Color(0xFF81C784),
  ComplianceFramework.iso27001 => const Color(0xFFFFB74D),
  ComplianceFramework.pciDss => const Color(0xFFE57373),
  ComplianceFramework.soc2 => const Color(0xFFCE93D8),
};

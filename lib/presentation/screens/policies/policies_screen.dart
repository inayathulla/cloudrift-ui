import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/policy_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/providers.dart';
import '../../widgets/severity_badge.dart';

/// Tabbed view of all 21 OPA policies with pass/fail status and violation counts.
///
/// Tabs: All, Security, Tagging, Cost. Each tab shows a badge with the number
/// of active violations. Policies are listed as expandable tiles showing
/// description, remediation guidance, and affected resource counts.
class PoliciesScreen extends ConsumerStatefulWidget {
  const PoliciesScreen({super.key});

  @override
  ConsumerState<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends ConsumerState<PoliciesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
                  'Policies',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.accentBlue,
                  labelColor: AppColors.accentBlue,
                  unselectedLabelColor: AppColors.textTertiary,
                  dividerColor: AppColors.border,
                  tabs: [
                    _TabWithBadge('All', allFindings.length),
                    _TabWithBadge(
                        'Security', countFindings(securityPolicies)),
                    _TabWithBadge(
                        'Tagging', countFindings(taggingPolicies)),
                    _TabWithBadge('Cost', countFindings(costPolicies)),
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
                    policies: allPolicies,
                    findingsByPolicy: findingsByPolicy),
                _PolicyList(
                    policies: securityPolicies,
                    findingsByPolicy: findingsByPolicy),
                _PolicyList(
                    policies: taggingPolicies,
                    findingsByPolicy: findingsByPolicy),
                _PolicyList(
                    policies: costPolicies,
                    findingsByPolicy: findingsByPolicy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  final String label;
  final int count;

  const _TabWithBadge(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.critical.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
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

class _PolicyList extends StatelessWidget {
  final List<PolicyDefinition> policies;
  final Map<String, int> findingsByPolicy;

  const _PolicyList({
    required this.policies,
    required this.findingsByPolicy,
  });

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(width: 12),
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
            trailing: SeverityBadge(
                severity: policy.defaultSeverity, compact: true),
            children: [
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
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
                          'Remediation',
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

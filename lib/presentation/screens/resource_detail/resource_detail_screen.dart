import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/severity.dart';
import '../../../providers/providers.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/severity_badge.dart';

/// Detailed view of a single AWS resource showing drift diffs and policy violations.
///
/// The centerpiece is the drift diff viewer: a three-column table comparing
/// each attribute's expected (Terraform) value against the actual (AWS) value,
/// color-coded green/red. Extra attributes (in AWS but not in Terraform) are
/// shown in amber. Policy violations are listed below with remediation guidance.
class ResourceDetailScreen extends ConsumerWidget {
  /// URL-encoded resource ID from the route parameter.
  final String resourceId;

  const ResourceDetailScreen({super.key, required this.resourceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(resourceSummariesProvider);
    final decodedId = Uri.decodeComponent(resourceId);
    final resource = resources
        .where((r) => r.resourceId == decodedId)
        .firstOrNull;

    if (resource == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Resource not found',
                  style: TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/resources'),
                child: const Text('Back to Resources'),
              ),
            ],
          ),
        ),
      );
    }

    final drift = resource.driftInfo;
    final monoStyle = GoogleFonts.jetBrainsMono(fontSize: 13);

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
                IconButton(
                  onPressed: () => context.go('/resources'),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resource.resourceName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SeverityBadge(severity: resource.highestSeverity),
              ],
            ),
            const SizedBox(height: 24),

            // Metadata card
            GlassmorphicCard(
              child: Row(
                children: [
                  _MetaItem(label: 'Type', value: resource.resourceType),
                  _MetaItem(label: 'ID', value: resource.resourceId),
                  _MetaItem(label: 'Service', value: resource.service),
                  _MetaItem(
                    label: 'Status',
                    value: resource.isClean ? 'Clean' : 'Drift Detected',
                    valueColor:
                        resource.isClean ? AppColors.low : AppColors.high,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Drift Diff Viewer
            if (drift != null && drift.hasDrift) ...[
              const Text(
                'Configuration Drift',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              if (drift.missing)
                GlassmorphicCard(
                  accentColor: AppColors.critical,
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppColors.critical),
                      const SizedBox(width: 12),
                      const Text(
                        'Resource exists in Terraform plan but NOT in AWS',
                        style: TextStyle(
                          color: AppColors.critical,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GlassmorphicCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        // Header row
                        Container(
                          color: AppColors.surfaceElevated,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text('Attribute',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Expected (Terraform)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text('Actual (AWS)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ),
                            ],
                          ),
                        ),
                        // Diff rows
                        ...drift.diffs.entries.map((entry) {
                          final expected =
                              entry.value.isNotEmpty ? entry.value[0] : '';
                          final actual =
                              entry.value.length > 1 ? entry.value[1] : '';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                  top: BorderSide(color: AppColors.border)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.key,
                                    style: monoStyle.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.low.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$expected',
                                      style: monoStyle.copyWith(
                                          color: AppColors.low),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.critical
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$actual',
                                      style: monoStyle.copyWith(
                                          color: AppColors.critical),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        // Extra attributes
                        ...drift.extraAttributes.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                  top: BorderSide(color: AppColors.border)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.key,
                                    style: monoStyle.copyWith(
                                      color: AppColors.medium,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '(not in plan)',
                                    style: monoStyle.copyWith(
                                        color: AppColors.textTertiary,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.medium
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${entry.value}',
                                      style: monoStyle.copyWith(
                                          color: AppColors.medium),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],

            // Policy Violations
            if (resource.violations.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Policy Violations (${resource.violations.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...resource.violations.map((v) {
                final severity = Severity.fromString(v.severity);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassmorphicCard(
                    accentColor: severity.color,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                v.policyId,
                                style: monoStyle.copyWith(
                                  fontSize: 12,
                                  color: AppColors.accentBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                v.policyName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            SeverityBadge(
                                severity: severity, compact: true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          v.message,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (v.remediation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline,
                                    size: 16, color: AppColors.medium),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    v.remediation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontFamily: monoStyle.fontFamily,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],

            if (resource.isClean)
              GlassmorphicCard(
                accentColor: AppColors.low,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.low, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'This resource is clean - no drift or policy violations',
                      style: TextStyle(
                        color: AppColors.low,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

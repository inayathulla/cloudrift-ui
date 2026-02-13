import 'policy_violation.dart';

/// Aggregated result from the OPA policy evaluation engine.
///
/// Maps to `output.PolicyOutput` in `internal/output/formatter.go`.
/// Contains lists of violations (blocking) and warnings (advisory),
/// pass/fail counts, and per-category/framework compliance scoring
/// computed by the CLI.
class EvaluationResult {
  /// Policy violations that indicate a blocking compliance failure.
  final List<PolicyViolation> violations;

  /// Policy warnings that are advisory and non-blocking.
  final List<PolicyViolation> warnings;

  /// Number of policies that passed evaluation.
  final int passed;

  /// Number of policies that failed evaluation.
  final int failed;

  /// CLI-computed compliance scores (overall, per-category, per-framework).
  /// Null if the CLI did not include compliance data.
  final CliCompliance? compliance;

  const EvaluationResult({
    this.violations = const [],
    this.warnings = const [],
    this.passed = 0,
    this.failed = 0,
    this.compliance,
  });

  /// Whether any blocking policy violations were found.
  bool get hasViolations => violations.isNotEmpty;

  /// Total number of policies that were evaluated.
  int get totalEvaluated => passed + failed;

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      violations: (json['violations'] as List<dynamic>?)
              ?.map((v) => PolicyViolation.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((w) => PolicyViolation.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
      passed: json['passed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      compliance: json['compliance'] != null
          ? CliCompliance.fromJson(json['compliance'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'violations': violations.map((v) => v.toJson()).toList(),
        'warnings': warnings.map((w) => w.toJson()).toList(),
        'passed': passed,
        'failed': failed,
        if (compliance != null) 'compliance': compliance!.toJson(),
      };
}

/// CLI-computed compliance scoring included in the policy_result JSON.
class CliCompliance {
  final double overallPercentage;
  final int totalPolicies;
  final int passingPolicies;
  final int failingPolicies;

  /// Per-category scores keyed by category name (security, tagging, cost).
  final Map<String, CliComplianceEntry> categories;

  /// Per-framework scores keyed by framework key (hipaa, soc2, etc.).
  final Map<String, CliComplianceEntry> frameworks;

  const CliCompliance({
    this.overallPercentage = 100.0,
    this.totalPolicies = 0,
    this.passingPolicies = 0,
    this.failingPolicies = 0,
    this.categories = const {},
    this.frameworks = const {},
  });

  factory CliCompliance.fromJson(Map<String, dynamic> json) {
    return CliCompliance(
      overallPercentage:
          (json['overall_percentage'] as num?)?.toDouble() ?? 100.0,
      totalPolicies: json['total_policies'] as int? ?? 0,
      passingPolicies: json['passing_policies'] as int? ?? 0,
      failingPolicies: json['failing_policies'] as int? ?? 0,
      categories: _parseEntries(json['categories']),
      frameworks: _parseEntries(json['frameworks']),
    );
  }

  static Map<String, CliComplianceEntry> _parseEntries(dynamic raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map((k, v) => MapEntry(
        k, CliComplianceEntry.fromJson(v as Map<String, dynamic>)));
  }

  Map<String, dynamic> toJson() => {
        'overall_percentage': overallPercentage,
        'total_policies': totalPolicies,
        'passing_policies': passingPolicies,
        'failing_policies': failingPolicies,
        'categories':
            categories.map((k, v) => MapEntry(k, v.toJson())),
        'frameworks':
            frameworks.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// A single compliance entry for a category or framework.
class CliComplianceEntry {
  final double percentage;
  final int passed;
  final int failed;
  final int total;

  const CliComplianceEntry({
    this.percentage = 100.0,
    this.passed = 0,
    this.failed = 0,
    this.total = 0,
  });

  factory CliComplianceEntry.fromJson(Map<String, dynamic> json) {
    return CliComplianceEntry(
      percentage: (json['percentage'] as num?)?.toDouble() ?? 100.0,
      passed: json['passed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'percentage': percentage,
        'passed': passed,
        'failed': failed,
        'total': total,
      };
}

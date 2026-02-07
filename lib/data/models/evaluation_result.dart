import 'policy_violation.dart';

/// Aggregated result from the OPA policy evaluation engine.
///
/// Maps to `output.PolicyOutput` in `internal/output/formatter.go`.
/// Contains lists of violations (blocking) and warnings (advisory),
/// plus pass/fail counts across all evaluated policies.
class EvaluationResult {
  /// Policy violations that indicate a blocking compliance failure.
  final List<PolicyViolation> violations;

  /// Policy warnings that are advisory and non-blocking.
  final List<PolicyViolation> warnings;

  /// Number of policies that passed evaluation.
  final int passed;

  /// Number of policies that failed evaluation.
  final int failed;

  const EvaluationResult({
    this.violations = const [],
    this.warnings = const [],
    this.passed = 0,
    this.failed = 0,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'violations': violations.map((v) => v.toJson()).toList(),
        'warnings': warnings.map((w) => w.toJson()).toList(),
        'passed': passed,
        'failed': failed,
      };
}

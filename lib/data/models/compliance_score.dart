/// Computed compliance posture derived from policy evaluation results.
///
/// Aggregates pass/fail counts into an overall percentage and per-category
/// breakdowns (Security, Tagging, Cost) for the compliance dashboard.
class ComplianceScore {
  /// Overall compliance percentage (0.0–100.0).
  final double overallPercentage;

  /// Per-category compliance scores keyed by category name.
  final Map<String, CategoryScore> categories;

  /// Total number of policies evaluated.
  final int totalPolicies;

  /// Number of policies that passed.
  final int passingPolicies;

  /// Number of policies that failed.
  final int failingPolicies;

  const ComplianceScore({
    this.overallPercentage = 100.0,
    this.categories = const {},
    this.totalPolicies = 0,
    this.passingPolicies = 0,
    this.failingPolicies = 0,
  });

  /// Returns a default 100% compliant score with no data.
  factory ComplianceScore.empty() => const ComplianceScore();
}

/// Compliance score for a specific policy category (e.g. Security, Tagging, Cost).
class CategoryScore {
  /// Category display name.
  final String name;

  /// Compliance percentage within this category (0.0–100.0).
  final double percentage;

  /// Number of passing policies in this category.
  final int passed;

  /// Number of failing policies in this category.
  final int failed;

  /// Policy IDs that are currently failing in this category.
  final List<String> failingPolicyIds;

  const CategoryScore({
    required this.name,
    this.percentage = 100.0,
    this.passed = 0,
    this.failed = 0,
    this.failingPolicyIds = const [],
  });
}

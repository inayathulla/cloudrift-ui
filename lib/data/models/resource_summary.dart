import 'drift_info.dart';
import 'policy_violation.dart';
import 'severity.dart';

/// Aggregated view of a single resource combining drift and policy data.
///
/// Computed by `resourceSummariesProvider` from the latest [ScanResult].
/// Used to render resource cards, the resource list, and the resource detail screen.
class ResourceSummary {
  /// Unique resource identifier (e.g. bucket name, instance ID).
  final String resourceId;

  /// Human-readable resource name.
  final String resourceName;

  /// Terraform resource type (e.g. `aws_s3_bucket`).
  final String resourceType;

  /// AWS service category (e.g. `S3`, `EC2`).
  final String service;

  /// Most severe finding across all drifts and violations for this resource.
  final Severity highestSeverity;

  /// Total number of attribute-level drifts (diffs + extra attributes).
  final int driftCount;

  /// Number of policy violations affecting this resource.
  final int violationCount;

  /// Detailed drift information, or `null` if no drift was detected.
  final DriftInfo? driftInfo;

  /// Policy violations specific to this resource.
  final List<PolicyViolation> violations;

  const ResourceSummary({
    required this.resourceId,
    required this.resourceName,
    required this.resourceType,
    required this.service,
    this.highestSeverity = Severity.info,
    this.driftCount = 0,
    this.violationCount = 0,
    this.driftInfo,
    this.violations = const [],
  });

  /// Whether this resource has any configuration drift.
  bool get hasDrift => driftCount > 0;

  /// Whether this resource has any policy violations.
  bool get hasViolations => violationCount > 0;

  /// Whether this resource is fully compliant (no drift, no violations).
  bool get isClean => !hasDrift && !hasViolations;
}

/// Drift detection result for a single AWS resource.
///
/// Maps to the Go struct `detector.DriftResult` in `internal/detector/interface.go`.
/// Represents the difference between a Terraform-planned resource and its live AWS state.
class DriftInfo {
  /// Unique identifier for the resource (e.g. bucket name, instance ID).
  final String resourceId;

  /// Terraform resource type (e.g. `aws_s3_bucket`, `aws_instance`).
  final String resourceType;

  /// Human-readable resource name from the Terraform plan.
  final String resourceName;

  /// Whether the resource exists in the Terraform plan but is missing in AWS.
  final bool missing;

  /// Attribute-level differences: key → `[expected, actual]`.
  ///
  /// Each entry represents a configuration attribute where the Terraform-planned
  /// value differs from the live AWS value. The list contains exactly two elements:
  /// `[0]` = expected (Terraform), `[1]` = actual (AWS).
  final Map<String, List<dynamic>> diffs;

  /// Attributes present in live AWS state but absent from the Terraform plan.
  final Map<String, dynamic> extraAttributes;

  /// Severity level of the drift (e.g. `critical`, `high`, `medium`, `low`).
  final String severity;

  const DriftInfo({
    required this.resourceId,
    required this.resourceType,
    required this.resourceName,
    this.missing = false,
    this.diffs = const {},
    this.extraAttributes = const {},
    this.severity = 'warning',
  });

  /// Whether any form of drift was detected for this resource.
  bool get hasDrift => missing || diffs.isNotEmpty || extraAttributes.isNotEmpty;

  factory DriftInfo.fromJson(Map<String, dynamic> json) {
    final rawDiffs = json['diffs'] as Map<String, dynamic>? ?? {};
    final diffs = rawDiffs.map((key, value) {
      if (value is List) {
        return MapEntry(key, value);
      }
      return MapEntry(key, [value, null]);
    });

    return DriftInfo(
      resourceId: json['resource_id'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      resourceName: json['resource_name'] as String? ?? '',
      missing: json['missing'] as bool? ?? false,
      diffs: diffs,
      extraAttributes: json['extra_attributes'] as Map<String, dynamic>? ?? {},
      severity: json['severity'] as String? ?? 'warning',
    );
  }

  Map<String, dynamic> toJson() => {
        'resource_id': resourceId,
        'resource_type': resourceType,
        'resource_name': resourceName,
        'missing': missing,
        'diffs': diffs,
        'extra_attributes': extraAttributes,
        'severity': severity,
      };
}

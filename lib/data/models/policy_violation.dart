/// A single OPA policy violation or warning from the Cloudrift policy engine.
///
/// Maps to `output.PolicyViolationOutput` in `internal/output/formatter.go`.
/// Each violation indicates that a specific resource failed a policy check.
class PolicyViolation {
  /// Unique policy identifier (e.g. `S3-001`, `TAG-002`, `COST-003`).
  final String policyId;

  /// Human-readable policy name (e.g. "S3 buckets must have encryption enabled").
  final String policyName;

  /// Detailed violation message describing what failed.
  final String message;

  /// Severity level: `critical`, `high`, `medium`, `low`, or `info`.
  final String severity;

  /// Terraform resource type that was evaluated (e.g. `aws_s3_bucket`).
  final String resourceType;

  /// Terraform resource address (e.g. `aws_s3_bucket.my_bucket`).
  final String resourceAddress;

  /// Suggested fix for the violation, if available.
  final String remediation;

  /// Policy category: `security`, `tagging`, or `cost`.
  final String category;

  /// Compliance frameworks this violation maps to (e.g. `["hipaa", "pci_dss"]`).
  final List<String> frameworks;

  const PolicyViolation({
    required this.policyId,
    required this.policyName,
    required this.message,
    required this.severity,
    required this.resourceType,
    required this.resourceAddress,
    this.remediation = '',
    this.category = '',
    this.frameworks = const [],
  });

  factory PolicyViolation.fromJson(Map<String, dynamic> json) {
    return PolicyViolation(
      policyId: json['policy_id'] as String? ?? '',
      policyName: json['policy_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      resourceType: json['resource_type'] as String? ?? '',
      resourceAddress: json['resource_address'] as String? ?? '',
      remediation: json['remediation'] as String? ?? '',
      category: json['category'] as String? ?? '',
      frameworks: (json['frameworks'] as List<dynamic>?)
              ?.map((f) => f as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'policy_id': policyId,
        'policy_name': policyName,
        'message': message,
        'severity': severity,
        'resource_type': resourceType,
        'resource_address': resourceAddress,
        'remediation': remediation,
        'category': category,
        'frameworks': frameworks,
      };
}

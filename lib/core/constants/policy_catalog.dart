import '../../data/models/severity.dart';

/// Broad classification for OPA policy rules.
enum PolicyCategory { security, tagging, cost }

/// Compliance frameworks that a policy may align with.
enum ComplianceFramework {
  hipaa,
  gdpr,
  iso27001,
  pciDss;

  String get label => switch (this) {
    ComplianceFramework.hipaa => 'HIPAA',
    ComplianceFramework.gdpr => 'GDPR',
    ComplianceFramework.iso27001 => 'ISO 27001',
    ComplianceFramework.pciDss => 'PCI DSS',
  };

  String get shortLabel => switch (this) {
    ComplianceFramework.hipaa => 'HIPAA',
    ComplianceFramework.gdpr => 'GDPR',
    ComplianceFramework.iso27001 => 'ISO',
    ComplianceFramework.pciDss => 'PCI',
  };
}

/// Static metadata for a single OPA policy rule.
///
/// Each definition maps a policy ID (e.g. `S3-001`) to its human-readable
/// name, category, default severity, description, remediation guidance,
/// and the AWS service it applies to.
class PolicyDefinition {
  /// Unique policy identifier (e.g. `S3-001`, `EC2-002`, `TAG-001`).
  final String id;

  /// Human-readable policy name.
  final String name;

  /// Category this policy belongs to (security, tagging, or cost).
  final PolicyCategory category;

  /// Default severity when this policy is violated.
  final Severity defaultSeverity;

  /// Detailed description of what this policy checks.
  final String description;

  /// Actionable guidance for fixing violations of this policy.
  final String remediation;

  /// AWS service this policy applies to (e.g. `S3`, `EC2`, `SG`, `All`).
  final String service;

  /// Compliance frameworks this policy helps satisfy.
  final List<ComplianceFramework> frameworks;

  const PolicyDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultSeverity,
    required this.description,
    required this.remediation,
    required this.service,
    this.frameworks = const [],
  });
}

/// Hardcoded catalog of all 21 built-in OPA policies shipped with Cloudrift.
///
/// Organized by AWS service: S3 (9 policies), EC2 (4), Security Groups (4),
/// Cost (2), and Tagging (4). Used by the Policies screen to render
/// pass/fail status alongside each rule's description and remediation.
class PolicyCatalog {
  PolicyCatalog._();

  /// All built-in policies keyed by their ID (e.g. `S3-001`).
  static const policies = <String, PolicyDefinition>{
    'S3-001': PolicyDefinition(
      id: 'S3-001', name: 'S3 Encryption Required', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have server-side encryption enabled.',
      remediation: 'Add server_side_encryption_configuration with sse_algorithm set to AES256 or aws:kms',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.pciDss, ComplianceFramework.iso27001, ComplianceFramework.gdpr],
    ),
    'S3-002': PolicyDefinition(
      id: 'S3-002', name: 'S3 KMS Encryption Recommended', category: PolicyCategory.security,
      defaultSeverity: Severity.low, service: 'S3',
      description: 'S3 buckets should use KMS encryption for better key management.',
      remediation: 'Change sse_algorithm to aws:kms and specify a KMS key',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.pciDss],
    ),
    'S3-003': PolicyDefinition(
      id: 'S3-003', name: 'S3 Block Public ACLs', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have block_public_acls enabled.',
      remediation: 'Set block_public_acls = true in aws_s3_bucket_public_access_block',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.gdpr, ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'S3-004': PolicyDefinition(
      id: 'S3-004', name: 'S3 Block Public Policy', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have block_public_policy enabled.',
      remediation: 'Set block_public_policy = true in aws_s3_bucket_public_access_block',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.gdpr, ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'S3-005': PolicyDefinition(
      id: 'S3-005', name: 'S3 Ignore Public ACLs', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have ignore_public_acls enabled.',
      remediation: 'Set ignore_public_acls = true in aws_s3_bucket_public_access_block',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.gdpr, ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'S3-006': PolicyDefinition(
      id: 'S3-006', name: 'S3 Restrict Public Buckets', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have restrict_public_buckets enabled.',
      remediation: 'Set restrict_public_buckets = true in aws_s3_bucket_public_access_block',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.gdpr, ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'S3-007': PolicyDefinition(
      id: 'S3-007', name: 'S3 No Public Read ACL', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'S3',
      description: 'S3 buckets must not have public-read ACL.',
      remediation: 'Change ACL to private or use bucket policies for controlled access',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.gdpr, ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'S3-008': PolicyDefinition(
      id: 'S3-008', name: 'S3 No Public Read-Write ACL', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'S3',
      description: 'S3 buckets must not have public-read-write ACL.',
      remediation: 'Immediately change ACL to private. Public write is a serious security risk',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.gdpr, ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'S3-009': PolicyDefinition(
      id: 'S3-009', name: 'S3 Versioning Recommended', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'S3',
      description: 'S3 buckets should have versioning enabled for data protection.',
      remediation: 'Enable versioning on the S3 bucket',
      frameworks: [ComplianceFramework.iso27001],
    ),
    'EC2-001': PolicyDefinition(
      id: 'EC2-001', name: 'EC2 IMDSv2 Required', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'EC2',
      description: 'EC2 instances should use IMDSv2 for instance metadata.',
      remediation: 'Set metadata_options.http_tokens = required',
      frameworks: [ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'EC2-002': PolicyDefinition(
      id: 'EC2-002', name: 'EC2 Root Volume Encryption', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'EC2',
      description: 'EC2 root volumes must be encrypted.',
      remediation: 'Set encrypted = true in root_block_device',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.pciDss, ComplianceFramework.iso27001, ComplianceFramework.gdpr],
    ),
    'EC2-003': PolicyDefinition(
      id: 'EC2-003', name: 'EC2 Public IP Warning', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'EC2',
      description: 'EC2 instances should not have public IPs unless necessary.',
      remediation: 'Remove associate_public_ip_address or use NAT gateway',
      frameworks: [ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'EC2-005': PolicyDefinition(
      id: 'EC2-005', name: 'EC2 Large Instance Review', category: PolicyCategory.cost,
      defaultSeverity: Severity.medium, service: 'EC2',
      description: 'Large EC2 instances should be reviewed for cost optimization.',
      remediation: 'Consider right-sizing or using reserved instances',
    ),
    'SG-001': PolicyDefinition(
      id: 'SG-001', name: 'No Unrestricted SSH', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'SG',
      description: 'Security groups must not allow SSH from 0.0.0.0/0.',
      remediation: 'Restrict SSH access to specific CIDR ranges',
      frameworks: [ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'SG-002': PolicyDefinition(
      id: 'SG-002', name: 'No Unrestricted RDP', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'SG',
      description: 'Security groups must not allow RDP from 0.0.0.0/0.',
      remediation: 'Restrict RDP access to specific CIDR ranges',
      frameworks: [ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'SG-003': PolicyDefinition(
      id: 'SG-003', name: 'No Unrestricted All Ports', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'SG',
      description: 'Security groups must not allow all ports from 0.0.0.0/0.',
      remediation: 'Restrict ingress to specific ports and CIDR ranges',
      frameworks: [ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'SG-004': PolicyDefinition(
      id: 'SG-004', name: 'Database Port Public Exposure', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'SG',
      description: 'Database ports should not be publicly exposed.',
      remediation: 'Restrict database port access to application subnets only',
      frameworks: [ComplianceFramework.hipaa, ComplianceFramework.pciDss, ComplianceFramework.iso27001],
    ),
    'COST-002': PolicyDefinition(
      id: 'COST-002', name: 'Very Large Instance Size', category: PolicyCategory.cost,
      defaultSeverity: Severity.medium, service: 'EC2',
      description: 'Very large instances should be reviewed for cost optimization.',
      remediation: 'Consider right-sizing based on actual utilization',
    ),
    'COST-003': PolicyDefinition(
      id: 'COST-003', name: 'Previous Generation Instance', category: PolicyCategory.cost,
      defaultSeverity: Severity.low, service: 'EC2',
      description: 'Using previous generation instance type.',
      remediation: 'Migrate to current generation for better price/performance',
    ),
    'TAG-001': PolicyDefinition(
      id: 'TAG-001', name: 'Environment Tag Required', category: PolicyCategory.tagging,
      defaultSeverity: Severity.medium, service: 'All',
      description: 'Resources must have an Environment tag.',
      remediation: 'Add tags = { Environment = "dev|staging|production" }',
    ),
    'TAG-002': PolicyDefinition(
      id: 'TAG-002', name: 'Owner Tag Recommended', category: PolicyCategory.tagging,
      defaultSeverity: Severity.low, service: 'All',
      description: 'Resources should have an Owner tag for accountability.',
      remediation: 'Add Owner tag with responsible team or individual',
    ),
    'TAG-003': PolicyDefinition(
      id: 'TAG-003', name: 'Project Tag Recommended', category: PolicyCategory.tagging,
      defaultSeverity: Severity.low, service: 'All',
      description: 'Resources should have a Project tag for cost allocation.',
      remediation: 'Add Project tag to enable cost tracking',
    ),
    'TAG-004': PolicyDefinition(
      id: 'TAG-004', name: 'Name Tag Recommended', category: PolicyCategory.tagging,
      defaultSeverity: Severity.low, service: 'All',
      description: 'Resources should have a Name tag for identification.',
      remediation: 'Add Name tag for easy identification in AWS console',
    ),
  };

  /// Returns all policies belonging to the given [category].
  static List<PolicyDefinition> byCategory(PolicyCategory category) {
    return policies.values.where((p) => p.category == category).toList();
  }
}

import '../../data/models/severity.dart';

/// Broad classification for OPA policy rules.
enum PolicyCategory { security, tagging, cost }

/// Compliance frameworks that a policy may align with.
enum ComplianceFramework {
  hipaa,
  gdpr,
  iso27001,
  pciDss,
  soc2;

  String get label => switch (this) {
    ComplianceFramework.hipaa => 'HIPAA',
    ComplianceFramework.gdpr => 'GDPR',
    ComplianceFramework.iso27001 => 'ISO 27001',
    ComplianceFramework.pciDss => 'PCI DSS',
    ComplianceFramework.soc2 => 'SOC 2',
  };

  String get shortLabel => switch (this) {
    ComplianceFramework.hipaa => 'HIPAA',
    ComplianceFramework.gdpr => 'GDPR',
    ComplianceFramework.iso27001 => 'ISO',
    ComplianceFramework.pciDss => 'PCI',
    ComplianceFramework.soc2 => 'SOC2',
  };

  /// Parses from the CLI's JSON framework key (e.g. `soc2`, `pci_dss`).
  static ComplianceFramework? fromKey(String key) => switch (key) {
    'hipaa' => ComplianceFramework.hipaa,
    'gdpr' => ComplianceFramework.gdpr,
    'iso_27001' => ComplianceFramework.iso27001,
    'pci_dss' => ComplianceFramework.pciDss,
    'soc2' => ComplianceFramework.soc2,
    _ => null,
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

/// Catalog of all 49 built-in OPA policies shipped with the Cloudrift CLI.
///
/// Organized by AWS service: S3 (9), EC2 (3), Security Groups (4), RDS (5),
/// IAM (3), CloudTrail (3), KMS (2), EBS (2), Lambda (2), ELB (3),
/// CloudWatch (2), VPC (2), Secrets Manager (2), Cost (3), Tagging (4).
///
/// Used by the Policies screen to render pass/fail status alongside each
/// rule's description and remediation. Framework mappings match the CLI's
/// `internal/policy/registry.go`.
class PolicyCatalog {
  PolicyCatalog._();

  static const _h = ComplianceFramework.hipaa;
  static const _g = ComplianceFramework.gdpr;
  static const _i = ComplianceFramework.iso27001;
  static const _p = ComplianceFramework.pciDss;
  static const _s = ComplianceFramework.soc2;

  /// All built-in policies keyed by their ID (e.g. `S3-001`).
  static const policies = <String, PolicyDefinition>{
    // ── S3 Storage (9) ───────────────────────────────────────────────────
    'S3-001': PolicyDefinition(
      id: 'S3-001', name: 'S3 Encryption Required', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have server-side encryption enabled.',
      remediation: 'Add server_side_encryption_configuration with sse_algorithm set to AES256 or aws:kms',
      frameworks: [_h, _p, _i, _g, _s],
    ),
    'S3-002': PolicyDefinition(
      id: 'S3-002', name: 'S3 KMS Encryption Recommended', category: PolicyCategory.security,
      defaultSeverity: Severity.low, service: 'S3',
      description: 'S3 buckets should use KMS encryption for better key management.',
      remediation: 'Change sse_algorithm to aws:kms and specify a KMS key',
      frameworks: [_h, _p, _s],
    ),
    'S3-003': PolicyDefinition(
      id: 'S3-003', name: 'S3 Block Public ACLs', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have block_public_acls enabled.',
      remediation: 'Set block_public_acls = true in aws_s3_bucket_public_access_block',
      frameworks: [_h, _g, _p, _i, _s],
    ),
    'S3-004': PolicyDefinition(
      id: 'S3-004', name: 'S3 Block Public Policy', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have block_public_policy enabled.',
      remediation: 'Set block_public_policy = true in aws_s3_bucket_public_access_block',
      frameworks: [_h, _g, _p, _i, _s],
    ),
    'S3-005': PolicyDefinition(
      id: 'S3-005', name: 'S3 Ignore Public ACLs', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have ignore_public_acls enabled.',
      remediation: 'Set ignore_public_acls = true in aws_s3_bucket_public_access_block',
      frameworks: [_h, _g, _p, _i, _s],
    ),
    'S3-006': PolicyDefinition(
      id: 'S3-006', name: 'S3 Restrict Public Buckets', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'S3',
      description: 'S3 buckets must have restrict_public_buckets enabled.',
      remediation: 'Set restrict_public_buckets = true in aws_s3_bucket_public_access_block',
      frameworks: [_h, _g, _p, _i, _s],
    ),
    'S3-007': PolicyDefinition(
      id: 'S3-007', name: 'S3 No Public Read ACL', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'S3',
      description: 'S3 buckets must not have public-read ACL.',
      remediation: 'Change ACL to private or use bucket policies for controlled access',
      frameworks: [_h, _g, _p, _i, _s],
    ),
    'S3-008': PolicyDefinition(
      id: 'S3-008', name: 'S3 No Public Read-Write ACL', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'S3',
      description: 'S3 buckets must not have public-read-write ACL.',
      remediation: 'Immediately change ACL to private. Public write is a serious security risk',
      frameworks: [_h, _g, _p, _i, _s],
    ),
    'S3-009': PolicyDefinition(
      id: 'S3-009', name: 'S3 Versioning Recommended', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'S3',
      description: 'S3 buckets should have versioning enabled for data protection.',
      remediation: 'Enable versioning on the S3 bucket',
      frameworks: [_i, _s],
    ),
    // ── EC2 Compute (3) ──────────────────────────────────────────────────
    'EC2-001': PolicyDefinition(
      id: 'EC2-001', name: 'EC2 IMDSv2 Required', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'EC2',
      description: 'EC2 instances should use IMDSv2 for instance metadata.',
      remediation: 'Set metadata_options.http_tokens = required',
      frameworks: [_p, _i, _s],
    ),
    'EC2-002': PolicyDefinition(
      id: 'EC2-002', name: 'EC2 Root Volume Encryption', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'EC2',
      description: 'EC2 root volumes must be encrypted.',
      remediation: 'Set encrypted = true in root_block_device',
      frameworks: [_h, _p, _i, _g, _s],
    ),
    'EC2-003': PolicyDefinition(
      id: 'EC2-003', name: 'EC2 Public IP Warning', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'EC2',
      description: 'EC2 instances should not have public IPs unless necessary.',
      remediation: 'Remove associate_public_ip_address or use NAT gateway',
      frameworks: [_p, _i, _s],
    ),
    // ── Security Groups (4) ──────────────────────────────────────────────
    'SG-001': PolicyDefinition(
      id: 'SG-001', name: 'No Unrestricted SSH', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'SG',
      description: 'Security groups must not allow SSH from 0.0.0.0/0.',
      remediation: 'Restrict SSH access to specific CIDR ranges',
      frameworks: [_p, _i, _s],
    ),
    'SG-002': PolicyDefinition(
      id: 'SG-002', name: 'No Unrestricted RDP', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'SG',
      description: 'Security groups must not allow RDP from 0.0.0.0/0.',
      remediation: 'Restrict RDP access to specific CIDR ranges',
      frameworks: [_p, _i, _s],
    ),
    'SG-003': PolicyDefinition(
      id: 'SG-003', name: 'No Unrestricted All Ports', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'SG',
      description: 'Security groups must not allow all ports from 0.0.0.0/0.',
      remediation: 'Restrict ingress to specific ports and CIDR ranges',
      frameworks: [_p, _i, _s],
    ),
    'SG-004': PolicyDefinition(
      id: 'SG-004', name: 'Database Ports Not Public', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'SG',
      description: 'Database ports should not be publicly exposed.',
      remediation: 'Restrict database port access to application subnets only',
      frameworks: [_h, _p, _i, _s],
    ),
    // ── RDS Databases (5) ────────────────────────────────────────────────
    'RDS-001': PolicyDefinition(
      id: 'RDS-001', name: 'RDS Storage Encryption Required', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'RDS',
      description: 'RDS instances must have storage encryption enabled.',
      remediation: 'Set storage_encrypted = true on the aws_db_instance',
      frameworks: [_h, _p, _i, _g, _s],
    ),
    'RDS-002': PolicyDefinition(
      id: 'RDS-002', name: 'RDS No Public Access', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'RDS',
      description: 'RDS instances must not be publicly accessible.',
      remediation: 'Set publicly_accessible = false',
      frameworks: [_h, _p, _i, _g, _s],
    ),
    'RDS-003': PolicyDefinition(
      id: 'RDS-003', name: 'RDS Backup Retention Period', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'RDS',
      description: 'RDS backup retention should be at least 7 days.',
      remediation: 'Set backup_retention_period >= 7',
      frameworks: [_h, _i, _s],
    ),
    'RDS-004': PolicyDefinition(
      id: 'RDS-004', name: 'RDS Deletion Protection', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'RDS',
      description: 'RDS instances should have deletion protection enabled.',
      remediation: 'Set deletion_protection = true',
      frameworks: [_i, _s],
    ),
    'RDS-005': PolicyDefinition(
      id: 'RDS-005', name: 'RDS Multi-AZ Recommended', category: PolicyCategory.security,
      defaultSeverity: Severity.low, service: 'RDS',
      description: 'RDS instances should use Multi-AZ for high availability.',
      remediation: 'Set multi_az = true for production workloads',
      frameworks: [_h, _i, _s],
    ),
    // ── IAM (3) ──────────────────────────────────────────────────────────
    'IAM-001': PolicyDefinition(
      id: 'IAM-001', name: 'No Wildcard IAM Actions', category: PolicyCategory.security,
      defaultSeverity: Severity.critical, service: 'IAM',
      description: 'IAM policies must not use wildcard (*) actions.',
      remediation: 'Replace * with specific actions following least-privilege principle',
      frameworks: [_h, _p, _i, _g, _s],
    ),
    'IAM-002': PolicyDefinition(
      id: 'IAM-002', name: 'No Inline Policies on Users', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'IAM',
      description: 'IAM users should not have inline policies attached.',
      remediation: 'Use managed policies attached to groups or roles instead',
      frameworks: [_p, _i, _s],
    ),
    'IAM-003': PolicyDefinition(
      id: 'IAM-003', name: 'IAM Role Trust Not Too Broad', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'IAM',
      description: 'IAM role trust policies should not allow overly broad principals.',
      remediation: 'Restrict assume_role_policy to specific accounts and services',
      frameworks: [_p, _i, _s],
    ),
    // ── CloudTrail (3) ───────────────────────────────────────────────────
    'CT-001': PolicyDefinition(
      id: 'CT-001', name: 'CloudTrail KMS Encryption', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'CloudTrail',
      description: 'CloudTrail logs must be encrypted with KMS.',
      remediation: 'Set kms_key_id on the aws_cloudtrail resource',
      frameworks: [_h, _p, _i, _g, _s],
    ),
    'CT-002': PolicyDefinition(
      id: 'CT-002', name: 'CloudTrail Log File Validation', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'CloudTrail',
      description: 'CloudTrail should have log file validation enabled.',
      remediation: 'Set enable_log_file_validation = true',
      frameworks: [_p, _i, _s],
    ),
    'CT-003': PolicyDefinition(
      id: 'CT-003', name: 'CloudTrail Multi-Region', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'CloudTrail',
      description: 'CloudTrail should be enabled across all regions.',
      remediation: 'Set is_multi_region_trail = true',
      frameworks: [_h, _p, _i, _s],
    ),
    // ── KMS (2) ──────────────────────────────────────────────────────────
    'KMS-001': PolicyDefinition(
      id: 'KMS-001', name: 'KMS Key Rotation Enabled', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'KMS',
      description: 'KMS keys must have automatic key rotation enabled.',
      remediation: 'Set enable_key_rotation = true on aws_kms_key',
      frameworks: [_h, _p, _i, _s],
    ),
    'KMS-002': PolicyDefinition(
      id: 'KMS-002', name: 'KMS Deletion Window Minimum', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'KMS',
      description: 'KMS key deletion window should be at least 14 days.',
      remediation: 'Set deletion_window_in_days >= 14',
      frameworks: [_i, _s],
    ),
    // ── EBS (2) ──────────────────────────────────────────────────────────
    'EBS-001': PolicyDefinition(
      id: 'EBS-001', name: 'EBS Volume Encryption', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'EBS',
      description: 'EBS volumes must be encrypted.',
      remediation: 'Set encrypted = true on aws_ebs_volume',
      frameworks: [_h, _p, _i, _g, _s],
    ),
    'EBS-002': PolicyDefinition(
      id: 'EBS-002', name: 'EBS Snapshot Encryption', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'EBS',
      description: 'EBS snapshot copies must be encrypted.',
      remediation: 'Set encrypted = true on aws_ebs_snapshot_copy',
      frameworks: [_h, _p, _i, _g],
    ),
    // ── Lambda (2) ───────────────────────────────────────────────────────
    'LAMBDA-001': PolicyDefinition(
      id: 'LAMBDA-001', name: 'Lambda X-Ray Tracing', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'Lambda',
      description: 'Lambda functions should have X-Ray tracing enabled.',
      remediation: 'Set tracing_config { mode = "Active" }',
      frameworks: [_s, _i],
    ),
    'LAMBDA-002': PolicyDefinition(
      id: 'LAMBDA-002', name: 'Lambda VPC Configuration', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'Lambda',
      description: 'Lambda functions should run inside a VPC for network isolation.',
      remediation: 'Add vpc_config with subnet_ids and security_group_ids',
      frameworks: [_h, _p, _i],
    ),
    // ── ELB / ALB (3) ───────────────────────────────────────────────────
    'ELB-001': PolicyDefinition(
      id: 'ELB-001', name: 'ALB Access Logging', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'ELB',
      description: 'Application Load Balancers should have access logging enabled.',
      remediation: 'Set access_logs { enabled = true, bucket = "..." }',
      frameworks: [_h, _p, _i, _s],
    ),
    'ELB-002': PolicyDefinition(
      id: 'ELB-002', name: 'ALB HTTPS Listener Required', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'ELB',
      description: 'ALB listeners should use HTTPS protocol.',
      remediation: 'Set protocol = "HTTPS" and configure ssl_policy + certificate_arn',
      frameworks: [_h, _p, _i, _g, _s],
    ),
    'ELB-003': PolicyDefinition(
      id: 'ELB-003', name: 'ALB Deletion Protection', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'ELB',
      description: 'Application Load Balancers should have deletion protection enabled.',
      remediation: 'Set enable_deletion_protection = true',
      frameworks: [_i, _s],
    ),
    // ── CloudWatch Logging (2) ───────────────────────────────────────────
    'LOG-001': PolicyDefinition(
      id: 'LOG-001', name: 'CloudWatch Log Group KMS Encryption', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'CloudWatch',
      description: 'CloudWatch log groups should be encrypted with KMS.',
      remediation: 'Set kms_key_id on aws_cloudwatch_log_group',
      frameworks: [_h, _p, _g, _s],
    ),
    'LOG-002': PolicyDefinition(
      id: 'LOG-002', name: 'CloudWatch Log Retention', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'CloudWatch',
      description: 'CloudWatch log groups should have a retention period set.',
      remediation: 'Set retention_in_days (e.g. 90, 365)',
      frameworks: [_h, _g, _s, _i],
    ),
    // ── VPC / Networking (2) ─────────────────────────────────────────────
    'VPC-001': PolicyDefinition(
      id: 'VPC-001', name: 'Default Security Group Restrict All', category: PolicyCategory.security,
      defaultSeverity: Severity.high, service: 'VPC',
      description: 'Default security groups should restrict all inbound and outbound traffic.',
      remediation: 'Remove all ingress and egress rules from the default security group',
      frameworks: [_p, _i, _s],
    ),
    'VPC-002': PolicyDefinition(
      id: 'VPC-002', name: 'Subnet No Auto-Assign Public IP', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'VPC',
      description: 'Subnets should not auto-assign public IP addresses.',
      remediation: 'Set map_public_ip_on_launch = false',
      frameworks: [_p, _i],
    ),
    // ── Secrets Manager (2) ──────────────────────────────────────────────
    'SECRET-001': PolicyDefinition(
      id: 'SECRET-001', name: 'Secrets Manager KMS Encryption', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'Secrets',
      description: 'Secrets Manager secrets should use a customer-managed KMS key.',
      remediation: 'Set kms_key_id on aws_secretsmanager_secret',
      frameworks: [_h, _p, _g, _s],
    ),
    'SECRET-002': PolicyDefinition(
      id: 'SECRET-002', name: 'Secrets Automatic Rotation', category: PolicyCategory.security,
      defaultSeverity: Severity.medium, service: 'Secrets',
      description: 'Secrets Manager secrets should have automatic rotation configured.',
      remediation: 'Configure rotation_rules with automatic_after_days',
      frameworks: [_p, _i, _s],
    ),
    // ── Cost (3) ─────────────────────────────────────────────────────────
    'EC2-005': PolicyDefinition(
      id: 'EC2-005', name: 'EC2 Large Instance Review', category: PolicyCategory.cost,
      defaultSeverity: Severity.medium, service: 'EC2',
      description: 'Large EC2 instances should be reviewed for cost optimization.',
      remediation: 'Consider right-sizing or using reserved instances',
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
    // ── Tagging (4) ─────────────────────────────────────────────────────
    'TAG-001': PolicyDefinition(
      id: 'TAG-001', name: 'Environment Tag Required', category: PolicyCategory.tagging,
      defaultSeverity: Severity.medium, service: 'All',
      description: 'Resources must have an Environment tag.',
      remediation: 'Add tags = { Environment = "dev|staging|production" }',
      frameworks: [_s],
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

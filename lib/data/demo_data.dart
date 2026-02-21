import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'datasources/local_storage_datasource.dart';
import 'models/scan_result.dart';
import 'models/drift_info.dart';
import 'models/evaluation_result.dart';
import 'models/policy_violation.dart';
import 'models/scan_history_entry.dart';

const _uuid = Uuid();

/// Seeds realistic demo scan data into storage for the web version.
///
/// Only seeds if no history exists yet. Creates 10 scan history entries
/// spanning the last 2 weeks so all screens (Dashboard, Scan History,
/// Resources, Policies, Compliance) render with meaningful data.
Future<void> seedDemoData(LocalStorageDatasource storage) async {
  final existing = storage.getAllHistory();
  if (existing.isNotEmpty) return;

  final now = DateTime.now();

  // Latest scan — full rawJson for Dashboard/Resources/Policies/Compliance
  final latestResult = _buildLatestScanResult(now);
  final latestJson = jsonEncode(latestResult.toJson());

  // Second most recent — also with rawJson so users can browse history
  final secondResult = _buildSecondScanResult(now);
  final secondJson = jsonEncode(secondResult.toJson());

  // Third most recent — IAM scan with rawJson
  final thirdResult = _buildIAMScanResult(now);
  final thirdJson = jsonEncode(thirdResult.toJson());

  final entries = <ScanHistoryEntry>[
    // Entry 0: latest (1h ago) — S3 scan
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 1)),
      service: 'S3',
      region: 'us-east-1',
      accountId: '123456789012',
      totalResources: 8,
      driftCount: 5,
      policyViolations: 6,
      policyWarnings: 3,
      scanDurationMs: 3245,
      rawJson: latestJson,
      status: 'completed',
    ),
    // Entry 1: 6h ago — EC2 scan
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 6)),
      service: 'EC2',
      region: 'us-east-1',
      accountId: '123456789012',
      totalResources: 12,
      driftCount: 3,
      policyViolations: 4,
      policyWarnings: 2,
      scanDurationMs: 4521,
      rawJson: secondJson,
      status: 'completed',
    ),
    // Entry 2: 12h ago — IAM scan
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 12)),
      service: 'IAM',
      region: 'us-east-1',
      accountId: '123456789012',
      totalResources: 6,
      driftCount: 3,
      policyViolations: 2,
      policyWarnings: 1,
      scanDurationMs: 2870,
      rawJson: thirdJson,
      status: 'completed',
    ),
    // Entries 3-10: historical (summary only, for trend chart + history table)
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 24)),
      service: 'S3', region: 'us-east-1', accountId: '123456789012',
      totalResources: 8, driftCount: 6, policyViolations: 7, policyWarnings: 4,
      scanDurationMs: 3102, rawJson: '', status: 'completed',
    ),
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 48)),
      service: 'EC2', region: 'us-east-1', accountId: '123456789012',
      totalResources: 11, driftCount: 4, policyViolations: 3, policyWarnings: 2,
      scanDurationMs: 4890, rawJson: '', status: 'completed',
    ),
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 72)),
      service: 'S3', region: 'us-east-1', accountId: '123456789012',
      totalResources: 8, driftCount: 7, policyViolations: 8, policyWarnings: 3,
      scanDurationMs: 2987, rawJson: '', status: 'completed',
    ),
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 120)),
      service: 'EC2', region: 'us-east-1', accountId: '123456789012',
      totalResources: 10, driftCount: 5, policyViolations: 4, policyWarnings: 2,
      scanDurationMs: 5123, rawJson: '', status: 'completed',
    ),
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 168)),
      service: 'S3', region: 'us-east-1', accountId: '123456789012',
      totalResources: 7, driftCount: 4, policyViolations: 5, policyWarnings: 2,
      scanDurationMs: 2845, rawJson: '', status: 'completed',
    ),
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 216)),
      service: 'EC2', region: 'us-east-1', accountId: '123456789012',
      totalResources: 10, driftCount: 6, policyViolations: 5, policyWarnings: 3,
      scanDurationMs: 4678, rawJson: '', status: 'completed',
    ),
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 264)),
      service: 'S3', region: 'us-east-1', accountId: '123456789012',
      totalResources: 7, driftCount: 3, policyViolations: 3, policyWarnings: 1,
      scanDurationMs: 3201, rawJson: '', status: 'completed',
    ),
    ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: now.subtract(const Duration(hours: 336)),
      service: 'EC2', region: 'us-east-1', accountId: '123456789012',
      totalResources: 9, driftCount: 8, policyViolations: 6, policyWarnings: 4,
      scanDurationMs: 5432, rawJson: '', status: 'completed',
    ),
  ];

  for (final entry in entries) {
    await storage.saveScanEntry(entry);
  }
}

/// Builds the latest S3 scan result with 8 resources, 5 drifted,
/// 6 violations, and 3 warnings across Security/Tagging/Cost categories.
ScanResult _buildLatestScanResult(DateTime now) {
  return ScanResult(
    service: 'S3',
    accountId: '123456789012',
    region: 'us-east-1',
    totalResources: 8,
    driftCount: 5,
    drifts: [
      // 1. HIGH — encryption changed, versioning disabled
      DriftInfo(
        resourceId: 'my-app-data-bucket',
        resourceType: 'aws_s3_bucket',
        resourceName: 'aws_s3_bucket.app_data',
        diffs: {
          'versioning.enabled': ['true', 'false'],
          'server_side_encryption_configuration.rule.sse_algorithm': ['aws:kms', 'AES256'],
        },
        severity: 'high',
      ),
      // 2. CRITICAL — public access blocks disabled
      DriftInfo(
        resourceId: 'my-logs-bucket',
        resourceType: 'aws_s3_bucket',
        resourceName: 'aws_s3_bucket.logs',
        diffs: {
          'block_public_acls': ['true', 'false'],
          'block_public_policy': ['true', 'false'],
          'restrict_public_buckets': ['true', 'false'],
        },
        severity: 'critical',
      ),
      // 3. MEDIUM — lifecycle rules removed
      DriftInfo(
        resourceId: 'my-static-assets',
        resourceType: 'aws_s3_bucket',
        resourceName: 'aws_s3_bucket.static_assets',
        diffs: {
          'lifecycle_rule.enabled': ['true', 'false'],
          'lifecycle_rule.transition.days': ['90', 'null'],
        },
        severity: 'medium',
      ),
      // 4. CRITICAL — bucket missing from AWS
      DriftInfo(
        resourceId: 'my-backup-bucket',
        resourceType: 'aws_s3_bucket',
        resourceName: 'aws_s3_bucket.backups',
        missing: true,
        severity: 'critical',
      ),
      // 5. MEDIUM — tags changed, CORS modified
      DriftInfo(
        resourceId: 'my-config-bucket',
        resourceType: 'aws_s3_bucket',
        resourceName: 'aws_s3_bucket.config',
        diffs: {
          'tags.Environment': ['production', 'dev'],
          'cors_rule.allowed_origins': ['["https://app.example.com"]', '["*"]'],
        },
        extraAttributes: {
          'tags.CostCenter': 'CC-4521',
        },
        severity: 'medium',
      ),
      // 6-8: Clean resources (no drift — included via totalResources count)
      DriftInfo(
        resourceId: 'my-terraform-state',
        resourceType: 'aws_s3_bucket',
        resourceName: 'aws_s3_bucket.terraform_state',
        severity: 'info',
      ),
      DriftInfo(
        resourceId: 'my-cdn-origin',
        resourceType: 'aws_s3_bucket',
        resourceName: 'aws_s3_bucket.cdn_origin',
        severity: 'info',
      ),
      DriftInfo(
        resourceId: 'my-analytics-data',
        resourceType: 'aws_s3_bucket',
        resourceName: 'aws_s3_bucket.analytics',
        diffs: {
          'tags.Owner': ['platform-team', 'null'],
        },
        severity: 'low',
      ),
    ],
    policyResult: EvaluationResult(
      violations: [
        PolicyViolation(
          policyId: 'S3-001',
          policyName: 'S3 Encryption Required',
          message: 'Bucket encryption changed from aws:kms to AES256',
          severity: 'high',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.app_data',
          remediation: 'Re-enable aws:kms encryption with the designated KMS key',
          category: 'security',
          frameworks: ['hipaa', 'pci_dss', 'iso_27001', 'gdpr', 'soc2'],
        ),
        PolicyViolation(
          policyId: 'S3-003',
          policyName: 'S3 Block Public ACLs',
          message: 'Public ACL blocking has been disabled',
          severity: 'critical',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.logs',
          remediation: 'Set block_public_acls = true in aws_s3_bucket_public_access_block',
          category: 'security',
          frameworks: ['hipaa', 'gdpr', 'pci_dss', 'iso_27001', 'soc2'],
        ),
        PolicyViolation(
          policyId: 'S3-006',
          policyName: 'S3 Restrict Public Buckets',
          message: 'Public bucket restriction has been disabled',
          severity: 'critical',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.logs',
          remediation: 'Set restrict_public_buckets = true in aws_s3_bucket_public_access_block',
          category: 'security',
          frameworks: ['hipaa', 'gdpr', 'pci_dss', 'iso_27001', 'soc2'],
        ),
        PolicyViolation(
          policyId: 'TAG-001',
          policyName: 'Environment Tag Required',
          message: 'Environment tag changed from production to dev',
          severity: 'medium',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.config',
          remediation: 'Restore the Environment tag to the correct value',
          category: 'tagging',
          frameworks: ['soc2'],
        ),
        PolicyViolation(
          policyId: 'TAG-003',
          policyName: 'Project Tag Recommended',
          message: 'Missing Project tag for cost allocation',
          severity: 'low',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.analytics',
          remediation: 'Add Project tag to enable cost tracking',
          category: 'tagging',
        ),
        PolicyViolation(
          policyId: 'COST-003',
          policyName: 'Previous Generation Instance',
          message: 'Lifecycle transition rules have been disabled',
          severity: 'medium',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.static_assets',
          remediation: 'Re-enable lifecycle rules to transition objects to cheaper storage classes',
          category: 'cost',
        ),
      ],
      warnings: [
        PolicyViolation(
          policyId: 'S3-002',
          policyName: 'S3 KMS Encryption Recommended',
          message: 'Using AES256 instead of KMS encryption',
          severity: 'low',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.cdn_origin',
          remediation: 'Consider upgrading to aws:kms encryption',
          category: 'security',
          frameworks: ['hipaa', 'pci_dss', 'soc2'],
        ),
        PolicyViolation(
          policyId: 'TAG-002',
          policyName: 'Owner Tag Recommended',
          message: 'Missing Owner tag',
          severity: 'low',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.backups',
          remediation: 'Add Owner tag with responsible team',
          category: 'tagging',
        ),
        PolicyViolation(
          policyId: 'S3-009',
          policyName: 'S3 Versioning Recommended',
          message: 'Bucket versioning is not enabled',
          severity: 'medium',
          resourceType: 'aws_s3_bucket',
          resourceAddress: 'aws_s3_bucket.static_assets',
          remediation: 'Enable versioning on the S3 bucket',
          category: 'security',
          frameworks: ['iso_27001', 'soc2'],
        ),
      ],
      passed: 43,
      failed: 6,
    ),
    scanDurationMs: 3245,
    timestamp: now.subtract(const Duration(hours: 1)).toIso8601String(),
  );
}

/// Builds an IAM scan result with 6 resources, 3 drifted,
/// 2 violations, and 1 warning for IAM-specific policies.
ScanResult _buildIAMScanResult(DateTime now) {
  return ScanResult(
    service: 'IAM',
    accountId: '123456789012',
    region: 'us-east-1',
    totalResources: 6,
    driftCount: 3,
    drifts: [
      // 1. CRITICAL — trust policy broadened
      DriftInfo(
        resourceId: 'lambda-exec-role',
        resourceType: 'aws_iam_role',
        resourceName: 'aws_iam_role.lambda_exec',
        diffs: {
          'assume_role_policy': ['lambda.amazonaws.com only', '* (any principal)'],
        },
        severity: 'critical',
      ),
      // 2. HIGH — policy document has wildcard action
      DriftInfo(
        resourceId: 'admin-policy',
        resourceType: 'aws_iam_policy',
        resourceName: 'aws_iam_policy.admin_policy',
        diffs: {
          'policy_document': ['s3:GetObject,s3:PutObject', '*'],
        },
        severity: 'high',
      ),
      // 3. MEDIUM — user tags changed
      DriftInfo(
        resourceId: 'deploy-user',
        resourceType: 'aws_iam_user',
        resourceName: 'aws_iam_user.deploy',
        diffs: {
          'tags.Environment': ['production', 'dev'],
        },
        extraAttributes: {
          'tags.CreatedBy': 'manual-console',
        },
        severity: 'medium',
      ),
      // 4-6: Clean resources
      DriftInfo(
        resourceId: 'ecs-task-role',
        resourceType: 'aws_iam_role',
        resourceName: 'aws_iam_role.ecs_task',
        severity: 'info',
      ),
      DriftInfo(
        resourceId: 'readonly-user',
        resourceType: 'aws_iam_user',
        resourceName: 'aws_iam_user.readonly',
        severity: 'info',
      ),
      DriftInfo(
        resourceId: 'developers',
        resourceType: 'aws_iam_group',
        resourceName: 'aws_iam_group.developers',
        severity: 'info',
      ),
    ],
    policyResult: EvaluationResult(
      violations: [
        PolicyViolation(
          policyId: 'IAM-001',
          policyName: 'No Wildcard IAM Actions',
          message: 'IAM policy admin-policy contains a wildcard (*) action',
          severity: 'critical',
          resourceType: 'aws_iam_policy',
          resourceAddress: 'aws_iam_policy.admin_policy',
          remediation: 'Replace wildcard Action with specific actions following least-privilege principle',
          category: 'security',
          frameworks: ['hipaa', 'pci_dss', 'iso_27001', 'gdpr', 'soc2'],
        ),
        PolicyViolation(
          policyId: 'IAM-003',
          policyName: 'IAM Role Trust Too Broad',
          message: 'IAM role lambda-exec-role has overly broad trust policy',
          severity: 'high',
          resourceType: 'aws_iam_role',
          resourceAddress: 'aws_iam_role.lambda_exec',
          remediation: 'Restrict Principal to specific AWS accounts, services, or IAM entities',
          category: 'security',
          frameworks: ['pci_dss', 'iso_27001', 'soc2'],
        ),
      ],
      warnings: [
        PolicyViolation(
          policyId: 'TAG-001',
          policyName: 'Environment Tag Required',
          message: 'Environment tag changed from production to dev',
          severity: 'medium',
          resourceType: 'aws_iam_user',
          resourceAddress: 'aws_iam_user.deploy',
          remediation: 'Restore Environment tag to correct value',
          category: 'tagging',
          frameworks: ['soc2'],
        ),
      ],
      passed: 47,
      failed: 2,
    ),
    scanDurationMs: 2870,
    timestamp: now.subtract(const Duration(hours: 12)).toIso8601String(),
  );
}

/// Builds a second scan (EC2) with drift data for browsable history.
ScanResult _buildSecondScanResult(DateTime now) {
  return ScanResult(
    service: 'EC2',
    accountId: '123456789012',
    region: 'us-east-1',
    totalResources: 12,
    driftCount: 3,
    drifts: [
      DriftInfo(
        resourceId: 'i-0a1b2c3d4e5f67890',
        resourceType: 'aws_instance',
        resourceName: 'aws_instance.web_server',
        diffs: {
          'instance_type': ['t3.medium', 't3.xlarge'],
          'metadata_options.http_tokens': ['required', 'optional'],
        },
        severity: 'high',
      ),
      DriftInfo(
        resourceId: 'i-0f9e8d7c6b5a43210',
        resourceType: 'aws_instance',
        resourceName: 'aws_instance.api_server',
        diffs: {
          'root_block_device.encrypted': ['true', 'false'],
        },
        severity: 'critical',
      ),
      DriftInfo(
        resourceId: 'i-0123456789abcdef0',
        resourceType: 'aws_instance',
        resourceName: 'aws_instance.worker',
        diffs: {
          'tags.Environment': ['production', 'staging'],
          'associate_public_ip_address': ['false', 'true'],
        },
        severity: 'medium',
      ),
    ],
    policyResult: EvaluationResult(
      violations: [
        PolicyViolation(
          policyId: 'EC2-001',
          policyName: 'EC2 IMDSv2 Required',
          message: 'Instance metadata service downgraded from v2 to v1',
          severity: 'medium',
          resourceType: 'aws_instance',
          resourceAddress: 'aws_instance.web_server',
          remediation: 'Set metadata_options.http_tokens = required',
          category: 'security',
          frameworks: ['hipaa', 'pci_dss', 'iso_27001', 'soc2'],
        ),
        PolicyViolation(
          policyId: 'EC2-002',
          policyName: 'EC2 Root Volume Encryption',
          message: 'Root volume encryption has been disabled',
          severity: 'high',
          resourceType: 'aws_instance',
          resourceAddress: 'aws_instance.api_server',
          remediation: 'Set encrypted = true in root_block_device',
          category: 'security',
          frameworks: ['hipaa', 'pci_dss', 'iso_27001', 'gdpr', 'soc2'],
        ),
        PolicyViolation(
          policyId: 'EC2-003',
          policyName: 'EC2 Public IP Warning',
          message: 'Instance now has a public IP assigned',
          severity: 'medium',
          resourceType: 'aws_instance',
          resourceAddress: 'aws_instance.worker',
          remediation: 'Remove associate_public_ip_address or use NAT gateway',
          category: 'security',
          frameworks: ['hipaa', 'pci_dss', 'soc2'],
        ),
        PolicyViolation(
          policyId: 'TAG-001',
          policyName: 'Environment Tag Required',
          message: 'Environment tag changed from production to staging',
          severity: 'medium',
          resourceType: 'aws_instance',
          resourceAddress: 'aws_instance.worker',
          remediation: 'Restore Environment tag to correct value',
          category: 'tagging',
          frameworks: ['soc2'],
        ),
      ],
      warnings: [
        PolicyViolation(
          policyId: 'EC2-005',
          policyName: 'EC2 Large Instance Review',
          message: 'Instance upsized to t3.xlarge — review for cost',
          severity: 'medium',
          resourceType: 'aws_instance',
          resourceAddress: 'aws_instance.web_server',
          remediation: 'Consider right-sizing based on actual utilization',
          category: 'cost',
        ),
        PolicyViolation(
          policyId: 'TAG-002',
          policyName: 'Owner Tag Recommended',
          message: 'Missing Owner tag',
          severity: 'low',
          resourceType: 'aws_instance',
          resourceAddress: 'aws_instance.api_server',
          remediation: 'Add Owner tag with responsible team',
          category: 'tagging',
        ),
      ],
      passed: 45,
      failed: 4,
    ),
    scanDurationMs: 4521,
    timestamp: now.subtract(const Duration(hours: 6)).toIso8601String(),
  );
}

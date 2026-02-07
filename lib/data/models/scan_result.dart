import 'drift_info.dart';
import 'evaluation_result.dart';

/// Top-level result returned by the Cloudrift CLI's `--format=json` output.
///
/// Maps directly to the Go struct `output.ScanResult` in `internal/output/formatter.go`.
/// Contains drift detection results, optional policy evaluation, and scan metadata.
class ScanResult {
  /// AWS service that was scanned (e.g. `S3`, `EC2`).
  final String service;

  /// AWS account ID where the scan was performed.
  final String accountId;

  /// AWS region targeted by the scan.
  final String region;

  /// Total number of resources discovered in the Terraform plan.
  final int totalResources;

  /// Number of resources with detected drift.
  final int driftCount;

  /// Individual drift entries for each resource with differences.
  final List<DriftInfo> drifts;

  /// OPA policy evaluation results, or `null` if policies were skipped.
  final EvaluationResult? policyResult;

  /// Wall-clock scan duration in milliseconds.
  final int scanDurationMs;

  /// ISO 8601 timestamp of when the scan was performed.
  final String timestamp;

  const ScanResult({
    required this.service,
    this.accountId = '',
    this.region = '',
    this.totalResources = 0,
    this.driftCount = 0,
    this.drifts = const [],
    this.policyResult,
    this.scanDurationMs = 0,
    this.timestamp = '',
  });

  /// Deserializes from the Cloudrift CLI JSON output.
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      service: json['service'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      region: json['region'] as String? ?? '',
      totalResources: json['total_resources'] as int? ?? 0,
      driftCount: json['drift_count'] as int? ?? 0,
      drifts: (json['drifts'] as List<dynamic>?)
              ?.map((d) => DriftInfo.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      policyResult: json['policy_result'] != null
          ? EvaluationResult.fromJson(
              json['policy_result'] as Map<String, dynamic>)
          : null,
      scanDurationMs: json['scan_duration_ms'] as int? ?? 0,
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  /// Serializes back to JSON for local storage persistence.
  Map<String, dynamic> toJson() => {
        'service': service,
        'account_id': accountId,
        'region': region,
        'total_resources': totalResources,
        'drift_count': driftCount,
        'drifts': drifts.map((d) => d.toJson()).toList(),
        if (policyResult != null) 'policy_result': policyResult!.toJson(),
        'scan_duration_ms': scanDurationMs,
        'timestamp': timestamp,
      };
}

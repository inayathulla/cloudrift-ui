/// Persisted record of a completed scan, stored in Hive local storage.
///
/// Captures summary metrics for display in the scan history table and
/// trend charts, plus the raw JSON for reconstructing the full [ScanResult].
class ScanHistoryEntry {
  /// Unique identifier (UUID v4) for this history entry.
  final String id;

  /// When the scan was performed.
  final DateTime timestamp;

  /// AWS service that was scanned (e.g. `s3`, `ec2`).
  final String service;

  /// AWS region targeted by the scan.
  final String region;

  /// AWS account ID where the scan was performed.
  final String accountId;

  /// Total number of resources discovered.
  final int totalResources;

  /// Number of resources with detected drift.
  final int driftCount;

  /// Number of blocking policy violations found.
  final int policyViolations;

  /// Number of advisory policy warnings found.
  final int policyWarnings;

  /// Scan duration in milliseconds.
  final int scanDurationMs;

  /// Full JSON output from the CLI, used to reconstruct [ScanResult] on demand.
  final String rawJson;

  /// Scan outcome: `completed` or `error`.
  final String status;

  const ScanHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.service,
    this.region = '',
    this.accountId = '',
    this.totalResources = 0,
    this.driftCount = 0,
    this.policyViolations = 0,
    this.policyWarnings = 0,
    this.scanDurationMs = 0,
    this.rawJson = '',
    this.status = 'completed',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'service': service,
        'region': region,
        'account_id': accountId,
        'total_resources': totalResources,
        'drift_count': driftCount,
        'policy_violations': policyViolations,
        'policy_warnings': policyWarnings,
        'scan_duration_ms': scanDurationMs,
        'raw_json': rawJson,
        'status': status,
      };

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScanHistoryEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      service: json['service'] as String,
      region: json['region'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      totalResources: json['total_resources'] as int? ?? 0,
      driftCount: json['drift_count'] as int? ?? 0,
      policyViolations: json['policy_violations'] as int? ?? 0,
      policyWarnings: json['policy_warnings'] as int? ?? 0,
      scanDurationMs: json['scan_duration_ms'] as int? ?? 0,
      rawJson: json['raw_json'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
    );
  }
}

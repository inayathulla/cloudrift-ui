/// Riverpod providers for the Cloudrift UI application.
///
/// Provides dependency injection for datasources, repositories, scan state
/// management, derived data (resource summaries, compliance scores), and
/// scan history. All reactive — downstream consumers rebuild automatically
/// when upstream data changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/cli_datasource.dart';
import '../data/datasources/config_datasource.dart';
import '../data/datasources/local_storage_datasource.dart';
import '../data/models/compliance_score.dart';
import '../data/models/resource_summary.dart';
import '../data/models/scan_history_entry.dart';
import '../data/models/scan_result.dart';
import '../data/models/severity.dart';
import '../data/repositories/scan_repository.dart';

// ---------------------------------------------------------------------------
// Datasource providers
// ---------------------------------------------------------------------------

/// Hive-backed local storage. Overridden in `main()` with a pre-initialized
/// instance to avoid late-initialization errors.
final localStorageProvider = Provider<LocalStorageDatasource>((ref) {
  return LocalStorageDatasource();
});

/// CLI datasource that bridges to the Cloudrift Go binary.
final cliDatasourceProvider = Provider<CliDatasource>((ref) {
  return CliDatasource();
});

/// YAML config file reader/writer.
final configDatasourceProvider = Provider<ConfigDatasource>((ref) {
  return ConfigDatasource();
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Central repository coordinating CLI execution and history persistence.
final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  return ScanRepository(
    ref.watch(cliDatasourceProvider),
    ref.watch(localStorageProvider),
  );
});

// ---------------------------------------------------------------------------
// Scan state machine
// ---------------------------------------------------------------------------

/// Lifecycle states for a scan operation.
enum ScanStatus { idle, running, completed, error }

/// Immutable snapshot of the current scan lifecycle.
///
/// Transitions: `idle` → `running` → `completed` | `error`.
class ScanState {
  /// Current lifecycle phase.
  final ScanStatus status;

  /// Scan result on successful completion.
  final ScanResult? result;

  /// Error message if the scan failed.
  final String? error;

  /// Human-readable description of the current scan phase.
  final String? currentPhase;

  /// Timestamp when the scan started, used for the elapsed timer.
  final DateTime? startedAt;

  const ScanState({
    this.status = ScanStatus.idle,
    this.result,
    this.error,
    this.currentPhase,
    this.startedAt,
  });

  ScanState copyWith({
    ScanStatus? status,
    ScanResult? result,
    String? error,
    String? currentPhase,
    DateTime? startedAt,
  }) {
    return ScanState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error,
      currentPhase: currentPhase ?? this.currentPhase,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

/// Manages the scan lifecycle: idle → running → completed/error.
///
/// On successful completion, invalidates [scanHistoryProvider] and
/// [latestScanResultProvider] so all dependent widgets rebuild.
class ScanNotifier extends StateNotifier<ScanState> {
  final ScanRepository _repository;
  final Ref _ref;

  ScanNotifier(this._repository, this._ref) : super(const ScanState());

  /// Initiates a Cloudrift scan with the given parameters.
  ///
  /// Transitions state from `idle` → `running` → `completed`/`error`.
  Future<void> runScan({
    required String configPath,
    required String service,
    String? policyDir,
    bool skipPolicies = false,
  }) async {
    state = ScanState(
      status: ScanStatus.running,
      currentPhase: 'Starting scan...',
      startedAt: DateTime.now(),
    );

    try {
      final result = await _repository.runScan(
        configPath: configPath,
        service: service,
        policyDir: policyDir,
        skipPolicies: skipPolicies,
      );

      state = ScanState(status: ScanStatus.completed, result: result);
      _ref.invalidate(scanHistoryProvider);
      _ref.invalidate(latestScanResultProvider);
    } catch (e) {
      state = ScanState(status: ScanStatus.error, error: e.toString());
    }
  }

  /// Resets the scan state back to idle.
  void reset() {
    state = const ScanState();
  }
}

/// Provides the current [ScanState] and exposes [ScanNotifier] for mutations.
final scanStateProvider =
    StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref.watch(scanRepositoryProvider), ref);
});

// ---------------------------------------------------------------------------
// Derived data providers
// ---------------------------------------------------------------------------

/// All persisted scan history entries, sorted newest first.
///
/// Invalidated by [ScanNotifier] after each successful scan.
final scanHistoryProvider = Provider<List<ScanHistoryEntry>>((ref) {
  return ref.watch(scanRepositoryProvider).getHistory();
});

/// Full [ScanResult] reconstructed from the most recent history entry.
///
/// Returns `null` if no scans have been performed yet.
final latestScanResultProvider = Provider<ScanResult?>((ref) {
  final history = ref.watch(scanHistoryProvider);
  if (history.isEmpty) return null;
  return ref.read(scanRepositoryProvider).getResultFromHistory(history.first);
});

/// Per-resource summaries combining drift and policy data from the latest scan.
///
/// Each [ResourceSummary] aggregates a resource's drift info, matching policy
/// violations, and computes the highest severity. Sorted most-severe first.
final resourceSummariesProvider = Provider<List<ResourceSummary>>((ref) {
  final result = ref.watch(latestScanResultProvider);
  if (result == null) return [];

  final summaries = <ResourceSummary>[];
  for (final drift in result.drifts) {
    final violations = result.policyResult?.violations
            .where((v) =>
                v.resourceAddress == drift.resourceId ||
                v.resourceAddress.contains(drift.resourceName))
            .toList() ??
        [];

    Severity highestSeverity = Severity.info;
    if (drift.missing) {
      highestSeverity = Severity.critical;
    } else if (violations.isNotEmpty) {
      for (final v in violations) {
        final s = Severity.fromString(v.severity);
        if (s.sortOrder < highestSeverity.sortOrder) {
          highestSeverity = s;
        }
      }
    } else if (drift.hasDrift) {
      highestSeverity = Severity.fromString(drift.severity);
    }

    summaries.add(ResourceSummary(
      resourceId: drift.resourceId,
      resourceName: drift.resourceName,
      resourceType: drift.resourceType,
      service: result.service,
      highestSeverity: highestSeverity,
      driftCount: drift.diffs.length + drift.extraAttributes.length,
      violationCount: violations.length,
      driftInfo: drift,
      violations: violations,
    ));
  }

  summaries.sort((a, b) => a.highestSeverity.sortOrder.compareTo(b.highestSeverity.sortOrder));
  return summaries;
});

// ---------------------------------------------------------------------------
// Compliance scoring
// ---------------------------------------------------------------------------

/// Policy ID prefixes that map to the Security category.
const _securityPrefixes = ['S3-', 'EC2-', 'SG-'];

/// Policy ID prefixes that map to the Tagging category.
const _taggingPrefixes = ['TAG-'];

/// Policy ID prefixes that map to the Cost category.
const _costPrefixes = ['COST-'];

/// Expected total policy counts per category (used for percentage calculation).
const _securityPolicyCount = 14;
const _taggingPolicyCount = 4;
const _costPolicyCount = 3;

/// Builds a [CategoryScore] from the list of failing policy IDs.
CategoryScore _buildCategoryScore(
    String name, List<String> failing, int estimatedTotal) {
  final passed = estimatedTotal - failing.length;
  return CategoryScore(
    name: name,
    percentage:
        estimatedTotal > 0 ? (passed / estimatedTotal) * 100.0 : 100.0,
    passed: passed.clamp(0, estimatedTotal),
    failed: failing.length,
    failingPolicyIds: failing,
  );
}

/// Computed compliance posture from the latest scan's policy results.
///
/// Breaks down violations into Security, Tagging, and Cost categories
/// and computes per-category and overall compliance percentages.
final complianceScoreProvider = Provider<ComplianceScore>((ref) {
  final result = ref.watch(latestScanResultProvider);
  if (result == null || result.policyResult == null) {
    return ComplianceScore.empty();
  }

  final pr = result.policyResult!;
  final total = pr.passed + pr.failed;
  final percentage = total > 0 ? (pr.passed / total) * 100.0 : 100.0;

  // Group violations by category in a single pass
  final securityViolations = <String>[];
  final taggingViolations = <String>[];
  final costViolations = <String>[];

  for (final v in pr.violations) {
    _categorize(v.policyId, securityViolations, taggingViolations, costViolations);
  }
  for (final v in pr.warnings) {
    _categorize(v.policyId, securityViolations, taggingViolations, costViolations);
  }

  return ComplianceScore(
    overallPercentage: percentage,
    categories: {
      'security': _buildCategoryScore('Security', securityViolations, _securityPolicyCount),
      'tagging': _buildCategoryScore('Tagging', taggingViolations, _taggingPolicyCount),
      'cost': _buildCategoryScore('Cost', costViolations, _costPolicyCount),
    },
    totalPolicies: total,
    passingPolicies: pr.passed,
    failingPolicies: pr.failed,
  );
});

/// Routes a policy ID into the appropriate category bucket.
void _categorize(String policyId, List<String> security,
    List<String> tagging, List<String> cost) {
  for (final prefix in _securityPrefixes) {
    if (policyId.startsWith(prefix)) {
      security.add(policyId);
      return;
    }
  }
  for (final prefix in _taggingPrefixes) {
    if (policyId.startsWith(prefix)) {
      tagging.add(policyId);
      return;
    }
  }
  for (final prefix in _costPrefixes) {
    if (policyId.startsWith(prefix)) {
      cost.add(policyId);
      return;
    }
  }
}

/// Checks whether the Cloudrift CLI binary is available on the system.
final cliAvailableProvider = FutureProvider<bool>((ref) {
  return ref.read(scanRepositoryProvider).isCliAvailable();
});

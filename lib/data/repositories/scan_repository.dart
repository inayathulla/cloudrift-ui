import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../datasources/cli_datasource.dart';
import '../datasources/local_storage_datasource.dart';
import '../models/scan_history_entry.dart';
import '../models/scan_result.dart';

/// Coordinates the CLI datasource and local storage for scan operations.
///
/// Orchestrates the scan workflow: invokes the CLI, persists results to
/// Hive history, and provides methods for history retrieval and management.
class ScanRepository {
  final CliDatasource _cliDatasource;
  final LocalStorageDatasource _storageDatasource;
  final _uuid = const Uuid();

  ScanRepository(this._cliDatasource, this._storageDatasource);

  /// Runs a Cloudrift scan, persists the result to history, and returns it.
  ///
  /// The scan is delegated to [CliDatasource.runScan]. On success, a
  /// [ScanHistoryEntry] is created with a UUID and saved to Hive storage.
  Future<ScanResult> runScan({
    required String configPath,
    required String service,
    String? policyDir,
    bool skipPolicies = false,
  }) async {
    final result = await _cliDatasource.runScan(
      configPath: configPath,
      service: service,
      policyDir: policyDir,
      skipPolicies: skipPolicies,
    );

    // Persist to history
    final entry = ScanHistoryEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      service: result.service,
      region: result.region,
      accountId: result.accountId,
      totalResources: result.totalResources,
      driftCount: result.driftCount,
      policyViolations: result.policyResult?.violations.length ?? 0,
      policyWarnings: result.policyResult?.warnings.length ?? 0,
      scanDurationMs: result.scanDurationMs,
      rawJson: jsonEncode(result.toJson()),
      status: 'completed',
    );
    await _storageDatasource.saveScanEntry(entry);

    return result;
  }

  /// Returns all scan history entries sorted by timestamp (newest first).
  List<ScanHistoryEntry> getHistory() {
    return _storageDatasource.getAllHistory();
  }

  /// Reconstructs a full [ScanResult] from a history entry's stored raw JSON.
  ///
  /// Returns `null` if the raw JSON is empty or fails to parse.
  ScanResult? getResultFromHistory(ScanHistoryEntry entry) {
    if (entry.rawJson.isEmpty) return null;
    try {
      final json = jsonDecode(entry.rawJson) as Map<String, dynamic>;
      return ScanResult.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a single history entry by [id].
  Future<void> deleteHistoryEntry(String id) async {
    await _storageDatasource.deleteScanEntry(id);
  }

  /// Clears all scan history.
  Future<void> clearHistory() async {
    await _storageDatasource.clearHistory();
  }

  /// Delegates to [CliDatasource.isCliAvailable].
  Future<bool> isCliAvailable() => _cliDatasource.isCliAvailable();

  /// Delegates to [CliDatasource.getCliVersion].
  Future<String?> getCliVersion() => _cliDatasource.getCliVersion();

  /// Updates the CLI binary path used for subsequent scans.
  void setCliBinaryPath(String path) {
    _cliDatasource.setCliBinaryPath(path);
  }
}

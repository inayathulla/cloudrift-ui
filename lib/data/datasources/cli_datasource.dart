import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/scan_result.dart';

/// Bridge between the Flutter UI and the Cloudrift Go CLI binary.
///
/// - **Desktop**: Invokes the CLI directly via [Process.run].
/// - **Web**: Calls the backend API server that wraps the CLI.
class CliDatasource {
  String _cliBinaryPath = '';
  String _cloudriftRepoDir = '';

  /// Base URL for the backend API (web mode only).
  /// Defaults to same origin (nginx proxies /api to the Go server).
  String _apiBaseUrl = '';

  CliDatasource() {
    if (kIsWeb) {
      // Same origin — nginx reverse proxies /api to Go backend
      _apiBaseUrl = '';
    } else {
      _detectPaths();
    }
  }

  // ---------------------------------------------------------------------------
  // Desktop: path detection
  // ---------------------------------------------------------------------------

  void _detectPaths() {
    // Build candidate paths dynamically from environment
    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      if (home.isNotEmpty) '$home/Developer/startup/cloudrift',
      if (home.isNotEmpty) '$home/cloudrift',
    ];

    for (final dir in candidates) {
      final binary = '$dir/cloudrift';
      if (File(binary).existsSync()) {
        _cliBinaryPath = binary;
        _cloudriftRepoDir = dir;
        return;
      }
    }

    try {
      final scriptDir = Platform.script.toFilePath();
      final projectDir = scriptDir.contains('cloudrift-ui')
          ? scriptDir.substring(0, scriptDir.indexOf('cloudrift-ui'))
          : '';
      if (projectDir.isNotEmpty) {
        final siblingDir = '${projectDir}cloudrift';
        final siblingBinary = '$siblingDir/cloudrift';
        if (File(siblingBinary).existsSync()) {
          _cliBinaryPath = siblingBinary;
          _cloudriftRepoDir = siblingDir;
          return;
        }
      }
    } catch (_) {}

    final gopath = Platform.environment['GOPATH'] ??
        '${Platform.environment['HOME']}/go';
    final gopathBin = '$gopath/bin/cloudrift';
    if (File(gopathBin).existsSync()) {
      _cliBinaryPath = gopathBin;
      _cloudriftRepoDir = '';
      return;
    }

    _cliBinaryPath = 'cloudrift';
    _cloudriftRepoDir = '';
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void setCliBinaryPath(String path) {
    _cliBinaryPath = path;
    if (!kIsWeb) {
      final binaryFile = File(path);
      if (binaryFile.existsSync()) {
        _cloudriftRepoDir = binaryFile.parent.path;
      }
    }
  }

  String get cliBinaryPath => _cliBinaryPath;
  String get cloudriftRepoDir => _cloudriftRepoDir;

  String get defaultConfigPath {
    if (kIsWeb) return 'config/cloudrift-s3.yml';
    if (_cloudriftRepoDir.isNotEmpty) {
      final configFile = File('$_cloudriftRepoDir/config/cloudrift-s3.yml');
      if (configFile.existsSync()) return configFile.path;
    }
    return 'cloudrift-s3.yml';
  }

  Future<bool> isCliAvailable() async {
    if (kIsWeb) {
      try {
        final resp = await http.get(Uri.parse('$_apiBaseUrl/api/health'));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          return body['available'] == true;
        }
        return false;
      } catch (_) {
        return false;
      }
    }
    try {
      final result = await Process.run(_cliBinaryPath, ['scan', '--help']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getCliVersion() async {
    if (kIsWeb) {
      try {
        final resp = await http.get(Uri.parse('$_apiBaseUrl/api/version'));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          return body['version'] as String?;
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    try {
      final result = await Process.run(_cliBinaryPath, ['--version']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ScanResult> runScan({
    required String configPath,
    required String service,
    String? policyDir,
    bool skipPolicies = false,
  }) async {
    if (kIsWeb) {
      return _runScanWeb(
        configPath: configPath,
        service: service,
        policyDir: policyDir,
        skipPolicies: skipPolicies,
      );
    }
    return _runScanDesktop(
      configPath: configPath,
      service: service,
      policyDir: policyDir,
      skipPolicies: skipPolicies,
    );
  }

  // ---------------------------------------------------------------------------
  // Web: HTTP calls to backend API
  // ---------------------------------------------------------------------------

  Future<ScanResult> _runScanWeb({
    required String configPath,
    required String service,
    String? policyDir,
    bool skipPolicies = false,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_apiBaseUrl/api/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service': service,
          'config_path': configPath,
          if (policyDir != null && policyDir.isNotEmpty) 'policy_dir': policyDir,
          if (skipPolicies) 'skip_policies': true,
        }),
      );

      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw CliException(body['error'] as String? ?? 'Scan failed');
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return ScanResult.fromJson(json);
    } on CliException {
      rethrow;
    } catch (e) {
      throw CliException('Failed to reach API server: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Desktop: direct Process.run
  // ---------------------------------------------------------------------------

  Future<ScanResult> _runScanDesktop({
    required String configPath,
    required String service,
    String? policyDir,
    bool skipPolicies = false,
  }) async {
    final args = [
      'scan',
      '--config=$configPath',
      '--service=$service',
      '--format=json',
      '--no-emoji',
    ];

    if (policyDir != null && policyDir.isNotEmpty) {
      args.add('--policy-dir=$policyDir');
    }
    if (skipPolicies) {
      args.add('--skip-policies');
    }

    final result = await Process.run(
      _cliBinaryPath,
      args,
      environment: Platform.environment,
      workingDirectory:
          _cloudriftRepoDir.isNotEmpty ? _cloudriftRepoDir : null,
    );

    final stdout = result.stdout as String;
    final stderr = result.stderr as String;

    // Try to parse JSON output even on non-zero exit codes.
    // The CLI may exit with code 1 when policy engine fails but drift
    // detection succeeds — the JSON output is still valid and useful.
    try {
      final jsonStr = _extractJson(stdout);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ScanResult.fromJson(json);
    } catch (_) {
      // No valid JSON found — now treat as a real failure
      if (result.exitCode != 0) {
        throw CliException(
            'Scan failed (exit code ${result.exitCode}): ${stderr.isNotEmpty ? stderr : stdout}');
      }
      throw CliException('Failed to parse scan output.\nOutput: $stdout');
    }
  }

  String _extractJson(String output) {
    final jsonStart = output.indexOf('{');
    if (jsonStart == -1) {
      throw const FormatException('No JSON object found in output');
    }
    final jsonEnd = output.lastIndexOf('}');
    if (jsonEnd == -1 || jsonEnd <= jsonStart) {
      throw const FormatException('Incomplete JSON object in output');
    }
    return output.substring(jsonStart, jsonEnd + 1);
  }
}

/// Exception thrown when a CLI operation fails.
class CliException implements Exception {
  final String message;
  const CliException(this.message);

  @override
  String toString() => message;
}

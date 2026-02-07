import 'dart:convert';
import 'dart:io';

import '../models/scan_result.dart';

/// Bridge between the Flutter UI and the Cloudrift Go CLI binary.
///
/// Invokes the `cloudrift` CLI via [Process.run], parses its JSON stdout,
/// and returns typed [ScanResult] objects. Handles binary auto-detection,
/// working directory resolution, and stdout JSON extraction.
class CliDatasource {
  String _cliBinaryPath = '';
  String _cloudriftRepoDir = '';

  CliDatasource() {
    _detectPaths();
  }

  /// Detects the cloudrift binary path and repo directory.
  void _detectPaths() {
    // Check common development paths
    const candidates = [
      '/Users/inayath/Developer/startup/cloudrift',
    ];

    for (final dir in candidates) {
      final binary = '$dir/cloudrift';
      if (File(binary).existsSync()) {
        _cliBinaryPath = binary;
        _cloudriftRepoDir = dir;
        return;
      }
    }

    // Check sibling repo relative to this project via Platform.script
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

    // Check GOPATH/bin
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

  /// Manually overrides the CLI binary path and derives the repo directory.
  void setCliBinaryPath(String path) {
    _cliBinaryPath = path;
    // Derive repo dir from binary path
    final binaryFile = File(path);
    if (binaryFile.existsSync()) {
      _cloudriftRepoDir = binaryFile.parent.path;
    }
  }

  /// Current path to the cloudrift binary.
  String get cliBinaryPath => _cliBinaryPath;

  /// Root directory of the cloudrift repository, used as working directory.
  String get cloudriftRepoDir => _cloudriftRepoDir;

  /// Returns the default config file path if it exists in the repo.
  String get defaultConfigPath {
    if (_cloudriftRepoDir.isNotEmpty) {
      final configFile = File('$_cloudriftRepoDir/config/cloudrift.yml');
      if (configFile.existsSync()) return configFile.path;
    }
    return 'cloudrift.yml';
  }

  /// Checks if the cloudrift binary is accessible and responds to `scan --help`.
  Future<bool> isCliAvailable() async {
    try {
      final result = await Process.run(_cliBinaryPath, ['scan', '--help']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns the CLI version string, or `null` if unavailable.
  Future<String?> getCliVersion() async {
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

  /// Executes a Cloudrift scan and returns the parsed result.
  ///
  /// Runs `cloudrift scan --config=<path> --service=<svc> --format=json --no-emoji`
  /// via [Process.run]. Handles exit codes:
  /// - `0` = success (no drift)
  /// - `1` = error (throws [CliException])
  /// - `2` = policy violations found (still returns valid output)
  ///
  /// Throws [CliException] on scan failure or JSON parse errors.
  Future<ScanResult> runScan({
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

    if (result.exitCode == 1) {
      throw CliException('Scan failed: ${stderr.isNotEmpty ? stderr : stdout}');
    }

    // Exit code 0 = success, 2 = policy violations found (still valid output)
    // The CLI prints status messages before the JSON output,
    // so extract just the JSON portion from stdout.
    try {
      final jsonStr = _extractJson(stdout);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ScanResult.fromJson(json);
    } catch (e) {
      throw CliException('Failed to parse scan output: $e\nOutput: $stdout');
    }
  }

  /// Extracts the JSON object from CLI output that may contain
  /// status/progress lines before the JSON.
  String _extractJson(String output) {
    // Find the first '{' which starts the JSON object
    final jsonStart = output.indexOf('{');
    if (jsonStart == -1) {
      throw const FormatException('No JSON object found in output');
    }
    // Find the matching closing '}' by scanning from the end
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

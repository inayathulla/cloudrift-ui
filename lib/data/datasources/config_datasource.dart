import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

import '../models/cloudrift_config.dart';
import '../models/file_list_result.dart';
import '../models/terraform_job.dart';
import '../models/terraform_status.dart';

/// Reads and writes `cloudrift.yml` configuration files.
///
/// - **Desktop**: Uses direct file system I/O.
/// - **Web**: Calls the backend API server (proxied via nginx).
class ConfigDatasource {
  /// Base URL for the backend API (web mode only).
  final String _apiBaseUrl = '';

  // ---------------------------------------------------------------------------
  // Config file operations
  // ---------------------------------------------------------------------------

  /// Loads and parses a `cloudrift.yml` file from [path].
  Future<CloudriftConfig> loadConfig(String path) async {
    if (kIsWeb) return _loadConfigWeb(path);
    final file = File(path);
    if (!await file.exists()) {
      throw ConfigException('Config file not found: $path');
    }
    final content = await file.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    return CloudriftConfig.fromYaml(Map<String, dynamic>.from(yaml));
  }

  Future<CloudriftConfig> _loadConfigWeb(String path) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/config').replace(
        queryParameters: {'path': path},
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw ConfigException('Failed to load config: ${resp.body}');
      }
      final yaml = loadYaml(resp.body) as YamlMap;
      return CloudriftConfig.fromYaml(Map<String, dynamic>.from(yaml));
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to reach API: $e');
    }
  }

  /// Writes a [CloudriftConfig] to a YAML file at [path].
  Future<void> saveConfig(String path, CloudriftConfig config) async {
    if (kIsWeb) return _saveConfigWeb(path, config);
    final file = File(path);
    await file.writeAsString(config.toYaml());
  }

  Future<void> _saveConfigWeb(String path, CloudriftConfig config) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/config').replace(
        queryParameters: {'path': path},
      );
      final resp = await http.put(
        uri,
        headers: {'Content-Type': 'text/yaml'},
        body: config.toYaml(),
      );
      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw ConfigException(body['error'] as String? ?? 'Save failed');
      }
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to reach API: $e');
    }
  }

  /// Checks whether a config file exists at the given [path].
  Future<bool> configExists(String path) async {
    if (kIsWeb) {
      try {
        final uri = Uri.parse('$_apiBaseUrl/api/config').replace(
          queryParameters: {'path': path},
        );
        final resp = await http.get(uri);
        return resp.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
    return File(path).exists();
  }

  // ---------------------------------------------------------------------------
  // File listing
  // ---------------------------------------------------------------------------

  /// Fetches the list of available config and plan files from the API.
  Future<FileListResult> listFiles() async {
    try {
      final resp = await http.get(Uri.parse('$_apiBaseUrl/api/files/list'));
      if (resp.statusCode != 200) {
        throw ConfigException('Failed to list files: ${resp.body}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return FileListResult.fromJson(json);
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to reach API: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Plan file operations
  // ---------------------------------------------------------------------------

  /// Reads a plan JSON file.
  Future<String> loadPlanJson(String path) async {
    if (!kIsWeb) {
      final file = File(path);
      if (!await file.exists()) throw ConfigException('Plan not found: $path');
      return file.readAsString();
    }
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/files/plan').replace(
        queryParameters: {'path': path},
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw ConfigException('Failed to load plan: ${resp.body}');
      }
      return resp.body;
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to reach API: $e');
    }
  }

  /// Saves plan JSON content to the API.
  Future<void> savePlanJson(String path, String jsonContent) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/files/plan').replace(
        queryParameters: {'path': path},
      );
      final resp = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonContent,
      );
      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw ConfigException(body['error'] as String? ?? 'Save failed');
      }
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to reach API: $e');
    }
  }

  /// Generates a plan.json from form data and saves it, updating the config.
  /// Returns a map with `plan_path` and `config` keys.
  Future<Map<String, String>> generatePlan(
      String service, Map<String, dynamic> planJson) async {
    try {
      final resp = await http.post(
        Uri.parse('$_apiBaseUrl/api/files/generate-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'service': service, 'plan': planJson}),
      );
      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw ConfigException(body['error'] as String? ?? 'Generate failed');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return {
        'plan_path': body['plan_path'] as String? ?? '',
        'config': body['config'] as String? ?? '',
      };
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to generate plan: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Terraform operations
  // ---------------------------------------------------------------------------

  /// Checks Terraform availability and lists .tf files.
  Future<TerraformStatus> getTerraformStatus() async {
    try {
      final resp =
          await http.get(Uri.parse('$_apiBaseUrl/api/terraform/status'));
      if (resp.statusCode != 200) {
        throw ConfigException(
            'Failed to get Terraform status: ${resp.body}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return TerraformStatus.fromJson(json);
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to reach API: $e');
    }
  }

  /// Uploads .tf and .tfvars files to the Terraform staging directory.
  Future<List<String>> uploadTerraformFiles(
      Map<String, List<int>> files) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/terraform/upload');
      final request = http.MultipartRequest('POST', uri);
      for (final entry in files.entries) {
        request.files.add(
          http.MultipartFile.fromBytes('files', entry.value,
              filename: entry.key),
        );
      }
      final streamedResp = await request.send();
      final resp = await http.Response.fromStream(streamedResp);
      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw ConfigException(body['error'] as String? ?? 'Upload failed');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return (body['uploaded'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to upload Terraform files: $e');
    }
  }

  /// Starts a Terraform plan generation job. Returns the job ID.
  Future<String> startTerraformPlan() async {
    try {
      final resp = await http.post(
        Uri.parse('$_apiBaseUrl/api/terraform/plan'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 409) {
        throw ConfigException(
            'Another Terraform operation is already running');
      }
      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw ConfigException(body['error'] as String? ?? 'Start failed');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['job_id'] as String;
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to start Terraform plan: $e');
    }
  }

  /// Polls the status of a Terraform job by its ID.
  Future<TerraformJobResult> getTerraformJobStatus(String jobId) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/terraform/job').replace(
        queryParameters: {'id': jobId},
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw ConfigException(
            body['error'] as String? ?? 'Job status failed');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return TerraformJobResult.fromJson(body);
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to poll Terraform job: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Plan file upload
  // ---------------------------------------------------------------------------

  /// Uploads a plan JSON file via multipart form.
  Future<String> uploadPlanFile(String fileName, List<int> bytes) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/files/upload');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final streamedResp = await request.send();
      final resp = await http.Response.fromStream(streamedResp);
      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw ConfigException(body['error'] as String? ?? 'Upload failed');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['path'] as String;
    } on ConfigException {
      rethrow;
    } catch (e) {
      throw ConfigException('Failed to upload: $e');
    }
  }
}

/// Exception thrown when a configuration file operation fails.
class ConfigException implements Exception {
  final String message;
  const ConfigException(this.message);

  @override
  String toString() => message;
}

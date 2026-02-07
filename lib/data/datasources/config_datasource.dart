import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/cloudrift_config.dart';

/// Reads and writes `cloudrift.yml` configuration files.
class ConfigDatasource {
  /// Loads and parses a `cloudrift.yml` file from [path].
  ///
  /// Throws [ConfigException] if the file does not exist.
  Future<CloudriftConfig> loadConfig(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ConfigException('Config file not found: $path');
    }
    final content = await file.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    return CloudriftConfig.fromYaml(Map<String, dynamic>.from(yaml));
  }

  /// Writes a [CloudriftConfig] to a YAML file at [path].
  Future<void> saveConfig(String path, CloudriftConfig config) async {
    final file = File(path);
    await file.writeAsString(config.toYaml());
  }

  /// Checks whether a config file exists at the given [path].
  Future<bool> configExists(String path) async {
    return File(path).exists();
  }
}

/// Exception thrown when a configuration file operation fails.
class ConfigException implements Exception {
  final String message;
  const ConfigException(this.message);

  @override
  String toString() => message;
}

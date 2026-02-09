/// Response from `GET /api/terraform/status`.
class TerraformStatus {
  final bool available;
  final String version;
  final List<String> tfFiles;
  final bool hasFiles;
  final bool initialized;
  final String tfDir;

  const TerraformStatus({
    required this.available,
    required this.version,
    required this.tfFiles,
    required this.hasFiles,
    required this.initialized,
    required this.tfDir,
  });

  factory TerraformStatus.fromJson(Map<String, dynamic> json) {
    return TerraformStatus(
      available: json['available'] as bool? ?? false,
      version: json['version'] as String? ?? '',
      tfFiles: (json['tf_files'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      hasFiles: json['has_files'] as bool? ?? false,
      initialized: json['initialized'] as bool? ?? false,
      tfDir: json['tf_dir'] as String? ?? '',
    );
  }
}

/// Response from the `/api/files/list` endpoint.
class FileListResult {
  final List<FileEntry> configs;
  final List<FileEntry> plans;

  const FileListResult({required this.configs, required this.plans});

  factory FileListResult.fromJson(Map<String, dynamic> json) {
    return FileListResult(
      configs: (json['configs'] as List<dynamic>? ?? [])
          .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      plans: (json['plans'] as List<dynamic>? ?? [])
          .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single file entry from the file listing.
class FileEntry {
  final String path;
  final String name;
  final int size;

  const FileEntry({required this.path, required this.name, required this.size});

  factory FileEntry.fromJson(Map<String, dynamic> json) {
    return FileEntry(
      path: json['path'] as String,
      name: json['name'] as String,
      size: json['size'] as int? ?? 0,
    );
  }
}

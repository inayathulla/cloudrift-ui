import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/scan_history_entry.dart';

/// Hive-backed local persistence for scan history and user settings.
///
/// Must call [init] before use. Uses [Hive.initFlutter] which handles
/// both desktop (file system) and web (IndexedDB) storage automatically.
class LocalStorageDatasource {
  static const _historyBoxName = 'scan_history';
  static const _settingsBoxName = 'settings';

  late Box<String> _historyBox;
  late Box<String> _settingsBox;

  /// Initializes Hive storage and opens boxes.
  ///
  /// Must be called once during app startup before any other operations.
  Future<void> init() async {
    await Hive.initFlutter('cloudrift_hive');
    _historyBox = await Hive.openBox<String>(_historyBoxName);
    _settingsBox = await Hive.openBox<String>(_settingsBoxName);
  }

  /// Persists a [ScanHistoryEntry] as JSON keyed by its ID.
  Future<void> saveScanEntry(ScanHistoryEntry entry) async {
    await _historyBox.put(entry.id, jsonEncode(entry.toJson()));
  }

  /// Returns all scan history entries, sorted by timestamp (newest first).
  ///
  /// Silently skips entries that fail to deserialize.
  List<ScanHistoryEntry> getAllHistory() {
    return _historyBox.values
        .map((raw) {
          try {
            return ScanHistoryEntry.fromJson(
                jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ScanHistoryEntry>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Deletes a single scan history entry by [id].
  Future<void> deleteScanEntry(String id) async {
    await _historyBox.delete(id);
  }

  /// Deletes all scan history entries.
  Future<void> clearHistory() async {
    await _historyBox.clear();
  }

  /// Saves a user setting as a string key-value pair.
  Future<void> saveSetting(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  /// Retrieves a setting value by [key], or `null` if not set.
  String? getSetting(String key) {
    return _settingsBox.get(key);
  }

  /// Removes a setting by [key].
  Future<void> deleteSetting(String key) async {
    await _settingsBox.delete(key);
  }
}

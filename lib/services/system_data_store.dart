import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Platform-safe JSON cache for system-dependent category data
/// (weapons, armor, gear, vehicles, …).
///
/// Each category gets its own file under `<appDocs>/system_data/<key>.json`
/// in the format:
/// ```json
/// { "lastFetched": "2026-01-15T10:30:00.000Z", "items": [ ... ] }
/// ```
class SystemDataStore {
  /// Stable filesystem key for this category (e.g. `"weapons"`).
  final String categoryKey;

  const SystemDataStore(this.categoryKey);

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}system_data');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$categoryKey.json');
  }

  /// Reads cached items. Returns an empty list if the file doesn't exist
  /// or fails to parse.
  Future<List<T>> read<T>(T Function(Map<String, dynamic>) fromJson) async {
    final f = await _file();
    if (!await f.exists()) return <T>[];
    try {
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = (decoded['items'] as List?) ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false);
    } catch (_) {
      return <T>[];
    }
  }

  /// Writes the items, stamping `lastFetched` with the current UTC time.
  Future<void> write<T>(
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final f = await _file();
    final payload = <String, dynamic>{
      'lastFetched': DateTime.now().toUtc().toIso8601String(),
      'items': items.map(toJson).toList(growable: false),
    };
    await f.writeAsString(jsonEncode(payload));
  }

  /// Raw bytes of the on-disk file, or `null` if it doesn't exist. Used
  /// by the cloud-sync layer to push the local cache verbatim to the
  /// shared GitHub repo without round-tripping through the model layer.
  Future<Uint8List?> readBytes() async {
    final f = await _file();
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  /// Overwrites the file's bytes wholesale. Used by the cloud-sync
  /// layer when pulling a cached database from the shared GitHub repo.
  Future<void> writeBytes(Uint8List bytes) async {
    final f = await _file();
    await f.writeAsBytes(bytes);
  }

  /// Returns the timestamp of the last successful write, or null if none.
  Future<DateTime?> lastFetched() async {
    final f = await _file();
    if (!await f.exists()) return null;
    try {
      final decoded = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final stamp = decoded['lastFetched'] as String?;
      return stamp == null ? null : DateTime.tryParse(stamp);
    } catch (_) {
      return null;
    }
  }
}

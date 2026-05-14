import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-safe JSON cache for system-dependent category data
/// (weapons, armor, gear, vehicles, …).
///
/// On non-web platforms each category gets its own file under
/// `<appDocs>/system_data/<key>.json`. On web `path_provider` and
/// `dart:io.File` have no implementation, so we fall back to
/// `SharedPreferencesAsync` (IndexedDB-backed on web in
/// `shared_preferences_web` ≥ 2.4) under the key `system_data.<key>`.
/// Both backends store the same envelope:
///
/// ```json
/// { "lastFetched": "2026-01-15T10:30:00.000Z", "items": [ ... ] }
/// ```
class SystemDataStore {
  /// Stable storage key for this category (e.g. `"weapons"`).
  final String categoryKey;

  const SystemDataStore(this.categoryKey);

  // --- Web backend (SharedPreferencesAsync → IndexedDB) ---

  String get _webKey => 'system_data.$categoryKey';

  SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  Future<String?> _readWebString() => _prefs.getString(_webKey);
  Future<void> _writeWebString(String value) =>
      _prefs.setString(_webKey, value);

  // --- File backend (mobile/desktop) ---

  Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}system_data');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$categoryKey.json');
  }

  /// Raw JSON envelope as a string, or null if nothing stored.
  Future<String?> _readEnvelopeString() async {
    if (kIsWeb) return _readWebString();
    final f = await _file();
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  Future<void> _writeEnvelopeString(String value) async {
    if (kIsWeb) {
      await _writeWebString(value);
      return;
    }
    final f = await _file();
    await f.writeAsString(value);
  }

  /// Reads cached items. Returns an empty list if nothing's stored
  /// or parsing fails.
  Future<List<T>> read<T>(T Function(Map<String, dynamic>) fromJson) async {
    final raw = await _readEnvelopeString();
    if (raw == null) return <T>[];
    try {
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
    final payload = <String, dynamic>{
      'lastFetched': DateTime.now().toUtc().toIso8601String(),
      'items': items.map(toJson).toList(growable: false),
    };
    await _writeEnvelopeString(jsonEncode(payload));
  }

  /// Raw bytes of the stored envelope, or `null` if it doesn't exist.
  /// Used by the cloud-sync layer to push the local cache verbatim to
  /// the shared GitHub repo without round-tripping through the model
  /// layer.
  Future<Uint8List?> readBytes() async {
    if (kIsWeb) {
      final raw = await _readWebString();
      if (raw == null) return null;
      return Uint8List.fromList(utf8.encode(raw));
    }
    final f = await _file();
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  /// Overwrites the stored bytes wholesale. Used by the cloud-sync
  /// layer when pulling a cached database from the shared GitHub repo.
  Future<void> writeBytes(Uint8List bytes) async {
    if (kIsWeb) {
      await _writeWebString(utf8.decode(bytes));
      return;
    }
    final f = await _file();
    await f.writeAsBytes(bytes);
  }

  /// Returns the timestamp of the last successful write, or null if none.
  Future<DateTime?> lastFetched() async {
    final raw = await _readEnvelopeString();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final stamp = decoded['lastFetched'] as String?;
      return stamp == null ? null : DateTime.tryParse(stamp);
    } catch (_) {
      return null;
    }
  }
}

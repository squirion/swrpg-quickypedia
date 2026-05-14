import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:swrpg_quickypedia/models/recently_viewed_entry.dart';

/// Persists the recently-viewed queue to SharedPreferences. Capacity
/// enforcement (max 10, dedup, move-to-front) lives in the notifier;
/// this store just round-trips the list verbatim.
class RecentlyViewedStore {
  static const _key = 'recently_viewed_v1';

  Future<List<RecentlyViewedEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = json.decode(raw);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map<String, dynamic>) RecentlyViewedEntry.fromJson(entry),
    ];
  }

  Future<void> save(List<RecentlyViewedEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      json.encode([for (final e in entries) e.toJson()]),
    );
  }
}

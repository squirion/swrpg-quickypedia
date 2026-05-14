/// A pointer to an item the user has recently opened. Stored in
/// SharedPreferences as a 10-deep FIFO queue, resolved against the
/// in-memory per-category list providers when rendering the row.
///
/// `kind` is one of: 'weapon', 'armor', 'gear', 'vehicle', 'starship',
/// 'beast', 'character'. `id` is the item's natural key — `name` for
/// the wiki-scraped categories, `Character.id` for characters.
class RecentlyViewedEntry {
  final String kind;
  final String id;

  const RecentlyViewedEntry({required this.kind, required this.id});

  Map<String, dynamic> toJson() => {'kind': kind, 'id': id};

  factory RecentlyViewedEntry.fromJson(Map<String, dynamic> json) =>
      RecentlyViewedEntry(
        kind: json['kind'] as String,
        id: json['id'] as String,
      );
}

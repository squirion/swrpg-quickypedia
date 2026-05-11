/// A single entry from the SWRPG FFG "Item Qualities" page — the rules
/// glossary that describes effects like Pierce, Sunder, Stun, etc.
///
/// Weapons reference qualities by name (sometimes with a numeric rank,
/// e.g. "Pierce 1"); the matching layer strips the rank before lookup.
class ItemQuality {
  /// Canonical name, e.g. `"Pierce"`, `"Stun setting"`. The trailing
  /// `(Active)` / `(Passive)` marker from the wiki heading is stripped.
  final String name;

  /// Either `"active"`, `"passive"`, or `null` when not annotated.
  final String? kind;

  /// One or more description paragraphs joined with `\n\n`.
  final String description;

  const ItemQuality({
    required this.name,
    required this.description,
    this.kind,
  });

  factory ItemQuality.fromJson(Map<String, dynamic> json) => ItemQuality(
        name: (json['name'] as String?) ?? '',
        kind: json['kind'] as String?,
        description: (json['description'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (kind != null) 'kind': kind,
        'description': description,
      };

  /// Normalize an arbitrary quality reference (e.g. `"Pierce 1"`,
  /// `"PIERCE"`, `"  pierce  "`) to a stable lookup key.
  static String lookupKey(String raw) {
    final s = raw.trim().toLowerCase();
    // Strip a trailing rank/number: "pierce 1" → "pierce".
    final m = RegExp(r'^(.*?)(?:\s+\d+)?$').firstMatch(s);
    return (m?.group(1) ?? s).trim();
  }
}

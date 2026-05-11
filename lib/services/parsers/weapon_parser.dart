import 'package:html/dom.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/utils/html_utils.dart';

/// Parse a single weapon page on the SWRPG FFG Fandom wiki.
///
/// Returns `null` for pages that don't look like a real weapon entry (no
/// portable infobox, no title, …) so they aren't persisted as junk.
Weapon? parseWeaponPage(Document doc, String sourceUrl) {
  final name = _extractTitle(doc);
  if (name == null || name.isEmpty) return null;

  final infobox = doc.querySelector('aside.portable-infobox');
  if (infobox == null) {
    // Some category members aren't actual weapon pages (e.g. redirects or
    // overview pages). Skip them.
    return null;
  }

  final fields = _extractInfoboxFields(infobox);

  return Weapon(
    name: name,
    skill: fields['skill'],
    damage: fields['damage'],
    critical: fields['critical'] ?? fields['crit'],
    range: fields['range'],
    encumbrance: fields['encumbrance'] ?? fields['enc'],
    hardpoints: fields['hardpoints'] ?? fields['hp'] ?? fields['hard points'],
    price: fields['price'] ?? fields['cost'],
    rarity: fields['rarity'],
    specialQualities: _extractSpecialQualities(fields),
    description: _extractLeadParagraph(doc, infobox),
    sourceUrl: sourceUrl,
  );
}

String? _extractTitle(Document doc) {
  final header = doc.querySelector('h1.page-header__title');
  final raw = header?.text ?? doc.querySelector('title')?.text;
  if (raw == null) return null;
  // Fandom's <title> looks like "Heavy Blaster Pistol | Star Wars RPG …".
  final cleaned = raw.split('|').first.trim();
  return cleaned.isEmpty ? null : cleaned;
}

/// Walks the infobox's `.pi-data` rows and returns a `{key: value}` map.
///
/// Key resolution prefers the `data-source` attribute when present (it's a
/// machine-friendly slug Fandom emits for templated infoboxes), falling back
/// to the visible label. Both are normalized to lowercase, whitespace-trimmed
/// so callers can look up `'special qualities'` regardless of casing.
Map<String, String> _extractInfoboxFields(Element infobox) {
  final out = <String, String>{};
  for (final row in infobox.querySelectorAll('.pi-data')) {
    final dataSource = row.attributes['data-source']?.trim().toLowerCase();
    final labelEl = row.querySelector('.pi-data-label');
    final valueEl = row.querySelector('.pi-data-value');
    if (valueEl == null) continue;
    final value = _normalize(valueEl.text);
    if (value.isEmpty) continue;

    final keys = <String>{
      if (dataSource != null && dataSource.isNotEmpty) dataSource,
      if (labelEl != null) _normalize(labelEl.text).toLowerCase(),
    }..removeWhere((k) => k.isEmpty);

    for (final k in keys) {
      out.putIfAbsent(k, () => value);
    }
  }
  return out;
}

List<String> _extractSpecialQualities(Map<String, String> fields) {
  final raw = fields['special qualities'] ??
      fields['specialqualities'] ??
      fields['special'] ??
      fields['qualities'];
  if (raw == null || raw.isEmpty) return const [];
  return raw
      .split(RegExp(r',|;|\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

String? _extractLeadParagraph(Document doc, Element infobox) {
  final container = doc.querySelector('.mw-parser-output');
  if (container == null) return null;
  for (final p in container.querySelectorAll('p')) {
    if (_isInside(p, infobox)) continue;
    final paragraphs = htmlToParagraphs(p.outerHtml);
    if (paragraphs.isEmpty) continue;
    final text = paragraphs.first;
    if (text.length < 20) continue;
    return text;
  }
  return null;
}

bool _isInside(Element node, Element ancestor) {
  Element? cur = node.parent;
  while (cur != null) {
    if (cur == ancestor) return true;
    cur = cur.parent;
  }
  return false;
}

String _normalize(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

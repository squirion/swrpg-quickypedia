import 'package:html/dom.dart';
import 'package:swrpg_quickypedia/models/beast.dart';
import 'package:swrpg_quickypedia/utils/html_utils.dart';

/// Parse a single beast page on the SWRPG FFG Fandom wiki.
///
/// Beasts have two `<img alt>` blocks:
///   1. Commerce: `Encumbrance - Price 2,500 Rarity 1` (Encumbrance is
///      usually `-` since beasts aren't items you carry).
///   2. Creature: `Brawn 5 Agility 1 Intellect 1 Cunning 1 Willpower 1
///      Presence 1 Soak Value 10 Wound Threshold 26 Melee Defense 0
///      Ranged Defense 0`
///
/// The post-stat paragraph carries `Skills:`, `Talents:`, `Abilities:`,
/// `Equipment:` — each kept as a single raw string so the detail view
/// can render the parenthetical descriptions intact.
///
/// `Silhouette N` is conventionally embedded inside the Abilities text
/// and is pulled out with a separate regex when present.
Beast? parseBeastPage(Document doc, String sourceUrl) {
  final name = _extractTitle(doc);
  if (name == null || name.isEmpty) return null;

  final (commerceImg, creatureImg) = _findStatImages(doc);
  // Need at least the creature alt to recognize this as a beast page.
  if (creatureImg == null) return null;

  final commerce = commerceImg == null
      ? const <String, String>{}
      : _parseAltStats(commerceImg.attributes['alt'] ?? '', _commerceTokens);
  final creature = _parseAltStats(
      creatureImg.attributes['alt'] ?? '', _creatureTokens);

  // The "anchor" for post-stat text extraction: use whichever stat
  // image came LATER in document order, since beast pages typically
  // emit commerce-alt first and creature-alt second.
  final anchorImg = creatureImg;

  final pageText = _collectPostStatText(doc, anchorImg);
  final (description, mechanics) =
      _extractDescriptionAndMechanics(doc, anchorImg);

  final abilitiesText = _extractField(pageText, 'Abilities');
  final silhouetteFromAbilities = abilitiesText == null
      ? null
      : RegExp(r'\bSilhouette\s+(\d+)').firstMatch(abilitiesText)?.group(1);

  return Beast(
    name: name,
    encumbrance: _normalizeValue(commerce['encumbrance']),
    price: _normalizeValue(commerce['price']),
    rarity: _normalizeValue(commerce['rarity']),
    brawn: _normalizeValue(creature['brawn']),
    agility: _normalizeValue(creature['agility']),
    intellect: _normalizeValue(creature['intellect']),
    cunning: _normalizeValue(creature['cunning']),
    willpower: _normalizeValue(creature['willpower']),
    presence: _normalizeValue(creature['presence']),
    soak: _normalizeValue(creature['soak value']),
    woundThreshold: _normalizeValue(creature['wound threshold']),
    meleeDefense: _normalizeValue(creature['melee defense']),
    rangedDefense: _normalizeValue(creature['ranged defense']),
    skills: _extractSkills(pageText),
    talents: _extractField(pageText, 'Talents'),
    abilities: abilitiesText,
    equipment: _extractEquipment(pageText),
    silhouette: silhouetteFromAbilities,
    description: description,
    mechanics: mechanics,
    sourceUrl: sourceUrl,
    imageUrl: null,
    category: null,
  );
}

String? _extractTitle(Document doc) {
  final header = doc.querySelector('h1.page-header__title');
  final raw = header?.text ?? doc.querySelector('title')?.text;
  if (raw == null) return null;
  final cleaned = raw.split('|').first.trim();
  return cleaned.isEmpty ? null : cleaned;
}

/// Walk every <img> and identify the commerce + creature alt blocks.
/// Commerce alt contains `Encumbrance ` AND `Price `; creature alt
/// contains `Brawn ` AND `Wound Threshold `. Either may be absent (some
/// wild creatures lack a price).
(Element?, Element?) _findStatImages(Document doc) {
  Element? commerce;
  Element? creature;
  for (final img in doc.querySelectorAll('img')) {
    final alt = img.attributes['alt'];
    if (alt == null || alt.length < 12) continue;
    if (creature == null &&
        alt.contains('Brawn ') &&
        alt.contains('Wound Threshold ')) {
      creature = img;
    }
    if (commerce == null &&
        alt.contains('Encumbrance ') &&
        alt.contains('Price ') &&
        !alt.contains('Brawn ')) {
      commerce = img;
    }
    if (commerce != null && creature != null) break;
  }
  return (commerce, creature);
}

// Tokens for the commerce alt. Same shape as gear.
const _commerceTokens = ['Encumbrance', 'Price', 'Rarity'];
// Tokens for the creature alt. Longer phrases first so e.g.
// `Soak Value` matches before `Soak` could.
const _creatureTokens = [
  'Soak Value',
  'Wound Threshold',
  'Melee Defense',
  'Ranged Defense',
  'Brawn',
  'Agility',
  'Intellect',
  'Cunning',
  'Willpower',
  'Presence',
];

Map<String, String> _parseAltStats(String alt, List<String> tokens) {
  if (alt.isEmpty || tokens.isEmpty) return const {};
  final pattern = RegExp(
    '\\b(${tokens.map(RegExp.escape).join('|')})\\b',
  );
  final matches = pattern.allMatches(alt).toList();
  final out = <String, String>{};
  for (var i = 0; i < matches.length; i++) {
    final key = matches[i].group(1)!.toLowerCase();
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : alt.length;
    final value = alt.substring(start, end).trim();
    if (value.isEmpty) continue;
    out.putIfAbsent(key, () => value);
  }
  return out;
}

String? _normalizeValue(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed == '-' || trimmed == '—' || trimmed == 'N/A') return null;
  return trimmed;
}

/// Collect every <p> AFTER the anchor image, joined with single
/// spaces. The wiki packs Skills/Talents/Abilities/Equipment into one
/// long sentence-separated paragraph.
String _collectPostStatText(Document doc, Element anchorImg) {
  final container = doc.querySelector('.mw-parser-output');
  if (container == null) return '';
  final anchorParent = _enclosingParagraph(anchorImg) ?? anchorImg;
  final paragraphs = container.querySelectorAll('p');
  final anchorIndex = paragraphs.indexWhere((p) =>
      p == anchorParent || p.querySelectorAll('img').contains(anchorImg));
  if (anchorIndex < 0) return '';
  final buf = StringBuffer();
  for (final p in paragraphs.skip(anchorIndex + 1)) {
    if (_isInsideBlockquote(p)) continue;
    buf.write(p.text);
    buf.write(' ');
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Extract a labeled field value. Captures everything between
/// `Label: ` and the next sentence boundary that introduces another
/// labeled field, falling back to end-of-string.
String? _extractField(String text, String label) {
  if (text.isEmpty) return null;
  final escaped = RegExp.escape(label);
  // Match the label, allow paren-suffixes like `Skills (group only)`,
  // then capture greedily until the next `Label:` boundary or end.
  // Beast field values contain nested parens with periods/colons, so
  // the simple "stop at next period" heuristic from vehicles is too
  // aggressive — use the explicit "next labeled field starts here"
  // termination instead.
  final m = RegExp(
    '\\b$escaped(?:\\s*\\([^)]*\\))?:\\s+(.*?)'
    r'(?=\s+(?:Skills|Talents|Abilities|Equipment)(?:\s*\([^)]*\))?:|$)',
    dotAll: true,
  ).firstMatch(text);
  if (m == null) return null;
  var value = m.group(1)?.trim() ?? '';
  // Trim a trailing period that belongs to the field's sentence
  // boundary rather than to a parenthetical inside the value.
  if (value.endsWith('.') &&
      !value.endsWith(').') &&
      !value.endsWith(']..')) {
    value = value.substring(0, value.length - 1).trim();
  }
  return _normalizeValue(value);
}

/// Specialized: also detects `Skills (group only):` and `Skills
/// (some-other-modifier):`. The base [_extractField] already handles
/// this via the optional `(...)` group; this wrapper just keeps the
/// call site readable.
String? _extractSkills(String text) => _extractField(text, 'Skills');

/// Specialized: Equipment values can include sub-period sentences like
/// "Toothy jaws (Brawl; Damage 3; …). Some sub-species also have …",
/// so the generic `next labeled field` boundary is what we want.
String? _extractEquipment(String text) => _extractField(text, 'Equipment');

(String?, String?) _extractDescriptionAndMechanics(
  Document doc,
  Element anchorImg,
) {
  final container = doc.querySelector('.mw-parser-output');
  if (container == null) return (null, null);

  final anchorParent = _enclosingParagraph(anchorImg) ?? anchorImg;
  final paragraphs = container.querySelectorAll('p');
  if (paragraphs.isEmpty) return (null, null);

  final anchorIndex = paragraphs.indexWhere((p) =>
      p == anchorParent || p.querySelectorAll('img').contains(anchorImg));
  if (anchorIndex < 0) return (null, null);

  String? joinProse(Iterable<Element> ps) {
    final chunks = <String>[];
    for (final p in ps) {
      if (_isInsideBlockquote(p)) continue;
      if (p.querySelector('img') != null) continue;
      final lines = htmlToParagraphs(p.outerHtml);
      if (lines.isEmpty) continue;
      final txt = _stripCitations(lines.first);
      if (txt.length < 20) continue;
      if (_looksLikeModelsList(txt)) continue;
      // Skip the labeled-fields paragraph and the canned Wookieepedia
      // link blurb that almost every beast page starts with.
      if (_looksLikeBeastSpecs(txt)) continue;
      if (_looksLikeWookieeBlurb(txt)) continue;
      chunks.add(txt);
    }
    if (chunks.isEmpty) return null;
    return chunks.join('\n\n');
  }

  final description = joinProse(paragraphs.take(anchorIndex));
  final mechanics = joinProse(paragraphs.skip(anchorIndex + 1));
  return (description, mechanics);
}

bool _looksLikeBeastSpecs(String text) {
  return RegExp(r'^Skills(\s*\([^)]+\))?:', caseSensitive: false)
      .hasMatch(text);
}

bool _looksLikeWookieeBlurb(String text) {
  return text.toLowerCase().contains('information about') &&
      text.toLowerCase().contains('wookieepedia');
}

Element? _enclosingParagraph(Element el) {
  Element? cur = el.parent;
  while (cur != null) {
    if (cur.localName == 'p') return cur;
    cur = cur.parent;
  }
  return null;
}

bool _isInsideBlockquote(Element el) {
  Element? cur = el.parent;
  while (cur != null) {
    if (cur.localName == 'blockquote') return true;
    cur = cur.parent;
  }
  return false;
}

bool _looksLikeModelsList(String text) =>
    RegExp(r'^Models? Includes?\s*:', caseSensitive: false).hasMatch(text);

String _stripCitations(String text) =>
    text.replaceAll(RegExp(r'\s*\[\d+\]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

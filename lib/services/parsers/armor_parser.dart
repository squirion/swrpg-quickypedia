import 'package:html/dom.dart';
import 'package:swrpg_quickypedia/models/armor.dart';
import 'package:swrpg_quickypedia/utils/html_utils.dart';

/// Parse a single armor page on the SWRPG FFG Fandom wiki.
///
/// Like weapons, armor pages encode their stat block as the `alt`
/// attribute of the profile image, e.g.:
/// ```
/// alt="Defense 0 Soak 2 Encumbrance 3 Hard Points 0 \
///      Price 500 Rarity 5 Special Cumbersome 2"
/// ```
/// We split on a fixed list of armor stat keywords and zip the pairs
/// into an [Armor]. Pages without a usable alt block (overview pages,
/// redirects, …) return `null` so junk doesn't land in storage.
///
/// `category` is intentionally left null here — the scraper sets it
/// once it knows which subcategory page the armor was discovered on.
Armor? parseArmorPage(Document doc, String sourceUrl) {
  final name = _extractTitle(doc);
  if (name == null || name.isEmpty) return null;

  final statImg = _findStatImage(doc);
  if (statImg == null) return null;

  final altStats = statImg.attributes['alt'];
  if (altStats == null) return null;

  final fields = _parseAltStats(altStats);
  if (fields.isEmpty) return null;

  final (description, mechanics) = _extractDescriptionAndMechanics(doc, statImg);

  return Armor(
    name: name,
    soak: _normalizeValue(fields['soak']),
    defense: _normalizeValue(fields['defense']),
    encumbrance: _normalizeValue(fields['encumbrance']),
    hardpoints: _normalizeValue(fields['hard points']),
    price: _normalizeValue(fields['price']),
    rarity: _normalizeValue(fields['rarity']),
    specialQualities: _splitSpecial(fields['special']),
    description: description,
    mechanics: mechanics,
    sourceUrl: sourceUrl,
    // Fandom images aren't usable for armor either — same as weapons,
    // an upload flow on the detail screen fills this in later.
    imageUrl: null,
    // Set by the scraper after discovery.
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

/// Walk every <img> on the page and return the first one whose `alt`
/// looks like an armor stat block (must contain both Soak and Defense
/// so decoration / icon images aren't picked up by accident).
Element? _findStatImage(Document doc) {
  for (final img in doc.querySelectorAll('img')) {
    final alt = img.attributes['alt'];
    if (alt == null || alt.length < 20) continue;
    if (!alt.contains('Soak ')) continue;
    if (!alt.contains('Defense ')) continue;
    return img;
  }
  return null;
}

/// "Defense 0 Soak 2 Encumbrance 3 Hard Points 1 Price 500 Rarity 5" →
/// `{defense: "0", soak: "2", encumbrance: "3", …}`.
///
/// Splits on the known stat keywords. No keyword in this set is a
/// prefix of another, so order doesn't matter (unlike weapons where
/// "Critical Rating" had to be matched before "Critical").
Map<String, String> _parseAltStats(String alt) {
  final pattern = RegExp(
    r'\b(Soak|Defense|Encumbrance|Price|Rarity|Hard Points|Special)\b',
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

/// Treat "-" and "—" (used for N/A) as null.
String? _normalizeValue(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed == '-' || trimmed == '—' || trimmed == 'N/A') return null;
  return trimmed;
}

List<String> _splitSpecial(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  final cleaned = raw.trim();
  if (cleaned == '-' || cleaned == '—') return const [];
  return cleaned
      .split(RegExp(r',|;'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// Splits the page's prose into the `description` (before the stat
/// image) and `mechanics` (after the stat image). Same wiki convention
/// as the weapon parser; the helper is duplicated here so the two
/// parsers stay independent.
(String?, String?) _extractDescriptionAndMechanics(
  Document doc,
  Element statImg,
) {
  final container = doc.querySelector('.mw-parser-output');
  if (container == null) return (null, null);

  final statParent = _enclosingParagraph(statImg) ?? statImg;
  final paragraphs = container.querySelectorAll('p');
  if (paragraphs.isEmpty) return (null, null);

  final statIndex = paragraphs.indexWhere((p) =>
      p == statParent || p.querySelectorAll('img').contains(statImg));
  if (statIndex < 0) return (null, null);

  String? joinProse(Iterable<Element> ps) {
    final chunks = <String>[];
    for (final p in ps) {
      if (_isInsideBlockquote(p)) continue;
      if (p.querySelector('img') != null) continue;
      final lines = htmlToParagraphs(p.outerHtml);
      if (lines.isEmpty) continue;
      final text = _stripCitations(lines.first);
      if (text.length < 20) continue;
      if (_looksLikeModelsList(text)) continue;
      chunks.add(text);
    }
    if (chunks.isEmpty) return null;
    return chunks.join('\n\n');
  }

  final description = joinProse(paragraphs.take(statIndex));
  final mechanics = joinProse(paragraphs.skip(statIndex + 1));
  return (description, mechanics);
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

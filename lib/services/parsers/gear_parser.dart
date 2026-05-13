import 'package:html/dom.dart';
import 'package:swrpg_quickypedia/models/gear.dart';
import 'package:swrpg_quickypedia/utils/html_utils.dart';

/// Parse a single gear page on the SWRPG FFG Fandom wiki.
///
/// Gear pages encode their stat block as the `alt` of the profile
/// image — e.g. `alt="Encumbrance 2 Price 400 Rarity 2"` — same
/// convention as weapons and armor.
///
/// `category` is left null; the scraper tags it after discovery.
Gear? parseGearPage(Document doc, String sourceUrl) {
  final name = _extractTitle(doc);
  if (name == null || name.isEmpty) return null;

  final statImg = _findStatImage(doc);
  if (statImg == null) return null;

  final altStats = statImg.attributes['alt'];
  if (altStats == null) return null;

  final fields = _parseAltStats(altStats);
  if (fields.isEmpty) return null;

  final (description, mechanics) = _extractDescriptionAndMechanics(doc, statImg);

  return Gear(
    name: name,
    price: _normalizeValue(fields['price']),
    encumbrance: _normalizeValue(fields['encumbrance']),
    rarity: _normalizeValue(fields['rarity']),
    specialQualities: _splitSpecial(fields['special']),
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

/// Walk every <img> on the page. Gear's universal markers are
/// Encumbrance + Price — they appear on every gear page, with or
/// without rarity and special qualities.
Element? _findStatImage(Document doc) {
  for (final img in doc.querySelectorAll('img')) {
    final alt = img.attributes['alt'];
    if (alt == null || alt.length < 12) continue;
    if (!alt.contains('Encumbrance ')) continue;
    if (!alt.contains('Price ')) continue;
    return img;
  }
  return null;
}

Map<String, String> _parseAltStats(String alt) {
  final pattern = RegExp(r'\b(Price|Encumbrance|Rarity|Special)\b');
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

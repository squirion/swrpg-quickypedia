import 'package:html/dom.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/utils/html_utils.dart';

/// Parse a single weapon page on the SWRPG FFG Fandom wiki.
///
/// The wiki doesn't use Fandom's portable-infobox template for this set
/// of pages — instead, the entire stat block is encoded as the `alt`
/// attribute of the weapon's profile image, e.g.:
/// ```
/// alt="Skill Ranged (Light) Range Medium Encumbrance 2 Price 700 \
///      Rarity 6 Damage 7 Critical Rating 3 Hard Points 3 \
///      Special Stun setting"
/// ```
/// We split that text on a fixed list of known stat keywords and zip the
/// pairs into a [Weapon]. Pages whose images don't carry such alt text
/// (overview pages, redirects, …) return `null` so they aren't persisted.
Weapon? parseWeaponPage(Document doc, String sourceUrl) {
  final name = _extractTitle(doc);
  if (name == null || name.isEmpty) return null;

  final statImg = _findStatImage(doc);
  if (statImg == null) return null;

  final altStats = statImg.attributes['alt'];
  if (altStats == null) return null;

  final fields = _parseAltStats(altStats);
  if (fields.isEmpty) return null;

  final (description, mechanics) = _extractDescriptionAndMechanics(doc, statImg);

  return Weapon(
    name: name,
    skill: fields['skill'],
    damage: _normalizeValue(fields['damage']),
    critical: _normalizeValue(fields['critical rating'] ?? fields['critical']),
    range: fields['range'],
    encumbrance: _normalizeValue(fields['encumbrance']),
    hardpoints: _normalizeValue(fields['hard points']),
    price: _normalizeValue(fields['price']),
    rarity: _normalizeValue(fields['rarity']),
    specialQualities: _splitSpecial(fields['special']),
    description: description,
    mechanics: mechanics,
    sourceUrl: sourceUrl,
    // imageUrl intentionally null: Fandom rarely has a usable photo (most
    // pages embed a re-render of the stat block image). A future fetcher
    // will populate this from another source.
    imageUrl: null,
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
/// looks like a weapon stat block (must contain at least Skill and
/// Damage so we don't false-positive on icons / decorations). The
/// same element carries the stat alt text AND the image URL, so the
/// caller can pull both off it.
Element? _findStatImage(Document doc) {
  for (final img in doc.querySelectorAll('img')) {
    final alt = img.attributes['alt'];
    if (alt == null || alt.length < 20) continue;
    if (!alt.contains('Skill ')) continue;
    if (!alt.contains('Damage ')) continue;
    return img;
  }
  return null;
}

/// "Skill Ranged (Light) Range Medium Encumbrance 2 …" →
/// `{skill: "Ranged (Light)", range: "Medium", encumbrance: "2", …}`.
///
/// Splits on the known stat keywords. `Critical Rating` is matched
/// before plain `Critical` so we don't truncate it.
Map<String, String> _parseAltStats(String alt) {
  final pattern = RegExp(
    r'\b(Skill|Range|Encumbrance|Price|Rarity|Damage|Critical Rating|Critical|Hard Points|Special)\b',
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

/// Treat "-" and "—" (sometimes used for N/A) as null. The wiki also
/// uses these for fields that don't apply to a given weapon class
/// (e.g. Hard Points on natural weapons).
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

/// Splits the page's prose into the `description` (before the stat image)
/// and `mechanics` (after the stat image). The wiki convention is:
///   1. narrative description paragraph(s)
///   2. optional "Models Include:" line — skipped, it's not prose
///   3. h2 with the weapon's name in caps
///   4. <p><img></p> with the stat block image
///   5. game-mechanics paragraph(s)
/// Citation markers like `[1]` are stripped. Paragraphs are joined with
/// a blank line so the UI can re-split them for paragraph spacing.
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

/// "Models Include: BlasTech DT-57…" appears on many wiki pages as a
/// manufacturer/model list. It's not narrative description and not game
/// mechanics, so we drop it from both buckets.
bool _looksLikeModelsList(String text) =>
    RegExp(r'^Models? Includes?\s*:', caseSensitive: false).hasMatch(text);

/// Strip inline `[1]` / `[2]` citation markers that the wiki injects.
String _stripCitations(String text) =>
    text.replaceAll(RegExp(r'\s*\[\d+\]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

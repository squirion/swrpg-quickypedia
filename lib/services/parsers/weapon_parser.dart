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
    description: _extractLeadParagraph(doc),
    sourceUrl: sourceUrl,
    imageUrl: _cleanImageUrl(statImg.attributes['src']),
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

/// Trim the Fandom cache-buster query off image URLs so the same image
/// across revisions has a stable cache key. Returns `null` for empty
/// or lazy-load placeholders (Fandom sometimes serves `data:image/gif…`
/// inline placeholders and the real URL only in `data-src`).
String? _cleanImageUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('data:')) return null;
  return trimmed;
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

String? _extractLeadParagraph(Document doc) {
  final container = doc.querySelector('.mw-parser-output');
  if (container == null) return null;
  for (final p in container.querySelectorAll('p')) {
    final paragraphs = htmlToParagraphs(p.outerHtml);
    if (paragraphs.isEmpty) continue;
    final text = _stripCitations(paragraphs.first);
    if (text.length < 20) continue;
    return text;
  }
  return null;
}

/// Strip inline `[1]` / `[2]` citation markers that the wiki injects.
String _stripCitations(String text) =>
    text.replaceAll(RegExp(r'\s*\[\d+\]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

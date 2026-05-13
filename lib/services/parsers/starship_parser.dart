import 'package:html/dom.dart';
import 'package:swrpg_quickypedia/models/starship.dart';
import 'package:swrpg_quickypedia/utils/html_utils.dart';

/// Parse a single starship page on the SWRPG FFG Fandom wiki.
///
/// Starship stat-image alt is identical to the vehicle alt
/// (Silhouette / Speed / Handling / 4-zone Defense / Armor / Hull
/// Trauma Threshold / System Strain Threshold). The post-stat text
/// paragraph adds Hull Type/Class, Manufacturer, Hyperdrive,
/// Navicomputer, Sensor Range, Ship's Complement, Encumbrance Capacity,
/// Passenger Capacity, Consumables, Price/Rarity, Customization Hard
/// Points, Weapons.
Starship? parseStarshipPage(Document doc, String sourceUrl) {
  final name = _extractTitle(doc);
  if (name == null || name.isEmpty) return null;

  final statImg = _findStatImage(doc);
  if (statImg == null) return null;

  final altStats = statImg.attributes['alt'];
  if (altStats == null) return null;

  final alt = _parseAltStats(altStats);
  if (alt.isEmpty) return null;

  final (fore, port, starboard, aft) = _splitDefense(alt['defense']);

  final pageText = _collectPostStatText(doc, statImg);
  final priceRarity = _extractPriceRarity(pageText);

  final (description, mechanics) = _extractDescriptionAndMechanics(doc, statImg);

  return Starship(
    name: name,
    silhouette: _normalizeValue(alt['silhouette']),
    speed: _normalizeValue(alt['speed']),
    handling: _normalizeValue(alt['handling']),
    defenseFore: fore,
    defensePort: port,
    defenseStarboard: starboard,
    defenseAft: aft,
    armor: _normalizeValue(alt['armor']),
    hullTrauma: _normalizeValue(alt['hull trauma threshold']),
    systemStrain: _normalizeValue(alt['system strain threshold']),
    hullTypeClass: _extractField(pageText, 'Hull Type/Class'),
    manufacturer: _extractField(pageText, 'Manufacturer'),
    hyperdrive: _extractField(pageText, 'Hyperdrive'),
    navicomputer: _extractField(pageText, 'Navicomputer'),
    sensorRange: _extractField(pageText, 'Sensor Range'),
    shipsComplement: _extractField(pageText, "Ship's Complement") ??
        _extractField(pageText, 'Ships Complement'),
    encumbranceCapacity:
        _extractField(pageText, 'Encumbrance Capacity'),
    passengerCapacity: _extractField(pageText, 'Passenger Capacity'),
    consumables: _extractField(pageText, 'Consumables'),
    hardpoints: _extractHardpoints(pageText),
    weapons: _extractWeapons(pageText),
    price: priceRarity.$1,
    rarity: priceRarity.$2,
    specialQualities: _splitSpecial(alt['special']),
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

/// Starship stat image's alt must contain `Silhouette ` AND
/// `Hull Trauma `. Same heuristic as vehicles.
Element? _findStatImage(Document doc) {
  for (final img in doc.querySelectorAll('img')) {
    final alt = img.attributes['alt'];
    if (alt == null || alt.length < 20) continue;
    if (!alt.contains('Silhouette ')) continue;
    if (!alt.contains('Hull Trauma ')) continue;
    return img;
  }
  return null;
}

Map<String, String> _parseAltStats(String alt) {
  final pattern = RegExp(
    r'\b(Hull Trauma Threshold|System Strain Threshold|Silhouette|Speed|Handling|Defense|Armor|Special)\b',
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

(String?, String?, String?, String?) _splitDefense(String? raw) {
  if (raw == null) return (null, null, null, null);
  final cleaned = raw
      .replaceAll(RegExp(r'\(Fore/Port/Starboard/Aft\)', caseSensitive: false), '')
      .trim();
  final slashMatch =
      RegExp(r'(\d+|-)\s*/\s*(\d+|-)\s*/\s*(\d+|-)\s*/\s*(\d+|-)')
          .firstMatch(cleaned);
  if (slashMatch != null) {
    return (
      _zoneOrNull(slashMatch.group(1)),
      _zoneOrNull(slashMatch.group(2)),
      _zoneOrNull(slashMatch.group(3)),
      _zoneOrNull(slashMatch.group(4)),
    );
  }
  final single = RegExp(r'\d+').firstMatch(cleaned);
  if (single != null) return (single.group(0), null, null, null);
  return (null, null, null, null);
}

String? _zoneOrNull(String? raw) {
  if (raw == null) return null;
  if (raw == '-' || raw == '–') return null;
  return raw;
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

String _collectPostStatText(Document doc, Element statImg) {
  final container = doc.querySelector('.mw-parser-output');
  if (container == null) return '';
  final statParent = _enclosingParagraph(statImg) ?? statImg;
  final paragraphs = container.querySelectorAll('p');
  final statIndex = paragraphs.indexWhere((p) =>
      p == statParent || p.querySelectorAll('img').contains(statImg));
  if (statIndex < 0) return '';
  final buf = StringBuffer();
  for (final p in paragraphs.skip(statIndex + 1)) {
    if (_isInsideBlockquote(p)) continue;
    buf.write(p.text);
    buf.write('\n');
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _extractField(String text, String label) {
  if (text.isEmpty) return null;
  final escaped = RegExp.escape(label);
  final m = RegExp('\\b$escaped:\\s+([^.]+?)(?:\\.\\s|\\.\$|\$)')
      .firstMatch(text);
  if (m == null) return null;
  return _normalizeValue(m.group(1));
}

String? _extractHardpoints(String text) {
  return _extractField(text, 'Customization Hard Points') ??
      _extractField(text, 'Hard Points');
}

(String?, String?) _extractPriceRarity(String text) {
  final raw = _extractField(text, 'Price/Rarity');
  if (raw == null) return (null, null);
  final lastSlash = raw.lastIndexOf('/');
  if (lastSlash < 0) return (raw, null);
  return (
    _normalizeValue(raw.substring(0, lastSlash)),
    _normalizeValue(raw.substring(lastSlash + 1)),
  );
}

String? _extractWeapons(String text) {
  if (text.isEmpty) return null;
  final m = RegExp(
    r'\bWeapons:\s+(.*?)(?:\.\s+(?:Modifications:|Notes:|Other comments?:|Special:|Hyperdrive:)|$)',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final raw = m.group(1)?.trim();
  if (raw == null || raw.isEmpty) return null;
  return raw;
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
      final txt = _stripCitations(lines.first);
      if (txt.length < 20) continue;
      if (_looksLikeModelsList(txt)) continue;
      if (_looksLikeTransportSpecs(txt)) continue;
      chunks.add(txt);
    }
    if (chunks.isEmpty) return null;
    return chunks.join('\n\n');
  }

  final description = joinProse(paragraphs.take(statIndex));
  final mechanics = joinProse(paragraphs.skip(statIndex + 1));
  return (description, mechanics);
}

bool _looksLikeTransportSpecs(String text) {
  return RegExp(
          r'^(Hull Type/Class|Manufacturer|Hyperdrive|Navicomputer|Sensor Range|Ship.s Complement|Encumbrance Capacity):',
          caseSensitive: false)
      .hasMatch(text);
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

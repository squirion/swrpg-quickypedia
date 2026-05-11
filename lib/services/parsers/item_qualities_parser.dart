import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:swrpg_quickypedia/models/item_quality.dart';
import 'package:swrpg_quickypedia/utils/html_utils.dart';

const String kItemQualitiesUrl =
    'https://star-wars-rpg-ffg.fandom.com/wiki/Item_Qualities';

const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

/// Fetches and parses the Item Qualities glossary page.
///
/// Unlike the weapons scraper, this page is a single document — one HTTP
/// request, then we walk the parser-output children: each `<h3>` (and
/// any nested `<h4>` like "Stun Setting") introduces a quality, and the
/// paragraphs between this heading and the next heading form its
/// description.
Future<List<ItemQuality>> fetchItemQualities({http.Client? client}) async {
  final httpClient = client ?? http.Client();
  try {
    final resp = await httpClient.get(
      Uri.parse(kItemQualitiesUrl),
      headers: const {'User-Agent': _userAgent},
    );
    if (resp.statusCode != 200) {
      throw http.ClientException(
        'GET $kItemQualitiesUrl returned ${resp.statusCode}',
        Uri.parse(kItemQualitiesUrl),
      );
    }
    return parseItemQualitiesDocument(html_parser.parse(resp.body));
  } finally {
    if (client == null) httpClient.close();
  }
}

/// Public so tests / debugging can feed in a captured HTML document.
List<ItemQuality> parseItemQualitiesDocument(Document doc) {
  final container = doc.querySelector('.mw-parser-output');
  if (container == null) return const [];

  final qualities = <ItemQuality>[];
  String? currentName;
  String? currentKind;
  final paragraphs = <String>[];

  void flush() {
    if (currentName == null) return;
    final desc = paragraphs.join('\n\n').trim();
    if (desc.isEmpty) {
      paragraphs.clear();
      currentName = null;
      currentKind = null;
      return;
    }
    qualities.add(ItemQuality(
      name: currentName!,
      kind: currentKind,
      description: desc,
    ));
    paragraphs.clear();
    currentName = null;
    currentKind = null;
  }

  // Walk only direct children so we don't descend into infoboxes or TOC.
  for (final node in container.children) {
    final tag = node.localName?.toLowerCase();
    if (tag == 'h3' || tag == 'h4') {
      flush();
      final headline = node.querySelector('.mw-headline');
      final raw = (headline?.text ?? node.text).trim();
      final (name, kind) = _splitHeading(raw);
      if (name.isEmpty) continue;
      currentName = name;
      currentKind = kind;
    } else if (tag == 'p' && currentName != null) {
      final lines = htmlToParagraphs(node.outerHtml);
      if (lines.isEmpty) continue;
      final text = _stripCitations(lines.first);
      if (text.isEmpty) continue;
      paragraphs.add(text);
    } else if (tag == 'h2') {
      // Switching top-level section (e.g. footer references) — stop.
      flush();
      break;
    }
  }
  flush();
  return qualities;
}

/// "Pierce (Passive)" → ("Pierce", "passive").
/// "Stun Setting (Active)" → ("Stun Setting", "active").
/// "Some Quality" → ("Some Quality", null).
(String, String?) _splitHeading(String raw) {
  final m = RegExp(r'^(.*?)\s*\((active|passive)\)\s*$',
          caseSensitive: false)
      .firstMatch(raw);
  if (m == null) return (raw, null);
  return (m.group(1)!.trim(), m.group(2)!.toLowerCase());
}

String _stripCitations(String text) =>
    text.replaceAll(RegExp(r'\s*\[\d+\]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

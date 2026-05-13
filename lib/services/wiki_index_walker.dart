import 'package:swrpg_quickypedia/services/wiki_scraper.dart';

/// Walks a Fandom article body and groups its inline `/wiki/...` links
/// by the H2/H3 section header they appear under.
///
/// Several SWRPG categories on the wiki (Armor, Gear, Vehicles) use
/// hand-written index pages — armors aren't actually subcategories of
/// `Category:Armor`; they're listed under section headers like `LIGHT`,
/// `HEAVY`, `BEAST_ARMOR_.26_EQUIPMENT` inside the article body. This
/// helper handles that pattern in one place so each per-category scrape
/// notifier only has to provide its index URL and a section-id → bucket
/// map.
///
/// Returns a `pageUrl → bucketLabel` map. `pageUrl` is absolute. Links
/// outside any tracked section are skipped; the first bucket a link
/// appears under wins (matches what the user wants for armor: an item
/// listed under two sections gets the first one).
Future<Map<String, String>> discoverByArticleHeaders({
  required WikiScraper scraper,
  required String indexUrl,
  required Map<String, String> sectionToBucket,
}) async {
  final doc = await scraper.fetchDocument(indexUrl);
  final article = doc.querySelector('.mw-parser-output');
  if (article == null) return const {};

  final out = <String, String>{};
  String? currentBucket;
  final origin = Uri.parse(indexUrl).origin;

  void visit(dynamic node) {
    final tag = node.localName as String?;
    if (tag == 'h1' || tag == 'h2' || tag == 'h3' || tag == 'h4') {
      // Anchor ID lives on the heading itself or on an inline span
      // with an id (MediaWiki convention varies by skin).
      final id = (node.attributes['id'] as String?) ??
          node.querySelector('[id]')?.attributes['id'];
      currentBucket = id == null ? null : sectionToBucket[id];
      return;
    }
    if (tag == 'a') {
      final href = node.attributes['href'] as String?;
      if (href != null &&
          href.startsWith('/wiki/') &&
          // Skip Category:/File:/Template:/etc. namespaces.
          !href.contains(':') &&
          currentBucket != null) {
        final url = '$origin$href';
        out.putIfAbsent(url, () => currentBucket!);
      }
      return;
    }
    for (final c in node.children) {
      visit(c);
    }
  }

  for (final c in article.children) {
    visit(c);
  }
  return out;
}

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Generic crawler for Fandom (`*.fandom.com`) Category pages.
///
/// Given a category URL and a per-item parser, [scrapeCategory] walks every
/// member page (across all pagination pages) and returns the non-null parse
/// results. The same scraper is reused for every system-dependent category
/// (weapons, armor, gear, vehicles, …) — only the parser callback changes.
class WikiScraper {
  /// Fandom returns 403 to clients with no User-Agent. A standard desktop UA
  /// is enough to be served the same HTML a browser would get.
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  final http.Client _client;

  WikiScraper({http.Client? client}) : _client = client ?? http.Client();

  /// Walk the category and parse each member page.
  ///
  /// [parser] receives the parsed HTML document and the full URL it was
  /// fetched from, and returns either a parsed item or `null` to skip.
  /// [onProgress] is called as `(done, total)` after each member page is
  /// processed — `total` is only known after pagination completes, so the
  /// first call comes after the index walk.
  Future<List<T>> scrapeCategory<T>({
    required String categoryUrl,
    required T? Function(Document doc, String sourceUrl) parser,
    void Function(int done, int total)? onProgress,
  }) async {
    final memberUrls = await _collectMemberUrls(categoryUrl);
    final total = memberUrls.length;
    onProgress?.call(0, total);

    final results = <T>[];
    for (var i = 0; i < memberUrls.length; i++) {
      final url = memberUrls[i];
      try {
        final doc = await _fetchDocument(url);
        final parsed = parser(doc, url);
        if (parsed != null) results.add(parsed);
      } catch (_) {
        // Individual page failures don't abort the whole scrape — skip and
        // continue. The grid will simply show the items that did parse.
      }
      onProgress?.call(i + 1, total);
    }
    return results;
  }

  Future<List<String>> _collectMemberUrls(String firstPageUrl) async {
    final urls = <String>[];
    final seen = <String>{};
    var nextUrl = firstPageUrl;
    final origin = Uri.parse(firstPageUrl).origin;

    while (true) {
      final doc = await _fetchDocument(nextUrl);

      for (final a in doc.querySelectorAll('a.category-page__member-link')) {
        final href = a.attributes['href'];
        if (href == null || href.isEmpty) continue;
        final resolved =
            href.startsWith('http') ? href : '$origin$href';
        if (seen.add(resolved)) urls.add(resolved);
      }

      final next = doc.querySelector('a.category-page__pagination-next');
      final nextHref = next?.attributes['href'];
      if (nextHref == null || nextHref.isEmpty) break;
      final resolvedNext =
          nextHref.startsWith('http') ? nextHref : '$origin$nextHref';
      if (resolvedNext == nextUrl) break;
      nextUrl = resolvedNext;
    }
    return urls;
  }

  /// Fetch and parse a single page. Public so caller-side scrapers
  /// (e.g. the armor scraper, which extracts its index from a hand-
  /// written wiki page rather than the auto-generated category) can
  /// reuse the same UA-spoofed client.
  Future<Document> fetchDocument(String url) => _fetchDocument(url);

  Future<Document> _fetchDocument(String url) async {
    final resp = await _client.get(
      Uri.parse(url),
      headers: const {'User-Agent': _userAgent},
    );
    if (resp.statusCode != 200) {
      throw http.ClientException(
        'GET $url returned ${resp.statusCode}',
        Uri.parse(url),
      );
    }
    return html_parser.parse(resp.body);
  }

  void close() => _client.close();
}

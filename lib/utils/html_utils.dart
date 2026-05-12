import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

/// Parse an HTML bio into a list of plain-text paragraphs.
///
/// Block-level tags (`p`, `div`, `li`, headings, `br`, blockquotes) act as
/// paragraph separators. Inline whitespace is collapsed. Empty paragraphs
/// are dropped.
List<String> htmlToParagraphs(String? html) {
  if (html == null || html.trim().isEmpty) return const [];
  final doc = html_parser.parse(html);

  final paragraphs = <String>[];
  final buffer = StringBuffer();

  void flush() {
    final text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) paragraphs.add(text);
    buffer.clear();
  }

  void walk(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(node.text);
      return;
    }
    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase();
    const blockTags = {
      'p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'blockquote', 'pre', 'tr', // line-like breaks
    };

    if (tag == 'br') {
      flush();
      return;
    }
    if (blockTags.contains(tag)) {
      flush();
      for (final child in node.nodes) {
        walk(child);
      }
      flush();
      return;
    }
    for (final child in node.nodes) {
      walk(child);
    }
  }

  final body = doc.body ?? doc.documentElement;
  if (body != null) {
    for (final node in body.nodes) {
      walk(node);
    }
  }
  flush();
  return paragraphs;
}

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Read bytes from a `blob:` URL via the modern Fetch API. Used as a
/// replacement for `cross_file_web`'s `XFile.readAsBytes()`, which
/// stages the response through XMLHttpRequest + FileReader and has
/// been observed to hang the renderer on multi-MB drag-dropped
/// files. `fetch().arrayBuffer()` is the same path the clipboard
/// paste already uses, which is known to work.
Future<Uint8List> readBlobUrlBytes(String url) async {
  final resp = await web.window.fetch(url.toJS).toDart;
  final buf = await resp.arrayBuffer().toDart;
  return buf.toDart.asUint8List();
}

/// Read the first image entry from the system clipboard via the
/// browser's Async Clipboard API. Returns `null` if the clipboard
/// holds no image (text-only paste, permission denied, or empty).
Future<Uint8List?> readImageFromClipboard() async {
  try {
    final items = await web.window.navigator.clipboard.read().toDart;
    for (final item in items.toDart) {
      for (final type in item.types.toDart) {
        final typeStr = type.toDart;
        if (typeStr.startsWith('image/')) {
          final blob = await item.getType(typeStr).toDart;
          final buffer = await blob.arrayBuffer().toDart;
          return buffer.toDart.asUint8List();
        }
      }
    }
  } catch (_) {
    // Permission denied, browser without clipboard.read(), etc.
  }
  return null;
}

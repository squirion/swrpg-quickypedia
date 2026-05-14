import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hard cap on the input size we'll try to decode on web. Very large
/// drag-dropped screenshots (raw camera dumps, etc.) can exhaust the
/// renderer process before they ever reach the canvas pipeline, which
/// shows up as a hard tab freeze (DevTools can't even attach). 25 MB
/// is well above any reasonable user-facing input but below the
/// browser's safe-decode limit.
const int _maxInputBytes = 25 * 1024 * 1024;

/// Resize and PNG-encode [bytes] using the browser's native pipeline.
/// The `image` package's pure-Dart decode/encode is fine on native but
/// freezes the JS main thread on multi-MB inputs after dart2js — using
/// the browser's `<canvas>` keeps the heavy work off the main thread.
Future<Uint8List> resizeToPng(Uint8List bytes, int maxEdgePx) async {
  if (bytes.length > _maxInputBytes) {
    final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
    throw Exception(
      'Image is too large to process in the browser ($mb MB). '
      'Try a smaller file (max ${(_maxInputBytes / (1024 * 1024)).round()} MB).',
    );
  }

  // Empty MIME so the browser detects the actual format from the
  // magic bytes; passing 'application/octet-stream' is technically
  // valid but some browsers won't decode it as an image.
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  try {
    final image = web.HTMLImageElement();
    final load = Completer<void>();
    image.onload = ((web.Event _) {
      if (!load.isCompleted) load.complete();
    }).toJS;
    image.onerror = ((web.Event _) {
      if (!load.isCompleted) {
        load.completeError(
          Exception('Browser could not decode the image bytes.'),
        );
      }
    }).toJS;
    image.src = url;
    await load.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw TimeoutException('Image decode timed out after 30 s'),
    );

    final w = image.naturalWidth;
    final h = image.naturalHeight;
    if (w == 0 || h == 0) {
      throw Exception('Decoded image has zero dimensions.');
    }
    final longest = w >= h ? w : h;
    final scale = longest <= maxEdgePx ? 1.0 : maxEdgePx / longest;
    final newW = (w * scale).round();
    final newH = (h * scale).round();

    final canvas =
        (web.document.createElement('canvas') as web.HTMLCanvasElement)
          ..width = newW
          ..height = newH;
    final ctx =
        canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    ctx.drawImage(image, 0, 0, newW.toDouble(), newH.toDouble());

    final out = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) {
        if (!out.isCompleted) out.complete(b);
      }).toJS,
      'image/png',
    );
    final pngBlob = await out.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw TimeoutException('Canvas encode timed out after 30 s'),
    );
    if (pngBlob == null) {
      throw Exception('Canvas.toBlob returned null.');
    }
    final buf = await pngBlob.arrayBuffer().toDart;
    return buf.toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

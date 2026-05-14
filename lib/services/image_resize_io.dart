import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decode → resize → PNG-encode via the `image` package on native.
/// Sync underneath, but the API is async so the web counterpart can
/// share it.
Future<Uint8List> resizeToPng(Uint8List bytes, int maxEdgePx) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Could not decode the supplied image bytes.');
  }
  final w = decoded.width;
  final h = decoded.height;
  final longest = w >= h ? w : h;
  final shrunk = longest <= maxEdgePx
      ? decoded
      : img.copyResize(
          decoded,
          width: w >= h ? maxEdgePx : null,
          height: h > w ? maxEdgePx : null,
          interpolation: img.Interpolation.cubic,
        );
  return Uint8List.fromList(img.encodePng(shrunk));
}

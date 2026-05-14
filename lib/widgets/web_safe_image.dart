import 'package:flutter/widgets.dart';

import 'web_safe_image_io.dart'
    if (dart.library.js_interop) 'web_safe_image_web.dart';

/// Renders a network image without falling foul of CORS on Flutter
/// web's CanvasKit renderer. On native this is just `Image.network`;
/// on web it pipes through an `<img>` element via [HtmlElementView]
/// so the browser draws the image natively (no CORS check on
/// display).
Widget webSafeImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? errorPlaceholder,
}) =>
    buildWebSafeImage(
      url: url,
      fit: fit,
      width: width,
      height: height,
      errorPlaceholder: errorPlaceholder,
    );

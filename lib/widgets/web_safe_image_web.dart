import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// View types we've already registered with the platform view
/// registry. The registry rejects re-registration of the same key,
/// so we cache the keys here.
final Set<String> _registered = <String>{};

String _viewTypeFor(String url, String fitCss) =>
    'webSafeImage:$fitCss:$url';

void _ensureRegistered(String url, String fitCss) {
  final type = _viewTypeFor(url, fitCss);
  if (_registered.contains(type)) return;
  _registered.add(type);
  ui_web.platformViewRegistry.registerViewFactory(
    type,
    (int viewId, {Object? params}) {
      final img = web.HTMLImageElement()
        ..src = url
        ..style.objectFit = fitCss
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block';
      return img;
    },
  );
}

String _fitToCss(BoxFit fit) {
  switch (fit) {
    case BoxFit.cover:
      return 'cover';
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.fitWidth:
    case BoxFit.fitHeight:
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.none:
      return 'none';
  }
}

/// Web path: render the image through an `<img>` element wrapped in
/// an [HtmlElementView]. Browsers don't enforce CORS on image
/// *display* — only on canvas pixel access — so this dodges the
/// "blocked by CORS policy" XHR fetch that CanvasKit's
/// [Image.network] performs for cross-origin hosts (Obsidian Portal
/// avatars, Fandom wiki thumbnails, etc.).
///
/// Downside: load errors aren't surfaced (no `errorBuilder`
/// equivalent on `<img>` from Dart side without a `StatefulWidget`),
/// so a failed URL shows the browser's broken-image icon rather
/// than [errorPlaceholder]. Acceptable for the avatar use case
/// since the upstream URLs are populated by the Obsidian Portal API
/// and shouldn't 404 in practice.
Widget buildWebSafeImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? errorPlaceholder,
}) {
  final fitCss = _fitToCss(fit);
  _ensureRegistered(url, fitCss);
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: _viewTypeFor(url, fitCss)),
  );
}

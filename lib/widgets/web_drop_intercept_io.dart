import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Shape the platform-agnostic side needs from each registered drop
/// surface. Mirrors the web impl so the import is a drop-in stub on
/// native builds where there's nothing to do.
abstract class WebDropSurface {
  Rect get globalRect;
  Future<void> handleBytes(Uint8List bytes);
  Future<void> handleUrl(String url);
}

void registerWebDropSurface(WebDropSurface s) {}
void unregisterWebDropSurface(WebDropSurface s) {}

/// No-op on native. The web counterpart installs a document-level
/// capture-phase drop handler at startup so `desktop_drop_web`'s
/// broken null-deref handler never gets a chance to run.
void initWebDropIntercept() {}

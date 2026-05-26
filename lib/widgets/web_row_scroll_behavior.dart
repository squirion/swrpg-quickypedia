import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// `ScrollBehavior` for the row-based screens (home + per-type
/// listings) on web. Strips the default Material vertical scrollbar
/// and enables click-and-drag scrolling with the mouse so the screen
/// behaves like the touch-drag flow on phone. On native, falls back
/// to the framework defaults so nothing changes there.
///
/// Per-row horizontal scrollbars in `CategoryRow` are constructed
/// explicitly with their own `Scrollbar` widget and aren't governed
/// by the ambient behavior — they continue to draw as today.
class _WebRowScrollBehavior extends MaterialScrollBehavior {
  const _WebRowScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => kIsWeb
      ? const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
        }
      : super.dragDevices;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (kIsWeb) return child;
    return super.buildScrollbar(context, child, details);
  }
}

const ScrollBehavior webRowScrollBehavior = _WebRowScrollBehavior();

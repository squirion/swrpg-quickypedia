import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Implemented by every widget that wants to receive drop events on
/// web. We can't lean on `desktop_drop`'s `DropTarget` here because
/// its global `window.ondrop` handler does `webkitGetAsEntry()!` on
/// every dragged item — that null-derefs the moment you drag anything
/// other than a real local file (e.g. an image from another browser
/// tab), and the exception nukes the rest of the drop chain so the
/// indicator hangs on screen forever.
abstract class WebDropSurface {
  /// Surface bounds in viewport coordinates, used to route a drop to
  /// the right registered surface when multiple are mounted.
  Rect get globalRect;

  /// Called when the dropped payload contains raw image bytes (real
  /// file from the OS, or a synthetic file Chrome creates for an
  /// in-tab image drag).
  Future<void> handleBytes(Uint8List bytes);

  /// Called when the dropped payload only contains a URL (drag from a
  /// webpage where the browser doesn't synthesize a file). Caller is
  /// expected to route through their existing "upload from URL" flow.
  Future<void> handleUrl(String url);
}

final List<WebDropSurface> _surfaces = <WebDropSurface>[];
bool _installed = false;

void registerWebDropSurface(WebDropSurface s) {
  initWebDropIntercept();
  _surfaces.add(s);
}

void unregisterWebDropSurface(WebDropSurface s) {
  _surfaces.remove(s);
}

/// Call once at app startup (from `main.dart`). Installs a
/// document-level capture-phase `drop` handler so `desktop_drop_web`'s
/// broken `webkitGetAsEntry()!` handler can never run — its null-deref
/// otherwise wedges the entire app the moment anything non-filesystem
/// is dropped (including the synthetic drag a browser starts when you
/// mouse over an `<img>` while dragging a scrollbar).
void initWebDropIntercept() {
  if (_installed) return;
  _installed = true;
  // Capture phase fires before `window.ondrop` (which `desktop_drop`
  // owns). `stopImmediatePropagation()` inside our handler prevents
  // the upstream broken code from running.
  web.document.addEventListener('drop', _onDrop.toJS, true.toJS);
  // `dragover` needs `preventDefault` for `drop` to fire at all.
  web.document.addEventListener(
    'dragover',
    ((web.Event e) => e.preventDefault()).toJS,
    true.toJS,
  );
}

void _onDrop(web.Event raw) {
  final event = raw as web.DragEvent;
  // Always swallow the drop in capture phase, regardless of whether
  // there's a matching surface — otherwise `desktop_drop`'s window
  // handler runs and crashes on any non-filesystem drop.
  event.preventDefault();
  event.stopImmediatePropagation();

  if (_surfaces.isEmpty) return;

  final point = Offset(
    event.clientX.toDouble(),
    event.clientY.toDouble(),
  );
  WebDropSurface? target;
  // Most-recently-registered surface wins on overlap (typical Z order).
  for (var i = _surfaces.length - 1; i >= 0; i--) {
    if (_surfaces[i].globalRect.contains(point)) {
      target = _surfaces[i];
      break;
    }
  }
  if (target == null) return;

  _dispatch(event, target);
}

Future<void> _dispatch(web.DragEvent event, WebDropSurface target) async {
  final transfer = event.dataTransfer;
  if (transfer == null) return;

  // Prefer real file bytes when present — `dataTransfer.files`
  // surfaces both OS file drops and synthetic files Chrome creates
  // for cross-tab image drags.
  final files = transfer.files;
  if (files.length > 0) {
    final file = files.item(0);
    if (file != null) {
      try {
        final buf = await file.arrayBuffer().toDart;
        await target.handleBytes(buf.toDart.asUint8List());
        return;
      } catch (_) {
        // Fall through to URL handling.
      }
    }
  }

  // Otherwise treat as a URL drop. The `text/uri-list` payload can
  // contain multiple URLs separated by newlines; take the first
  // non-comment line per RFC 2483.
  final uriList = transfer.getData('text/uri-list');
  final url = _firstUrl(uriList);
  if (url != null && url.isNotEmpty) {
    await target.handleUrl(url);
    return;
  }
  // Last resort — `text/plain` sometimes carries the URL too.
  final plain = transfer.getData('text/plain').trim();
  if (plain.startsWith('http://') || plain.startsWith('https://')) {
    await target.handleUrl(plain);
  }
}

String? _firstUrl(String uriList) {
  for (final line in uriList.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    return trimmed;
  }
  return null;
}

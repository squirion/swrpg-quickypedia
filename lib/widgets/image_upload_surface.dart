import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:swrpg_quickypedia/theme.dart';

import 'image_clipboard_io.dart'
    if (dart.library.js_interop) 'image_clipboard_web.dart';
import 'web_drop_intercept_io.dart'
    if (dart.library.js_interop) 'web_drop_intercept_web.dart';

typedef BytesUploader = Future<void> Function(Uint8List bytes);
typedef UrlUploader = Future<void> Function(String url);

/// Wraps a detail-screen hero image with three image-add affordances:
///
///   * **Pick / URL sheet** — same modal the edit-pencil button has always
///     opened; exposed as a static helper so callers can trigger it too.
///   * **Drag-and-drop** — drop an image file (or a URL string) onto the
///     hero panel. Works on web + desktop via the HTML5 / OS drag API.
///   * **Paste (Ctrl/Cmd+V)** — read the system clipboard while the
///     surface is focused. On web, raw image bytes from the Async
///     Clipboard API are uploaded directly; text falls back to the URL
///     upload path. On native, only text is read (no per-OS image
///     clipboard plugin) so the user sees a snackbar prompting drag-drop
///     or file-pick if there's no URL in the clipboard.
///
/// `onBytes` and `onUrl` are the per-category upload callbacks (each
/// view screen has its own uploader). They get the *raw* bytes / URL —
/// caller is responsible for the snackbar and provider invalidation.
class ImageUploadSurface extends StatefulWidget {
  final Widget child;
  final BytesUploader onBytes;
  final UrlUploader onUrl;

  const ImageUploadSurface({
    super.key,
    required this.child,
    required this.onBytes,
    required this.onUrl,
  });

  /// Show the "Add image" bottom sheet. Shared by the surface's
  /// keyboard / drop affordances and by the edit-pencil button on each
  /// view screen.
  static Future<void> showUploadSheet(
    BuildContext context, {
    required BytesUploader onBytes,
    required UrlUploader onUrl,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Add image',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from device'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _pickFromDevice(context, onBytes);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('From URL'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _promptForUrl(context, onUrl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickFromDevice(
    BuildContext context,
    BytesUploader onBytes,
  ) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }
    await onBytes(bytes);
  }

  static Future<void> _promptForUrl(
    BuildContext context,
    UrlUploader onUrl,
  ) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Image URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final clip = await Clipboard.getData('text/plain');
              if (clip?.text != null) controller.text = clip!.text!;
            },
            child: const Text('Paste'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Fetch'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    await onUrl(url);
  }

  @override
  State<ImageUploadSurface> createState() => _ImageUploadSurfaceState();
}

class _ImageUploadSurfaceState extends State<ImageUploadSurface>
    implements WebDropSurface {
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'ImageUploadSurface',
    skipTraversal: true,
  );
  final GlobalKey _dropAreaKey = GlobalKey();
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) registerWebDropSurface(this);
  }

  @override
  void dispose() {
    if (kIsWeb) unregisterWebDropSurface(this);
    _focusNode.dispose();
    super.dispose();
  }

  // ── WebDropSurface ───────────────────────────────────────────────
  @override
  Rect get globalRect {
    final ro = _dropAreaKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return Rect.zero;
    final topLeft = ro.localToGlobal(Offset.zero);
    return topLeft & ro.size;
  }

  @override
  Future<void> handleBytes(Uint8List bytes) async {
    if (mounted) setState(() => _isDragOver = false);
    await widget.onBytes(bytes);
  }

  @override
  Future<void> handleUrl(String url) async {
    if (mounted) setState(() => _isDragOver = false);
    await widget.onUrl(url);
  }

  Future<void> _handlePaste() async {
    if (kIsWeb) {
      final bytes = await readImageFromClipboard();
      if (bytes != null) {
        await widget.onBytes(bytes);
        return;
      }
    }
    final clip = await Clipboard.getData('text/plain');
    final text = clip?.text?.trim();
    if (text != null && text.isNotEmpty && _looksLikeUrl(text)) {
      await widget.onUrl(text);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Clipboard has no image or URL — try drag-and-drop or pick a file.',
        ),
      ),
    );
  }

  bool _looksLikeUrl(String s) =>
      s.startsWith('http://') || s.startsWith('https://');

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDragOver = false);
    if (details.files.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    // Diagnostic ping so we can see the drop fired even when the
    // subsequent decode hangs — without this, a hung decode looks
    // identical to a missed drop event.
    messenger.showSnackBar(
      const SnackBar(content: Text('Drop received — reading file…')),
    );
    final file = details.files.first;
    try {
      // On web, bypass `cross_file_web`'s XMLHttpRequest + FileReader
      // chain (which has been observed to hang on multi-MB inputs)
      // and read the blob URL directly via fetch — same path the
      // working Ctrl+V paste uses.
      final bytes = kIsWeb
          ? await readBlobUrlBytes(file.path)
          : await file.readAsBytes();
      await widget.onBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not read dropped file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            const _PasteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            const _PasteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PasteIntent: CallbackAction<_PasteIntent>(
            onInvoke: (_) {
              _handlePaste();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: false,
          child: MouseRegion(
            onEnter: (_) => _focusNode.requestFocus(),
            child: DropTarget(
              onDragEntered: (_) => setState(() => _isDragOver = true),
              onDragExited: (_) => setState(() => _isDragOver = false),
              onDragDone: _handleDrop,
              child: Stack(
                key: _dropAreaKey,
                children: [
                  widget.child,
                  if (_isDragOver)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.accent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Drop image to upload',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

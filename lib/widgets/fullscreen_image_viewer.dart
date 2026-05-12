import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Pinch-to-zoom full-screen viewer for any image URL. Designed to be
/// shared by every detail screen in the app (weapons, characters, …)
/// so the open-an-image affordance feels the same wherever it appears.
///
/// Use [FullscreenImageViewer.open] to push it as a route — pass the
/// same `imageUrl` and `heroTag` you used on the source widget to get
/// a free morph transition.
class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final Map<String, String>? httpHeaders;
  final String? heroTag;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    this.httpHeaders,
    this.heroTag,
  });

  /// Convenience for callers: push the viewer as a full-screen dialog.
  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    Map<String, String>? httpHeaders,
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imageUrl: imageUrl,
          httpHeaders: httpHeaders,
          heroTag: heroTag,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: httpHeaders,
      fit: BoxFit.contain,
      placeholder: (_, _) => const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      ),
      errorWidget: (_, _, _) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white24, size: 56),
      ),
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: image,
        ),
      ),
    );
  }
}

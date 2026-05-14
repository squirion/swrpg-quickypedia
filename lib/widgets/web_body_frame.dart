import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// On web, constrain content to a column the size of a phone-ish
/// reading width so the app reads as a card centered in the viewport
/// instead of hero images filling the full screen and pushing every
/// other section below the fold. No-op on native builds where the
/// device width is already the constraint.
class WebBodyFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  /// Detail (single-item) screens get a tighter column so the 4:5
  /// hero panel stays around ~500px tall and the stat block + start
  /// of the next section are visible on a ~900px-tall viewport.
  static const double detail = 460;

  /// Grid + list screens get a wider column so the multi-column item
  /// tile grid has room to breathe.
  static const double grid = 1080;

  const WebBodyFrame({
    super.key,
    required this.child,
    this.maxWidth = detail,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

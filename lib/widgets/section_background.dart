import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Subtle hexagonal-grid texture rendered behind a section's content,
/// fading from a low-opacity hairline at the top to fully transparent
/// by the section's mid-point. Used to visually demarcate the home
/// page's groups without enclosing them in a hard rectangle.
class SectionBackground extends StatelessWidget {
  final Widget child;

  const SectionBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _HexGridPainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _HexGridPainter extends CustomPainter {
  // Edge length of each pointy-top hex.
  static const double _r = 14.0;
  static const double _topAlpha = 0.10;
  // The pattern starts just below the GroupHeader's text so the
  // header reads cleanly against the dark bg, and the densest part of
  // the gradient lands behind the content rows. The GroupHeader's text
  // occupies y≈6..23 within the section; we clear it plus a small
  // margin.
  static const double _topInset = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= _topInset) return;

    final patternRect =
        Rect.fromLTRB(0, _topInset, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accent.withValues(alpha: _topAlpha),
          AppColors.accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55],
      ).createShader(patternRect);

    canvas.save();
    canvas.clipRect(patternRect);

    // Pointy-top hex dimensions.
    final hexW = math.sqrt(3) * _r; // horizontal pitch within a row
    final rowH = 1.5 * _r; // vertical pitch between rows

    final cols = (size.width / hexW).ceil() + 2;
    final rows = ((size.height - _topInset) / rowH).ceil() + 2;

    for (var row = -1; row < rows; row++) {
      final isOdd = row.isOdd;
      for (var col = -1; col < cols; col++) {
        final cx = col * hexW + (isOdd ? hexW / 2 : 0);
        final cy = _topInset + row * rowH;
        canvas.drawPath(_hexPath(cx, cy, _r), paint);
      }
    }

    canvas.restore();
  }

  Path _hexPath(double cx, double cy, double r) {
    final path = Path();
    // Pointy-top: vertices at 30°, 90°, 150°, 210°, 270°, 330°.
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 180) * (60 * i - 30);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexGridPainter oldDelegate) => false;
}

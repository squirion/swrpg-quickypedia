import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Visual placeholder used in gear UI when no `imageUrl` is available.
///
/// A satchel/pouch silhouette with a shoulder strap and clasp buckle,
/// rendered on the same diagonal-hatch background as the weapon and
/// armor placeholders.
class GearPlaceholder extends StatelessWidget {
  final Color? stroke;

  const GearPlaceholder({super.key, this.stroke});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg2,
      child: CustomPaint(
        painter: _GearPlaceholderPainter(
          stroke: stroke ?? AppColors.accent.withValues(alpha: 0.55),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GearPlaceholderPainter extends CustomPainter {
  final Color stroke;
  _GearPlaceholderPainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    _paintHatch(canvas, size);
    _paintSatchel(canvas, size);
  }

  void _paintHatch(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 8.0;
    for (double d = -size.height; d < size.width; d += step) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  void _paintSatchel(Canvas canvas, Size size) {
    const sourceW = 200.0;
    const sourceH = 240.0;
    final scale = (size.width / sourceW).clamp(0.0, size.height / sourceH);
    final dx = (size.width - sourceW * scale) / 2;
    final dy = (size.height - sourceH * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final outline = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = stroke.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Shoulder strap: a curved arc from upper-left to upper-right.
    final strap = Path()
      ..moveTo(40, 90)
      ..quadraticBezierTo(100, 30, 160, 90);
    canvas.drawPath(strap, outline);

    // Body: rounded rectangle with the flap notch at the top.
    final body = Path()
      ..moveTo(50, 95)
      ..lineTo(150, 95)
      ..lineTo(160, 110)
      ..lineTo(160, 200)
      ..quadraticBezierTo(160, 215, 145, 215)
      ..lineTo(55, 215)
      ..quadraticBezierTo(40, 215, 40, 200)
      ..lineTo(40, 110)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, outline);

    // Flap covering the top third.
    final flap = Path()
      ..moveTo(50, 95)
      ..lineTo(150, 95)
      ..lineTo(160, 110)
      ..lineTo(155, 140)
      ..quadraticBezierTo(100, 155, 45, 140)
      ..lineTo(40, 110)
      ..close();
    canvas.drawPath(flap, outline);

    // Clasp / buckle in the middle of the flap edge.
    canvas.drawRect(
      const Rect.fromLTWH(90, 135, 20, 12),
      outline,
    );

    // Side stitch lines on the body.
    final stitch = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(55, 160), const Offset(55, 205), stitch);
    canvas.drawLine(const Offset(145, 160), const Offset(145, 205), stitch);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GearPlaceholderPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

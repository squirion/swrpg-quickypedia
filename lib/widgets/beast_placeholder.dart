import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Visual placeholder used in beast UI when no `imageUrl` is available.
///
/// A stylized quadruped silhouette — body, four legs, tail, head with
/// a small ear — on the diagonal-hatch background shared across the
/// category placeholders.
class BeastPlaceholder extends StatelessWidget {
  final Color? stroke;

  const BeastPlaceholder({super.key, this.stroke});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg2,
      child: CustomPaint(
        painter: _BeastPlaceholderPainter(
          stroke: stroke ?? AppColors.accent.withValues(alpha: 0.55),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BeastPlaceholderPainter extends CustomPainter {
  final Color stroke;
  _BeastPlaceholderPainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    _paintHatch(canvas, size);
    _paintBeast(canvas, size);
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

  void _paintBeast(Canvas canvas, Size size) {
    const sourceW = 480.0;
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

    // Body: an elongated oval-ish blob.
    final body = Path()
      ..moveTo(110, 130)
      ..quadraticBezierTo(140, 90, 220, 88)
      ..lineTo(330, 88)
      ..quadraticBezierTo(390, 92, 380, 130)
      ..quadraticBezierTo(360, 150, 280, 152)
      ..lineTo(160, 152)
      ..quadraticBezierTo(110, 152, 110, 130)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, outline);

    // Head: small rounded rectangle in front.
    final head = Path()
      ..moveTo(360, 95)
      ..quadraticBezierTo(415, 90, 425, 110)
      ..quadraticBezierTo(420, 132, 380, 132)
      ..lineTo(360, 130)
      ..close();
    canvas.drawPath(head, fill);
    canvas.drawPath(head, outline);

    // Ear (small triangle on top of head).
    final ear = Path()
      ..moveTo(395, 90)
      ..lineTo(410, 70)
      ..lineTo(415, 92)
      ..close();
    canvas.drawPath(ear, outline);

    // Eye.
    canvas.drawCircle(const Offset(405, 110), 2.5, outline);

    // Front-near leg.
    canvas.drawLine(const Offset(330, 152), const Offset(335, 200), outline);
    canvas.drawLine(const Offset(335, 200), const Offset(345, 200), outline);
    // Front-far leg.
    canvas.drawLine(const Offset(305, 152), const Offset(310, 200), outline);
    canvas.drawLine(const Offset(310, 200), const Offset(320, 200), outline);
    // Back-near leg.
    canvas.drawLine(const Offset(170, 152), const Offset(165, 200), outline);
    canvas.drawLine(const Offset(165, 200), const Offset(155, 200), outline);
    // Back-far leg.
    canvas.drawLine(const Offset(195, 152), const Offset(190, 200), outline);
    canvas.drawLine(const Offset(190, 200), const Offset(180, 200), outline);

    // Tail: a curling line from the back.
    final tail = Path()
      ..moveTo(110, 120)
      ..quadraticBezierTo(70, 95, 60, 60)
      ..quadraticBezierTo(60, 50, 75, 55);
    canvas.drawPath(tail, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeastPlaceholderPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Visual placeholder used in starship UI when no `imageUrl` is
/// available. Renders an X-wing-style silhouette (cockpit + fuselage +
/// 4 swept S-foils with engine nacelles) on the diagonal-hatch
/// background shared across the category placeholders.
class StarshipPlaceholder extends StatelessWidget {
  final Color? stroke;

  const StarshipPlaceholder({super.key, this.stroke});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg2,
      child: CustomPaint(
        painter: _StarshipPlaceholderPainter(
          stroke: stroke ?? AppColors.accent.withValues(alpha: 0.55),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StarshipPlaceholderPainter extends CustomPainter {
  final Color stroke;
  _StarshipPlaceholderPainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    _paintHatch(canvas, size);
    _paintStarship(canvas, size);
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

  void _paintStarship(Canvas canvas, Size size) {
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
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = stroke.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Central fuselage: pointed nose at right, blunt tail at left.
    final fuselage = Path()
      ..moveTo(70, 120)
      ..lineTo(140, 100)
      ..lineTo(360, 105)
      ..quadraticBezierTo(440, 120, 360, 135)
      ..lineTo(140, 140)
      ..close();
    canvas.drawPath(fuselage, fill);
    canvas.drawPath(fuselage, outline);

    // Cockpit canopy.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(280, 95, 60, 18),
        const Radius.circular(4),
      ),
      outline,
    );

    // Upper-left S-foil.
    final ulFoil = Path()
      ..moveTo(160, 110)
      ..lineTo(60, 60)
      ..lineTo(30, 60)
      ..lineTo(140, 120)
      ..close();
    canvas.drawPath(ulFoil, outline);
    // Engine pod at the tip.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 52, 50, 12),
        const Radius.circular(3),
      ),
      outline,
    );

    // Lower-left S-foil.
    final llFoil = Path()
      ..moveTo(160, 130)
      ..lineTo(60, 180)
      ..lineTo(30, 180)
      ..lineTo(140, 130)
      ..close();
    canvas.drawPath(llFoil, outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 176, 50, 12),
        const Radius.circular(3),
      ),
      outline,
    );

    // Upper-right S-foil (shorter, more swept).
    final urFoil = Path()
      ..moveTo(220, 100)
      ..lineTo(190, 60)
      ..lineTo(220, 60)
      ..lineTo(260, 105)
      ..close();
    canvas.drawPath(urFoil, outline);

    // Lower-right S-foil.
    final lrFoil = Path()
      ..moveTo(220, 140)
      ..lineTo(190, 180)
      ..lineTo(220, 180)
      ..lineTo(260, 135)
      ..close();
    canvas.drawPath(lrFoil, outline);

    // Nose tip / sensor.
    canvas.drawCircle(const Offset(420, 120), 4, outline);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StarshipPlaceholderPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

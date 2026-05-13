import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Visual placeholder used in vehicle UI when no `imageUrl` is
/// available. Renders a low-profile speeder silhouette (body + nose
/// cone + repulsor pods + cockpit canopy) on the same diagonal-hatch
/// background as the other category placeholders.
class VehiclePlaceholder extends StatelessWidget {
  final Color? stroke;

  const VehiclePlaceholder({super.key, this.stroke});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg2,
      child: CustomPaint(
        painter: _VehiclePlaceholderPainter(
          stroke: stroke ?? AppColors.accent.withValues(alpha: 0.55),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _VehiclePlaceholderPainter extends CustomPainter {
  final Color stroke;
  _VehiclePlaceholderPainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    _paintHatch(canvas, size);
    _paintSpeeder(canvas, size);
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

  void _paintSpeeder(Canvas canvas, Size size) {
    // 480 × 200 viewBox (long aspect, fits speeders/walkers).
    const sourceW = 480.0;
    const sourceH = 200.0;
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

    // Main body: a swept teardrop. Nose at right, blunt tail at left.
    final body = Path()
      ..moveTo(60, 110)
      ..quadraticBezierTo(80, 85, 130, 80)
      ..lineTo(330, 80)
      ..quadraticBezierTo(390, 80, 430, 105)
      ..quadraticBezierTo(390, 130, 330, 130)
      ..lineTo(130, 130)
      ..quadraticBezierTo(80, 125, 60, 110)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, outline);

    // Cockpit canopy bubble.
    final canopy = Path()
      ..moveTo(180, 80)
      ..quadraticBezierTo(225, 55, 280, 80)
      ..close();
    canvas.drawPath(canopy, outline);

    // Front repulsor pod (right side of body, hanging below).
    final frontPod = Path()
      ..moveTo(340, 130)
      ..quadraticBezierTo(370, 165, 410, 150)
      ..quadraticBezierTo(395, 135, 340, 130)
      ..close();
    canvas.drawPath(frontPod, outline);

    // Rear repulsor pod.
    final rearPod = Path()
      ..moveTo(90, 130)
      ..quadraticBezierTo(115, 165, 155, 150)
      ..quadraticBezierTo(135, 135, 90, 130)
      ..close();
    canvas.drawPath(rearPod, outline);

    // Nose tip / sensor.
    canvas.drawCircle(const Offset(430, 105), 4, outline);

    // Body waterline / seam.
    canvas.drawLine(
      const Offset(80, 110),
      const Offset(425, 108),
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VehiclePlaceholderPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

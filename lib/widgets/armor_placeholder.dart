import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Visual placeholder used in armor UI when no `imageUrl` is available.
///
/// Mirrors [WeaponPlaceholder]: same diagonal-hatch background, same
/// accent stroke. The silhouette is a chest-plate / cuirass (shoulder
/// yoke + V-neck collar + pectoral plates + abdomen segments + hip
/// flares), built with [CustomPaint] so it scales cleanly.
class ArmorPlaceholder extends StatelessWidget {
  /// Tint for the silhouette stroke (defaults to the steel-blue accent).
  final Color? stroke;

  const ArmorPlaceholder({super.key, this.stroke});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg2,
      child: CustomPaint(
        painter: _ArmorPlaceholderPainter(
          stroke: stroke ?? AppColors.accent.withValues(alpha: 0.55),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArmorPlaceholderPainter extends CustomPainter {
  final Color stroke;
  _ArmorPlaceholderPainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    _paintHatch(canvas, size);
    _paintChestPlate(canvas, size);
  }

  /// Faint 45° hatch — mirrors the weapon placeholder.
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

  void _paintChestPlate(Canvas canvas, Size size) {
    // Source viewBox is 200 × 240 (taller than wide for a torso shape);
    // scale uniformly and center.
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
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = stroke.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Cuirass outline: shoulder yoke → underarm → waist → opposite
    // shoulder, symmetric around x=100. The V-neck is carved out at the
    // top with a small notch.
    final cuirass = Path()
      // Left shoulder
      ..moveTo(40, 50)
      // Left clavicle / yoke up to V-neck left edge
      ..lineTo(85, 55)
      // V-neck notch
      ..lineTo(100, 75)
      ..lineTo(115, 55)
      // Right shoulder
      ..lineTo(160, 50)
      // Right pauldron flare
      ..quadraticBezierTo(180, 60, 170, 95)
      // Right rib taper
      ..quadraticBezierTo(165, 130, 150, 150)
      // Right hip flare
      ..lineTo(160, 200)
      // Belt under-edge
      ..lineTo(40, 200)
      // Left hip flare
      ..lineTo(50, 150)
      // Left rib taper
      ..quadraticBezierTo(35, 130, 30, 95)
      // Left pauldron flare back up to start
      ..quadraticBezierTo(20, 60, 40, 50)
      ..close();
    canvas.drawPath(cuirass, fill);
    canvas.drawPath(cuirass, outline);

    // Pectoral seam — vertical line down the center, broken at the
    // sternum to suggest plate joinery.
    final seamPaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(100, 80), const Offset(100, 140), seamPaint);

    // Pectoral plate split — two diagonals from sternum to underarms.
    canvas.drawLine(const Offset(100, 95), const Offset(55, 95), seamPaint);
    canvas.drawLine(const Offset(100, 95), const Offset(145, 95), seamPaint);

    // Abdomen segment lines — three horizontal ribs across the belly.
    for (final y in [155, 170, 185]) {
      canvas.drawLine(
        Offset(55, y.toDouble()),
        Offset(145, y.toDouble()),
        seamPaint,
      );
    }

    // Belt at the bottom.
    canvas.drawRect(
      const Rect.fromLTWH(45, 200, 110, 14),
      outline,
    );
    // Buckle center.
    canvas.drawRect(
      const Rect.fromLTWH(92, 202, 16, 10),
      outline,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArmorPlaceholderPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Visual placeholder used in weapon UI when no `imageUrl` is available.
///
/// Ported from the `swrpg-weapon-view` design handoff's rifle SVG so the
/// placeholder feels intentional rather than empty. The diagonal hatch
/// background matches the design; the silhouette is the design's
/// `rifle` shape rendered with [CustomPaint].
class WeaponPlaceholder extends StatelessWidget {
  /// Tint for the silhouette stroke (defaults to the steel-blue accent).
  final Color? stroke;

  const WeaponPlaceholder({super.key, this.stroke});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg2,
      child: CustomPaint(
        painter: _WeaponPlaceholderPainter(
          stroke: stroke ?? AppColors.accent.withValues(alpha: 0.55),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WeaponPlaceholderPainter extends CustomPainter {
  final Color stroke;
  _WeaponPlaceholderPainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    _paintHatch(canvas, size);
    _paintRifle(canvas, size);
  }

  /// Faint 45° hatch — mirrors the design's `<pattern>` element.
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

  void _paintRifle(Canvas canvas, Size size) {
    // Source SVG uses a 480 × 200 viewBox; scale uniformly + center.
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
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = stroke.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Stock
    final stock = Path()
      ..moveTo(40, 100)
      ..lineTo(90, 90)
      ..lineTo(130, 95)
      ..lineTo(130, 115)
      ..lineTo(90, 120)
      ..close();
    canvas.drawPath(stock, fill);
    canvas.drawPath(stock, outline);

    // Receiver
    final receiver = const Rect.fromLTWH(130, 92, 170, 22);
    canvas.drawRect(receiver, fill);
    canvas.drawRect(receiver, outline);

    // Grip
    final grip = Path()
      ..moveTo(180, 114)
      ..lineTo(195, 145)
      ..lineTo(215, 145)
      ..lineTo(210, 114)
      ..close();
    canvas.drawPath(grip, outline);

    // Barrel
    canvas.drawRect(const Rect.fromLTWH(300, 96, 130, 10), outline);
    // Muzzle
    canvas.drawRect(const Rect.fromLTWH(430, 92, 14, 18), outline);
    // Scope
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(170, 76, 80, 14),
        const Radius.circular(2),
      ),
      outline,
    );
    // Scope dots
    canvas.drawCircle(const Offset(180, 83), 5, outline);
    canvas.drawCircle(const Offset(240, 83), 5, outline);
    // Foregrip rail
    final railPaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(310, 102), const Offset(420, 102), railPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WeaponPlaceholderPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

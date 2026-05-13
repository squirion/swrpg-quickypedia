import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Diamond-shaped tile for a vehicle's 4-zone defense rating.
///
/// The square clips to a diamond; inside, 4 right triangles share the
/// diamond's center as their apex and each touch one edge of the
/// bounding square (top / right / bottom / left). Each triangle is
/// labeled with its compass direction (F / S / A / P) and the zone's
/// value (a digit or `–` when null).
///
/// Layout:
/// ```
///       Fore
///        ▲
///   Port ◄ ▶ Starboard
///        ▼
///        Aft
/// ```
class DefenseDiamond extends StatelessWidget {
  final String? fore;
  final String? port;
  final String? starboard;
  final String? aft;
  final double size;

  const DefenseDiamond({
    super.key,
    required this.fore,
    required this.port,
    required this.starboard,
    required this.aft,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: ClipPath(
            clipper: const _DiamondClipper(),
            child: CustomPaint(
              painter: _DiamondPainter(
                fore: fore ?? '–',
                port: port ?? '–',
                starboard: starboard ?? '–',
                aft: aft ?? '–',
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.statTabBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'DEFENSE',
            style: AppFonts.display(
              const TextStyle(
                fontSize: 10,
                letterSpacing: 2.0,
                color: AppColors.statTabInk,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiamondClipper extends CustomClipper<Path> {
  const _DiamondClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DiamondPainter extends CustomPainter {
  final String fore;
  final String port;
  final String starboard;
  final String aft;

  _DiamondPainter({
    required this.fore,
    required this.port,
    required this.starboard,
    required this.aft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Midpoints of the four diamond edges — the seams run between
    // opposing midpoints (an X rotated 45° from the original cross),
    // so they sit clear of the value text that lives near each vertex.
    final ulMid = Offset(cx / 2, cy / 2);
    final urMid = Offset((cx + w) / 2, cy / 2);
    final lrMid = Offset((cx + w) / 2, (cy + h) / 2);
    final llMid = Offset(cx / 2, (cy + h) / 2);

    // Vertex-centered wedges: each wedge owns one vertex (top = Fore,
    // right = Starboard, bottom = Aft, left = Port) and is bounded by
    // the two adjacent diagonal seams + the two adjacent diamond edges.
    final top = Path()
      ..moveTo(cx, cy)
      ..lineTo(ulMid.dx, ulMid.dy)
      ..lineTo(cx, 0)
      ..lineTo(urMid.dx, urMid.dy)
      ..close();
    final right = Path()
      ..moveTo(cx, cy)
      ..lineTo(urMid.dx, urMid.dy)
      ..lineTo(w, cy)
      ..lineTo(lrMid.dx, lrMid.dy)
      ..close();
    final bottom = Path()
      ..moveTo(cx, cy)
      ..lineTo(lrMid.dx, lrMid.dy)
      ..lineTo(cx, h)
      ..lineTo(llMid.dx, llMid.dy)
      ..close();
    final left = Path()
      ..moveTo(cx, cy)
      ..lineTo(llMid.dx, llMid.dy)
      ..lineTo(0, cy)
      ..lineTo(ulMid.dx, ulMid.dy)
      ..close();

    // Alternating fills make the wedge boundaries readable even before
    // the seam strokes go on top.
    final fills = {
      'fore': const Color(0xFF1B2230),
      'starboard': const Color(0xFF161B27),
      'aft': const Color(0xFF1B2230),
      'port': const Color(0xFF161B27),
    };
    canvas.drawPath(top, Paint()..color = fills['fore']!);
    canvas.drawPath(right, Paint()..color = fills['starboard']!);
    canvas.drawPath(bottom, Paint()..color = fills['aft']!);
    canvas.drawPath(left, Paint()..color = fills['port']!);

    // Diagonal seams between opposing edge midpoints. These pass
    // through the center and form an X that hugs the diamond's edges
    // rather than crossing the value anchors.
    final seam = Paint()
      ..color = AppColors.lineStrong.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    canvas.drawLine(ulMid, lrMid, seam);
    canvas.drawLine(urMid, llMid, seam);

    // Anchors at the midpoint between center and each vertex so the
    // value text sits well inside its wedge.
    _drawZone(canvas, Offset(cx, cy * 0.5), fore, 'F');
    _drawZone(canvas, Offset((cx + w) / 2, cy), starboard, 'S');
    _drawZone(canvas, Offset(cx, (cy + h) / 2), aft, 'A');
    _drawZone(canvas, Offset(cx * 0.5, cy), port, 'P');
  }

  void _drawZone(Canvas canvas, Offset anchor, String value, String label) {
    final valuePainter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    valuePainter.paint(
      canvas,
      Offset(anchor.dx - valuePainter.width / 2,
          anchor.dy - valuePainter.height / 2 - 6),
    );
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.accent.withValues(alpha: 0.85),
          fontSize: 9,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(anchor.dx - labelPainter.width / 2,
          anchor.dy + valuePainter.height / 2 - 4),
    );
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter oldDelegate) =>
      oldDelegate.fore != fore ||
      oldDelegate.port != port ||
      oldDelegate.starboard != starboard ||
      oldDelegate.aft != aft;
}

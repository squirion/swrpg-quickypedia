import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:swrpg_quickypedia/widgets/web_body_frame.dart';

/// Width at which the layout expands from one column to two. Tuned so
/// the hero panel keeps its existing ~460 px column on the left and
/// the first section gets a matching ~460 px column on the right with
/// a 24 px gutter. Below this, we drop back to a single capped column
/// and stack everything vertically.
const double _sideBySideBreakpoint = 960;
const double _wideMaxWidth = 944;
const double _columnGutter = 24;

/// Shared layout for the weapon/armor/gear/vehicle/starship/beast
/// detail screens. Single-column on narrow viewports, two-column on
/// wide ones — hero on the left, first section on the right, all
/// remaining sections stacked underneath at the combined width.
class ItemDetailLayout extends StatelessWidget {
  final Widget crumbs;
  final Widget hero;
  final Widget firstSectionHeading;
  final Widget firstSectionBody;
  final List<Widget> restSections;

  const ItemDetailLayout({
    super.key,
    required this.crumbs,
    required this.hero,
    required this.firstSectionHeading,
    required this.firstSectionBody,
    this.restSections = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Only widen on web — native targets stay phone-sized today and
    // don't need the responsive split.
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final wide = kIsWeb && viewportWidth >= _sideBySideBreakpoint;

    return WebBodyFrame(
      maxWidth: wide ? _wideMaxWidth : WebBodyFrame.detail,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        children: [
          crumbs,
          const SizedBox(height: 16),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: hero),
                const SizedBox(width: _columnGutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      firstSectionHeading,
                      const SizedBox(height: 14),
                      firstSectionBody,
                    ],
                  ),
                ),
              ],
            )
          else ...[
            hero,
            const SizedBox(height: 20),
            firstSectionHeading,
            const SizedBox(height: 14),
            firstSectionBody,
          ],
          ...restSections,
        ],
      ),
    );
  }
}

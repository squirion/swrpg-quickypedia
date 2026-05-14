import 'package:flutter/material.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Numbered section header used to label the two home-screen groups
/// (CAMPAIGN, SYSTEM). Mirrors the section-heading treatment from the
/// detail screens: mono "01"-style number prefix, display-font caps
/// label, fading horizontal rule, plus an optional trailing slot for
/// inline controls (the System header uses this for the sort menu).
class GroupHeader extends StatelessWidget {
  final String number;
  final String label;
  final Widget? trailing;

  const GroupHeader({
    super.key,
    required this.number,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            number,
            style: AppFonts.mono(
              const TextStyle(
                fontSize: 11,
                color: AppColors.accent,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.display(
                const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3.0,
                  color: AppColors.inkDim,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            flex: 1,
            fit: FlexFit.tight,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.lineStrong, Colors.transparent],
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class CategoryRow extends StatefulWidget {
  final String title;
  final Widget child;
  final VoidCallback? onTitleTap;

  const CategoryRow({
    super.key,
    required this.title,
    required this.child,
    this.onTitleTap,
  });

  @override
  State<CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<CategoryRow> {
  /// Per-row controller. Each tile row scrolls horizontally
  /// independently, and on web we want a visible scrollbar attached
  /// to that scroll so the user knows there are tiles off-screen.
  /// Children inject themselves into this controller via
  /// `primary: true` on their `ListView`.
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    final header = widget.onTitleTap == null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(widget.title, style: titleStyle),
          )
        : InkWell(
            onTap: widget.onTitleTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.title, style: titleStyle),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          );

    // On web, the row height has to include space for the scrollbar
    // so it doesn't crop the bottom of the tiles. Default Material
    // scrollbar thickness is 6 px + a small gap.
    final rowHeight = kIsWeb ? 142.0 : 128.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(
          height: rowHeight,
          child: PrimaryScrollController(
            controller: _controller,
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: kIsWeb,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

class ComingSoonTile extends StatelessWidget {
  final IconData icon;
  const ComingSoonTile({super.key, this.icon = Icons.hourglass_empty});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: 120,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 4),
                Text(
                  'Coming soon',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

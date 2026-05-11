import 'package:flutter/material.dart';

class CategoryRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    final header = onTitleTap == null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(title, style: titleStyle),
          )
        : InkWell(
            onTap: onTitleTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: titleStyle),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: 128, child: child),
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

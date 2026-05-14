import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// Compact sort menu surfaced in the System group header on home.
/// Exposes the cross-category subset (Rarity / Price / Alphabetical);
/// the notifier propagates each pick to every per-category sort
/// provider so the rest of the app picks up the change immediately.
class HomeSystemSortMenu extends ConsumerWidget {
  const HomeSystemSortMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(homeSystemSortProvider);
    return PopupMenuButton<HomeSystemSortAttr>(
      icon: const Icon(Icons.sort, size: 20),
      tooltip: 'Sort system rows',
      onSelected: (attr) =>
          ref.read(homeSystemSortProvider.notifier).select(attr),
      itemBuilder: (_) => [
        for (final attr in HomeSystemSortAttr.values)
          PopupMenuItem<HomeSystemSortAttr>(
            value: attr,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: attr == sort.attr
                      ? Icon(
                          sort.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: AppColors.accent,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  attr.label,
                  style: TextStyle(
                    fontWeight: attr == sort.attr
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: attr == sort.attr
                        ? AppColors.ink
                        : AppColors.inkDim,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

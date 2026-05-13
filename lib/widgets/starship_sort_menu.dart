import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/starship_sort.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/theme.dart';

class StarshipSortMenu extends ConsumerWidget {
  const StarshipSortMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(starshipSortProvider);
    return PopupMenuButton<StarshipSortAttr>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort',
      onSelected: (attr) =>
          ref.read(starshipSortProvider.notifier).select(attr),
      itemBuilder: (_) => [
        for (final attr in StarshipSortAttr.values)
          PopupMenuItem<StarshipSortAttr>(
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

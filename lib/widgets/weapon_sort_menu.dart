import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/weapon_sort.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/theme.dart';

/// AppBar action that lets the user pick the weapon sort attribute and
/// direction. Tapping the currently-selected attribute toggles its
/// direction; tapping a different attribute switches axis (keeping the
/// last direction so re-flipping isn't required on every axis change).
class WeaponSortMenu extends ConsumerWidget {
  const WeaponSortMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(weaponSortProvider);
    return PopupMenuButton<WeaponSortAttr>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort',
      onSelected: (attr) =>
          ref.read(weaponSortProvider.notifier).select(attr),
      itemBuilder: (_) => [
        for (final attr in WeaponSortAttr.values)
          PopupMenuItem<WeaponSortAttr>(
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

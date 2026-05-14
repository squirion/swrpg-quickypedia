import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/armor.dart';
import 'package:swrpg_quickypedia/models/beast.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/models/gear.dart';
import 'package:swrpg_quickypedia/models/starship.dart';
import 'package:swrpg_quickypedia/models/vehicle.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/armor_view_screen.dart';
import 'package:swrpg_quickypedia/screens/beast_view_screen.dart';
import 'package:swrpg_quickypedia/screens/character_bio_screen.dart';
import 'package:swrpg_quickypedia/screens/gear_view_screen.dart';
import 'package:swrpg_quickypedia/screens/starship_view_screen.dart';
import 'package:swrpg_quickypedia/screens/vehicle_view_screen.dart';
import 'package:swrpg_quickypedia/screens/weapon_view_screen.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/armor_tile.dart';
import 'package:swrpg_quickypedia/widgets/beast_tile.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/character_tile.dart';
import 'package:swrpg_quickypedia/widgets/gear_tile.dart';
import 'package:swrpg_quickypedia/widgets/starship_tile.dart';
import 'package:swrpg_quickypedia/widgets/vehicle_tile.dart';
import 'package:swrpg_quickypedia/widgets/weapon_tile.dart';

/// Horizontal row of the up-to-10 most recently opened tiles, mixed
/// across categories. Filters by the global search query (within the
/// 10, no backfill from history). Tapping a tile here pushes the
/// detail screen WITHOUT recording — the row's order stays stable.
class RecentlyViewedRow extends ConsumerWidget {
  const RecentlyViewedRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(recentlyViewedResolvedProvider);
    final query = ref.watch(searchQueryProvider);

    return CategoryRow(
      title: 'Recently viewed',
      onTitleTap: null,
      child: Builder(builder: (_) {
        final filtered = query.isEmpty
            ? resolved
            : resolved
                .where((e) =>
                    _nameOf(e.item).toLowerCase().contains(query.toLowerCase()))
                .toList(growable: false);
        if (filtered.isEmpty) return const _NoMatchTile();
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          primary: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final e = filtered[i];
            return SizedBox(
              width: 120,
              child: _tileFor(context, e),
            );
          },
        );
      }),
    );
  }
}

String _nameOf(Object item) {
  if (item is Weapon) return item.name;
  if (item is Armor) return item.name;
  if (item is Gear) return item.name;
  if (item is Vehicle) return item.name;
  if (item is Starship) return item.name;
  if (item is Beast) return item.name;
  if (item is Character) return item.name;
  return '';
}

Widget _tileFor(BuildContext context, ({String kind, Object item}) e) {
  switch (e.kind) {
    case 'weapon':
      final w = e.item as Weapon;
      return WeaponTile(
        weapon: w,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WeaponViewScreen(weapon: w)),
        ),
      );
    case 'armor':
      final a = e.item as Armor;
      return ArmorTile(
        armor: a,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ArmorViewScreen(armor: a)),
        ),
      );
    case 'gear':
      final g = e.item as Gear;
      return GearTile(
        gear: g,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GearViewScreen(gear: g)),
        ),
      );
    case 'vehicle':
      final v = e.item as Vehicle;
      return VehicleTile(
        vehicle: v,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VehicleViewScreen(vehicle: v)),
        ),
      );
    case 'starship':
      final s = e.item as Starship;
      return StarshipTile(
        starship: s,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StarshipViewScreen(starship: s)),
        ),
      );
    case 'beast':
      final b = e.item as Beast;
      return BeastTile(
        beast: b,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BeastViewScreen(beast: b)),
        ),
      );
    case 'character':
      final c = e.item as Character;
      return CharacterTile(
        character: c,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CharacterBioScreen(character: c)),
        ),
      );
  }
  return const SizedBox.shrink();
}

class _NoMatchTile extends StatelessWidget {
  const _NoMatchTile();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No matches',
        style: TextStyle(
          color: AppColors.inkFaint,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

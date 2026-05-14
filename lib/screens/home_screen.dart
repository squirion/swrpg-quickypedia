import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/armor_view_screen.dart';
import 'package:swrpg_quickypedia/screens/armors_type_screen.dart';
import 'package:swrpg_quickypedia/screens/beast_view_screen.dart';
import 'package:swrpg_quickypedia/screens/beasts_type_screen.dart';
import 'package:swrpg_quickypedia/screens/campaign_input_screen.dart';
import 'package:swrpg_quickypedia/screens/category_grid_screen.dart';
import 'package:swrpg_quickypedia/screens/character_bio_screen.dart';
import 'package:swrpg_quickypedia/screens/gear_type_screen.dart';
import 'package:swrpg_quickypedia/screens/gear_view_screen.dart';
import 'package:swrpg_quickypedia/screens/starship_view_screen.dart';
import 'package:swrpg_quickypedia/screens/starships_type_screen.dart';
import 'package:swrpg_quickypedia/screens/vehicle_view_screen.dart';
import 'package:swrpg_quickypedia/screens/vehicles_type_screen.dart';
import 'package:swrpg_quickypedia/screens/weapon_view_screen.dart';
import 'package:swrpg_quickypedia/screens/weapons_type_screen.dart';
import 'package:swrpg_quickypedia/models/campaign.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/armor_tile.dart';
import 'package:swrpg_quickypedia/widgets/beast_tile.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/character_tile.dart';
import 'package:swrpg_quickypedia/widgets/section_background.dart';
import 'package:swrpg_quickypedia/widgets/download_from_cloud_button.dart';
import 'package:swrpg_quickypedia/widgets/gear_tile.dart';
import 'package:swrpg_quickypedia/widgets/group_header.dart';
import 'package:swrpg_quickypedia/widgets/home_system_sort_menu.dart';
import 'package:swrpg_quickypedia/widgets/recently_viewed_row.dart';
import 'package:swrpg_quickypedia/widgets/search_bar_field.dart';
import 'package:swrpg_quickypedia/widgets/settings_cog_menu.dart';
import 'package:swrpg_quickypedia/widgets/starship_tile.dart';
import 'package:swrpg_quickypedia/widgets/vehicle_tile.dart';
import 'package:swrpg_quickypedia/widgets/weapon_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openCharactersGrid(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryGridScreen<Character>(
          title: 'Characters',
          icon: Icons.person,
          watchItems: (ref) => ref.watch(charactersProvider),
          matchesQuery: (c, q) {
            final lq = q.toLowerCase();
            if (c.name.toLowerCase().contains(lq)) return true;
            final owner = c.author?.username.toLowerCase();
            return owner != null && owner.contains(lq);
          },
          itemBuilder: (ctx, c) => CharacterTile(
            character: c,
            onTap: () {
              ref
                  .read(recentlyViewedProvider.notifier)
                  .record('character', c.id);
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => CharacterBioScreen(character: c),
                ),
              );
            },
          ),
          searchHint: 'Search by name or owner',
        ),
      ),
    );
  }

  void _openWeaponsTypeScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeaponsTypeScreen()),
    );
  }

  void _openArmorsTypeScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArmorsTypeScreen()),
    );
  }

  void _openGearTypeScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GearTypeScreen()),
    );
  }

  void _openVehiclesTypeScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VehiclesTypeScreen()),
    );
  }

  void _openStarshipsTypeScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StarshipsTypeScreen()),
    );
  }

  void _openBeastsTypeScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BeastsTypeScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(charactersProvider);
    final weapons = ref.watch(weaponsProvider);
    final armors = ref.watch(armorsProvider);
    final gear = ref.watch(gearProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final starships = ref.watch(starshipsProvider);
    final beasts = ref.watch(beastsProvider);
    final query = ref.watch(searchQueryProvider);
    final searching = query.isNotEmpty;
    final campaignLabel = _resolveCampaignLabel(ref);
    final recent = ref.watch(recentlyViewedResolvedProvider);
    final showRecent = recent.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SWRPG Quickypedia'),
        actions: [
          const DownloadFromCloudButton(),
          const SettingsCogMenu(),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change campaign',
            onPressed: () {
              ref.read(campaignIdProvider.notifier).setCampaign(null);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CampaignInputScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authStateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(charactersProvider);
          await ref.read(charactersProvider.future);
        },
        child: ListView(
          children: [
            const SearchBarField(),
            const SizedBox(height: 6),
            if (showRecent) ...[
              SectionBackground(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    GroupHeader(number: '00', label: 'Recently viewed'),
                    RecentlyViewedRow(),
                    SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SectionBackground(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GroupHeader(number: '01', label: campaignLabel),
                  _CharactersRow(
                    characters: characters,
                    query: query,
                    onTitleTap: () => _openCharactersGrid(context, ref),
                  ),
                  // Coming-soon rows are hidden entirely while the user
                  // is searching — nothing meaningful to match against.
                  if (!searching) ...[
                    CategoryRow(
                      title: 'Locations',
                      onTitleTap: null,
                      child: const ComingSoonTile(icon: Icons.public),
                    ),
                    CategoryRow(
                      title: 'Events',
                      onTitleTap: null,
                      child: const ComingSoonTile(icon: Icons.event),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionBackground(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GroupHeader(
                    number: '02',
                    label: 'System',
                    trailing: HomeSystemSortMenu(),
                  ),
                  _SystemRow<dynamic>(
              title: 'Weapons',
              icon: Icons.flash_on,
              async: weapons,
              query: query,
              onTitleTap: () => _openWeaponsTypeScreen(context),
              nameOf: (w) => (w as dynamic).name as String,
              tileBuilder: (item) => WeaponTile(
                weapon: item,
                onTap: () {
                  ref
                      .read(recentlyViewedProvider.notifier)
                      .record('weapon', item.name as String);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WeaponViewScreen(weapon: item),
                    ),
                  );
                },
              ),
            ),
            _SystemRow<dynamic>(
              title: 'Armor',
              icon: Icons.shield,
              async: armors,
              query: query,
              onTitleTap: () => _openArmorsTypeScreen(context),
              nameOf: (a) => (a as dynamic).name as String,
              tileBuilder: (item) => ArmorTile(
                armor: item,
                onTap: () {
                  ref
                      .read(recentlyViewedProvider.notifier)
                      .record('armor', item.name as String);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArmorViewScreen(armor: item),
                    ),
                  );
                },
              ),
            ),
            _SystemRow<dynamic>(
              title: 'Gear',
              icon: Icons.inventory_2,
              async: gear,
              query: query,
              onTitleTap: () => _openGearTypeScreen(context),
              nameOf: (g) => (g as dynamic).name as String,
              tileBuilder: (item) => GearTile(
                gear: item,
                onTap: () {
                  ref
                      .read(recentlyViewedProvider.notifier)
                      .record('gear', item.name as String);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GearViewScreen(gear: item),
                    ),
                  );
                },
              ),
            ),
            _SystemRow<dynamic>(
              title: 'Vehicles',
              icon: Icons.directions_car,
              async: vehicles,
              query: query,
              onTitleTap: () => _openVehiclesTypeScreen(context),
              nameOf: (v) => (v as dynamic).name as String,
              tileBuilder: (item) => VehicleTile(
                vehicle: item,
                onTap: () {
                  ref
                      .read(recentlyViewedProvider.notifier)
                      .record('vehicle', item.name as String);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VehicleViewScreen(vehicle: item),
                    ),
                  );
                },
              ),
            ),
            _SystemRow<dynamic>(
              title: 'Starships',
              icon: Icons.rocket_launch,
              async: starships,
              query: query,
              onTitleTap: () => _openStarshipsTypeScreen(context),
              nameOf: (s) => (s as dynamic).name as String,
              tileBuilder: (item) => StarshipTile(
                starship: item,
                onTap: () {
                  ref
                      .read(recentlyViewedProvider.notifier)
                      .record('starship', item.name as String);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StarshipViewScreen(starship: item),
                    ),
                  );
                },
              ),
            ),
            _SystemRow<dynamic>(
              title: 'Beasts',
              icon: Icons.pets,
              async: beasts,
              query: query,
              onTitleTap: () => _openBeastsTypeScreen(context),
              nameOf: (b) => (b as dynamic).name as String,
              tileBuilder: (item) => BeastTile(
                beast: item,
                onTap: () {
                  ref
                      .read(recentlyViewedProvider.notifier)
                      .record('beast', item.name as String);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BeastViewScreen(beast: item),
                    ),
                  );
                },
              ),
            ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String _resolveCampaignLabel(WidgetRef ref) {
  final id = ref.watch(campaignIdProvider);
  if (id == null || id.isEmpty) return 'Campaign';
  final campaignsAsync = ref.watch(campaignsProvider);
  return campaignsAsync.maybeWhen(
    data: (List<Campaign> list) {
      for (final c in list) {
        if (c.id == id) return c.name;
      }
      return 'Campaign';
    },
    orElse: () => 'Campaign',
  );
}

/// Characters row needs a name + author predicate, so it gets its own
/// small wrapper (rather than the generic _SystemRow).
class _CharactersRow extends ConsumerWidget {
  final AsyncValue<List<Character>> characters;
  final String query;
  final VoidCallback onTitleTap;

  const _CharactersRow({
    required this.characters,
    required this.query,
    required this.onTitleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CategoryRow(
      title: 'Characters',
      onTitleTap: onTitleTap,
      child: characters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text('Failed to load characters: $error'),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text('No characters in this campaign.'),
              ),
            );
          }
          final filtered = query.isEmpty
              ? all
              : all.where((c) {
                  final lq = query.toLowerCase();
                  if (c.name.toLowerCase().contains(lq)) return true;
                  final owner = c.author?.username.toLowerCase();
                  return owner != null && owner.contains(lq);
                }).toList(growable: false);
          if (filtered.isEmpty) return const _NoMatchTile();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            primary: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = filtered[i];
              return SizedBox(
                width: 120,
                child: CharacterTile(
                  character: c,
                  onTap: () {
                    ref
                        .read(recentlyViewedProvider.notifier)
                        .record('character', c.id);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CharacterBioScreen(character: c),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Generic system-category row — name-only search; common shape across
/// all six system rows. The `dynamic` typing dodges the per-model type
/// gymnastics; each row passes a `nameOf` accessor (`(w) => w.name`)
/// so filtering and tile building stay strongly tied to the underlying
/// model at the call site.
class _SystemRow<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<dynamic>> async;
  final String query;
  final VoidCallback onTitleTap;
  final String Function(dynamic item) nameOf;
  final Widget Function(dynamic item) tileBuilder;

  const _SystemRow({
    super.key,
    required this.title,
    required this.icon,
    required this.async,
    required this.query,
    required this.onTitleTap,
    required this.nameOf,
    required this.tileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CategoryRow(
      title: title,
      onTitleTap: onTitleTap,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(child: Text('Failed: $error')),
        ),
        data: (all) {
          if (all.isEmpty) return ComingSoonTile(icon: icon);
          final filtered = query.isEmpty
              ? all
              : all
                  .where((item) =>
                      nameOf(item).toLowerCase().contains(query.toLowerCase()))
                  .toList(growable: false);
          if (filtered.isEmpty) return const _NoMatchTile();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            primary: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(
              width: 120,
              child: tileBuilder(filtered[i]),
            ),
          );
        },
      ),
    );
  }
}

/// Small inkDim text rendered in the row's child slot when search has
/// no matches in that category — the row title + chevron stay visible.
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

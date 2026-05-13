import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/armor_view_screen.dart';
import 'package:swrpg_quickypedia/screens/armors_type_screen.dart';
import 'package:swrpg_quickypedia/screens/campaign_input_screen.dart';
import 'package:swrpg_quickypedia/screens/category_grid_screen.dart';
import 'package:swrpg_quickypedia/screens/character_bio_screen.dart';
import 'package:swrpg_quickypedia/screens/gear_type_screen.dart';
import 'package:swrpg_quickypedia/screens/gear_view_screen.dart';
import 'package:swrpg_quickypedia/screens/vehicle_view_screen.dart';
import 'package:swrpg_quickypedia/screens/vehicles_type_screen.dart';
import 'package:swrpg_quickypedia/screens/weapon_view_screen.dart';
import 'package:swrpg_quickypedia/screens/weapons_type_screen.dart';
import 'package:swrpg_quickypedia/widgets/armor_tile.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/character_tile.dart';
import 'package:swrpg_quickypedia/widgets/gear_tile.dart';
import 'package:swrpg_quickypedia/widgets/vehicle_tile.dart';
import 'package:swrpg_quickypedia/widgets/weapon_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openCharactersGrid(BuildContext context) {
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
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => CharacterBioScreen(character: c),
              ),
            ),
          ),
          searchHint: 'Search by name or owner',
        ),
      ),
    );
  }

  void _openComingSoon(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryGridScreen<Never>.comingSoon(
          title: title,
          icon: icon,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(charactersProvider);
    final weapons = ref.watch(weaponsProvider);
    final armors = ref.watch(armorsProvider);
    final gear = ref.watch(gearProvider);
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SWRPG Quickypedia'),
        actions: [
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
            CategoryRow(
              title: 'Characters',
              onTitleTap: () => _openCharactersGrid(context),
              child: characters.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text('Failed to load characters: $error'),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Text('No characters in this campaign.'),
                      ),
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return SizedBox(
                        width: 120,
                        child: CharacterTile(
                          character: c,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CharacterBioScreen(character: c),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            CategoryRow(
              title: 'Locations',
              onTitleTap: () =>
                  _openComingSoon(context, 'Locations', Icons.public),
              child: const ComingSoonTile(icon: Icons.public),
            ),
            CategoryRow(
              title: 'Events',
              onTitleTap: () =>
                  _openComingSoon(context, 'Events', Icons.event),
              child: const ComingSoonTile(icon: Icons.event),
            ),
            CategoryRow(
              title: 'Weapons',
              onTitleTap: () => _openWeaponsTypeScreen(context),
              child: weapons.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text('Failed: $error')),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const ComingSoonTile(icon: Icons.flash_on);
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final w = list[i];
                      return SizedBox(
                        width: 120,
                        child: WeaponTile(
                          weapon: w,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WeaponViewScreen(weapon: w),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            CategoryRow(
              title: 'Armor',
              onTitleTap: () => _openArmorsTypeScreen(context),
              child: armors.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text('Failed: $error')),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const ComingSoonTile(icon: Icons.shield);
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final a = list[i];
                      return SizedBox(
                        width: 120,
                        child: ArmorTile(
                          armor: a,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArmorViewScreen(armor: a),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            CategoryRow(
              title: 'Gear',
              onTitleTap: () => _openGearTypeScreen(context),
              child: gear.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text('Failed: $error')),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const ComingSoonTile(icon: Icons.inventory_2);
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final g = list[i];
                      return SizedBox(
                        width: 120,
                        child: GearTile(
                          gear: g,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GearViewScreen(gear: g),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            CategoryRow(
              title: 'Vehicles',
              onTitleTap: () => _openVehiclesTypeScreen(context),
              child: vehicles.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text('Failed: $error')),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const ComingSoonTile(icon: Icons.directions_car);
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final v = list[i];
                      return SizedBox(
                        width: 120,
                        child: VehicleTile(
                          vehicle: v,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VehicleViewScreen(vehicle: v),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


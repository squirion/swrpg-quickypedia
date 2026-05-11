import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/character.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/campaign_input_screen.dart';
import 'package:swrpg_quickypedia/screens/category_grid_screen.dart';
import 'package:swrpg_quickypedia/screens/character_bio_screen.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/character_tile.dart';
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

  void _openWeaponsGrid(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryGridScreen<Weapon>(
          title: 'Weapons',
          icon: Icons.flash_on,
          watchItems: (ref) => ref.watch(weaponsProvider),
          matchesQuery: (w, q) {
            final lq = q.toLowerCase();
            return w.name.toLowerCase().contains(lq);
          },
          itemBuilder: (ctx, w) => WeaponTile(
            weapon: w,
            onTap: () => showDialog<void>(
              context: ctx,
              builder: (_) => AlertDialog(
                title: Text(w.name),
                content: const Text('Weapon view coming soon.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          searchHint: 'Search weapons',
          appBarActionsBuilder: (ctx, ref) {
            final scrape = ref.watch(weaponsScrapeProvider);
            final running = scrape is ScrapeRunning;
            return [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Fetch from wiki',
                onPressed: running
                    ? null
                    : () => ref
                        .read(weaponsScrapeProvider.notifier)
                        .refresh(),
              ),
            ];
          },
          belowAppBarBuilder: (ctx, ref) {
            final scrape = ref.watch(weaponsScrapeProvider);
            return _WeaponsScrapeBanner(state: scrape);
          },
          emptyStateBuilder: (ctx, ref) {
            final scrape = ref.watch(weaponsScrapeProvider);
            final running = scrape is ScrapeRunning;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on,
                        size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No weapons cached yet',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pull the catalogue from the SWRPG FFG wiki to '
                      'populate this grid. The data is cached on-device '
                      'and only refetched when you tap refresh.',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Fetch weapons from wiki'),
                      onPressed: running
                          ? null
                          : () => ref
                              .read(weaponsScrapeProvider.notifier)
                              .refresh(),
                    ),
                    if (scrape is ScrapeError) ...[
                      const SizedBox(height: 12),
                      Text(
                        scrape.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(charactersProvider);

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
              onTitleTap: () => _openWeaponsGrid(context),
              child: const ComingSoonTile(icon: Icons.flash_on),
            ),
            CategoryRow(
              title: 'Armor',
              onTitleTap: () =>
                  _openComingSoon(context, 'Armor', Icons.shield),
              child: const ComingSoonTile(icon: Icons.shield),
            ),
            CategoryRow(
              title: 'Gear',
              onTitleTap: () =>
                  _openComingSoon(context, 'Gear', Icons.inventory_2),
              child: const ComingSoonTile(icon: Icons.inventory_2),
            ),
            CategoryRow(
              title: 'Vehicles',
              onTitleTap: () => _openComingSoon(
                  context, 'Vehicles', Icons.directions_car),
              child: const ComingSoonTile(icon: Icons.directions_car),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin status strip rendered below the AppBar on the weapons grid.
/// Shows a progress bar + "Fetched N / M" label while scraping, and an
/// error message bar (with retry button) when the scrape failed.
class _WeaponsScrapeBanner extends ConsumerWidget
    implements PreferredSizeWidget {
  final ScrapeState state;
  const _WeaponsScrapeBanner({required this.state});

  @override
  Size get preferredSize {
    if (state is ScrapeRunning) return const Size.fromHeight(28);
    if (state is ScrapeError) return const Size.fromHeight(40);
    return Size.zero;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state;
    if (s is ScrapeRunning) {
      final indeterminate = s.total == 0;
      final value = indeterminate ? null : s.done / s.total;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: value),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                indeterminate
                    ? 'Discovering weapons…'
                    : 'Fetched ${s.done} / ${s.total}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ],
      );
    }
    if (s is ScrapeError) {
      return Container(
        color: Colors.red.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Scrape failed: ${s.message}',
                style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(weaponsScrapeProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

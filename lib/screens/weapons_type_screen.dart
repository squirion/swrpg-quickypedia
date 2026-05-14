import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/category_grid_screen.dart';
import 'package:swrpg_quickypedia/screens/weapon_view_screen.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/download_from_cloud_button.dart';
import 'package:swrpg_quickypedia/widgets/search_bar_field.dart';
import 'package:swrpg_quickypedia/widgets/weapon_sort_menu.dart';
import 'package:swrpg_quickypedia/widgets/weapon_tile.dart';

/// Intermediate screen for weapons: one horizontal row per weapon type
/// (skill), mirroring the home-screen format. Tapping a row title opens
/// a filtered grid containing only that type.
class WeaponsTypeScreen extends ConsumerWidget {
  const WeaponsTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weaponsAsync = ref.watch(weaponsProvider);
    final scrape = ref.watch(weaponsScrapeProvider);
    final running = scrape is ScrapeRunning;
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weapons'),
        actions: [
          const DownloadFromCloudButton(),
          const WeaponSortMenu(),
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Fetch from wiki',
              onPressed: running ? null : () => _runScrape(context, ref),
            ),
        ],
        bottom: _WeaponsScrapeBanner(state: scrape),
      ),
      body: Column(
        children: [
          const SearchBarField(),
          Expanded(
            child: weaponsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load weapons: $error')),
              data: (all) {
                if (all.isEmpty) {
                  return _emptyState(context, ref, running, scrape);
                }
                return _buildRows(context, ref, all, query);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRows(
      BuildContext context, WidgetRef ref, List<Weapon> all, String query) {
    final groups = _groupBySkill(all);
    return ListView.builder(
      itemCount: kWeaponSkillOrder.length,
      itemBuilder: (_, i) {
        final type = kWeaponSkillOrder[i];
        final items = groups[type] ?? const <Weapon>[];
        if (items.isEmpty) return const SizedBox.shrink();
        final filtered = query.isEmpty
            ? items
            : items
                .where((w) =>
                    w.name.toLowerCase().contains(query.toLowerCase()))
                .toList(growable: false);
        return CategoryRow(
          title: type,
          onTitleTap: () => _openTypeGrid(context, ref, type, items),
          child: filtered.isEmpty
              ? const _NoMatchTile()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, j) {
                    final w = filtered[j];
                    return SizedBox(
                      width: 120,
                      child: WeaponTile(
                        weapon: w,
                        onTap: () {
                          ref
                              .read(recentlyViewedProvider.notifier)
                              .record('weapon', w.name);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WeaponViewScreen(weapon: w),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref, bool running,
      ScrapeState scrape) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flash_on, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No weapons cached yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Pull the catalogue from the SWRPG FFG wiki to populate '
              'these rows. The data is cached on-device and only '
              'refetched when you tap refresh.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade700),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.travel_explore),
                label: const Text('Fetch from wiki'),
                onPressed:
                    running ? null : () => _runScrape(context, ref),
              ),
            ],
            if (scrape is ScrapeError) ...[
              const SizedBox(height: 12),
              Text(scrape.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
    );
  }

  void _openTypeGrid(BuildContext context, WidgetRef ref, String type,
      List<Weapon> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryGridScreen<Weapon>(
          title: type,
          icon: Icons.flash_on,
          watchItems: (ref) {
            final all = ref.watch(weaponsProvider);
            return all.whenData((list) =>
                list.where((w) => _normalizeSkill(w.skill) == type).toList());
          },
          matchesQuery: (w, q) =>
              w.name.toLowerCase().contains(q.toLowerCase()),
          itemBuilder: (ctx, w) => WeaponTile(
            weapon: w,
            onTap: () {
              ref
                  .read(recentlyViewedProvider.notifier)
                  .record('weapon', w.name);
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => WeaponViewScreen(weapon: w),
                ),
              );
            },
          ),
          searchHint: 'Search $type',
          appBarActionsBuilder: (_, _) => const [WeaponSortMenu()],
        ),
      ),
    );
  }

  Future<void> _pushCloud(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Pushing databases to cloud…')),
    );
    final result =
        await ref.read(cloudSyncProvider.notifier).pushDatabases();
    if (!context.mounted) return;
    _showSyncResult(context, result);
  }

  void _showSyncResult(BuildContext context, CloudSyncResult result) {
    final summary = result.errors.isEmpty
        ? 'Pushed ${result.succeeded} '
            '${result.succeeded == 1 ? 'file' : 'files'}'
            '${result.skipped > 0 ? ' (${result.skipped} skipped)' : ''}.'
        : 'Some files failed:\n${result.errors.join('\n')}';
    if (result.errors.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cloud push report'),
          content: SingleChildScrollView(child: Text(summary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(summary)));
    }
  }

  Future<void> _runScrape(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fetch weapons from wiki?'),
        content: const Text(
          'This will scrape every weapon page on the SWRPG FFG Fandom '
          'wiki. The process can take a few minutes and uses your data '
          'connection. Existing cached weapons will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Fetch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final result = await ref.read(weaponsScrapeProvider.notifier).refresh();
    if (!context.mounted) return;

    final hasError =
        result.weaponsError != null || result.qualitiesError != null;

    if (hasError) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scrape report'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result.weaponsError == null
                    ? 'Weapons: saved ${result.weapons}.'
                    : 'Weapons FAILED:\n${result.weaponsError}'),
                const SizedBox(height: 12),
                Text(result.qualitiesError == null
                    ? 'Qualities: saved ${result.qualities}.'
                    : 'Qualities FAILED:\n${result.qualitiesError}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${result.weapons} weapons · ${result.qualities} qualities',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Push to cloud',
          onPressed: () => _pushCloud(context, ref),
        ),
      ),
    );
  }
}

/// Display order for weapon-type rows. Anything not in this list (or with
/// a null skill) is bucketed under `kWeaponSkillOther`.
const String kWeaponSkillOther = 'Other';
const List<String> kWeaponSkillOrder = [
  'Brawl',
  'Melee',
  'Lightsaber',
  'Ranged (Light)',
  'Ranged (Heavy)',
  'Gunnery',
  kWeaponSkillOther,
];

Map<String, List<Weapon>> _groupBySkill(List<Weapon> all) {
  final out = <String, List<Weapon>>{};
  for (final w in all) {
    final key = _normalizeSkill(w.skill);
    out.putIfAbsent(key, () => []).add(w);
  }
  return out;
}

/// Map raw wiki skill strings to one of [kWeaponSkillOrder]. Wiki text
/// sometimes carries trailing whitespace, alt casing, or stray
/// punctuation that we want to fold into the canonical bucket name.
String _normalizeSkill(String? skill) {
  if (skill == null) return kWeaponSkillOther;
  final s = skill.trim();
  if (s.isEmpty) return kWeaponSkillOther;
  final lower = s.toLowerCase();
  if (lower.contains('ranged (light)')) return 'Ranged (Light)';
  if (lower.contains('ranged (heavy)')) return 'Ranged (Heavy)';
  if (lower.startsWith('ranged')) return 'Ranged (Light)';
  if (lower.contains('lightsaber')) return 'Lightsaber';
  if (lower.contains('gunnery')) return 'Gunnery';
  if (lower.contains('melee')) return 'Melee';
  if (lower.contains('brawl')) return 'Brawl';
  return kWeaponSkillOther;
}

/// "No matches" placeholder shown in a section's tile slot when the
/// active search has zero matches in that section.
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

/// Reuses the in-app scrape banner styling — copied here instead of
/// imported because home_screen.dart's banner is private to that file.
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

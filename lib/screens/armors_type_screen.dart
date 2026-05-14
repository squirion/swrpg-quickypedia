import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/armor.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/armor_view_screen.dart';
import 'package:swrpg_quickypedia/screens/category_grid_screen.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/armor_sort_menu.dart';
import 'package:swrpg_quickypedia/widgets/armor_tile.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/download_from_cloud_button.dart';
import 'package:swrpg_quickypedia/widgets/search_bar_field.dart';

/// Intermediate screen for armors: one horizontal row per Fandom
/// subcategory, mirroring [WeaponsTypeScreen]. Tapping a row title
/// opens a filtered grid containing only that bucket.
class ArmorsTypeScreen extends ConsumerWidget {
  const ArmorsTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armorsAsync = ref.watch(armorsProvider);
    final scrape = ref.watch(armorsScrapeProvider);
    final running = scrape is ScrapeRunning;
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Armor'),
        actions: [
          const DownloadFromCloudButton(),
          const ArmorSortMenu(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Fetch from wiki',
            onPressed: running ? null : () => _runScrape(context, ref),
          ),
        ],
        bottom: _ArmorsScrapeBanner(state: scrape),
      ),
      body: Column(
        children: [
          const SearchBarField(),
          Expanded(
            child: armorsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load armors: $error')),
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
      BuildContext context, WidgetRef ref, List<Armor> all, String query) {
    final groups = _groupByCategory(all);
    return ListView.builder(
      itemCount: kArmorCategoryOrder.length,
      itemBuilder: (_, i) {
        final type = kArmorCategoryOrder[i];
        final items = groups[type] ?? const <Armor>[];
        if (items.isEmpty) return const SizedBox.shrink();
        final filtered = query.isEmpty
            ? items
            : items
                .where((a) =>
                    a.name.toLowerCase().contains(query.toLowerCase()))
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
                    final a = filtered[j];
                    return SizedBox(
                      width: 120,
                      child: ArmorTile(
                        armor: a,
                        onTap: () {
                          ref
                              .read(recentlyViewedProvider.notifier)
                              .record('armor', a.name);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ArmorViewScreen(armor: a),
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
            Icon(Icons.shield, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No armor cached yet',
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.travel_explore),
              label: const Text('Fetch from wiki'),
              onPressed:
                  running ? null : () => _runScrape(context, ref),
            ),
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
      List<Armor> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryGridScreen<Armor>(
          title: type,
          icon: Icons.shield,
          watchItems: (ref) {
            final all = ref.watch(armorsProvider);
            return all.whenData((list) =>
                list.where((a) => _categoryOf(a) == type).toList());
          },
          matchesQuery: (a, q) =>
              a.name.toLowerCase().contains(q.toLowerCase()),
          itemBuilder: (ctx, a) => ArmorTile(
            armor: a,
            onTap: () {
              ref
                  .read(recentlyViewedProvider.notifier)
                  .record('armor', a.name);
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => ArmorViewScreen(armor: a),
                ),
              );
            },
          ),
          searchHint: 'Search $type',
          appBarActionsBuilder: (_, _) => const [ArmorSortMenu()],
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
        title: const Text('Fetch armor from wiki?'),
        content: const Text(
          'This will scrape every armor page on the SWRPG FFG Fandom '
          'wiki, across all 6 subcategories. The process can take a '
          'few minutes and uses your data connection. Existing cached '
          'armor will be replaced.',
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

    final result = await ref.read(armorsScrapeProvider.notifier).refresh();
    if (!context.mounted) return;

    final hasError =
        result.armorsError != null || result.qualitiesError != null;

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
                Text(result.armorsError == null
                    ? 'Armor: saved ${result.armors}.'
                    : 'Armor FAILED:\n${result.armorsError}'),
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
          'Saved ${result.armors} armors · ${result.qualities} qualities',
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

/// Resolve an armor to one of [kArmorCategoryOrder]. Anything with a
/// missing or unknown category falls into [kArmorCategoryOther].
String _categoryOf(Armor a) {
  final c = a.category;
  if (c == null) return kArmorCategoryOther;
  return kArmorCategoryOrder.contains(c) ? c : kArmorCategoryOther;
}

Map<String, List<Armor>> _groupByCategory(List<Armor> all) {
  final out = <String, List<Armor>>{};
  for (final a in all) {
    out.putIfAbsent(_categoryOf(a), () => []).add(a);
  }
  return out;
}

/// Scrape progress / error banner, same shape as the weapons banner.
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

class _ArmorsScrapeBanner extends ConsumerWidget
    implements PreferredSizeWidget {
  final ScrapeState state;
  const _ArmorsScrapeBanner({required this.state});

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
                    ? 'Discovering armor…'
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
                  ref.read(armorsScrapeProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

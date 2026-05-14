import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/gear.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/category_grid_screen.dart';
import 'package:swrpg_quickypedia/screens/gear_view_screen.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/download_from_cloud_button.dart';
import 'package:swrpg_quickypedia/widgets/gear_sort_menu.dart';
import 'package:swrpg_quickypedia/widgets/gear_tile.dart';
import 'package:swrpg_quickypedia/widgets/search_bar_field.dart';

/// Intermediate screen for gear: one row per Fandom article-body
/// section in [kGearCategoryOrder]. Tapping a row title opens a
/// filtered grid containing only that bucket.
class GearTypeScreen extends ConsumerWidget {
  const GearTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gearAsync = ref.watch(gearProvider);
    final scrape = ref.watch(gearScrapeProvider);
    final running = scrape is ScrapeRunning;
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gear'),
        actions: [
          const DownloadFromCloudButton(),
          const GearSortMenu(),
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Fetch from wiki',
              onPressed: running ? null : () => _runScrape(context, ref),
            ),
        ],
        bottom: _GearScrapeBanner(state: scrape),
      ),
      body: Column(
        children: [
          const SearchBarField(),
          Expanded(
            child: gearAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load gear: $error')),
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
      BuildContext context, WidgetRef ref, List<Gear> all, String query) {
    final groups = _groupByCategory(all);
    return ListView.builder(
      itemCount: kGearCategoryOrder.length,
      itemBuilder: (_, i) {
        final type = kGearCategoryOrder[i];
        final items = groups[type] ?? const <Gear>[];
        if (items.isEmpty) return const SizedBox.shrink();
        final filtered = query.isEmpty
            ? items
            : items
                .where((g) =>
                    g.name.toLowerCase().contains(query.toLowerCase()))
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
                    final g = filtered[j];
                    return SizedBox(
                      width: 120,
                      child: GearTile(
                        gear: g,
                        onTap: () {
                          ref
                              .read(recentlyViewedProvider.notifier)
                              .record('gear', g.name);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GearViewScreen(gear: g),
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
            Icon(Icons.inventory_2, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No gear cached yet',
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
      List<Gear> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryGridScreen<Gear>(
          title: type,
          icon: Icons.inventory_2,
          watchItems: (ref) {
            final all = ref.watch(gearProvider);
            return all.whenData((list) =>
                list.where((g) => _categoryOf(g) == type).toList());
          },
          matchesQuery: (g, q) =>
              g.name.toLowerCase().contains(q.toLowerCase()),
          itemBuilder: (ctx, g) => GearTile(
            gear: g,
            onTap: () {
              ref
                  .read(recentlyViewedProvider.notifier)
                  .record('gear', g.name);
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => GearViewScreen(gear: g),
                ),
              );
            },
          ),
          searchHint: 'Search $type',
          appBarActionsBuilder: (_, _) => const [GearSortMenu()],
        ),
      ),
    );
  }

  Future<void> _pushCloud(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Pushing databases to cloud…')),
    );
    final result = await ref.read(cloudSyncProvider.notifier).pushDatabases();
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
        title: const Text('Fetch gear from wiki?'),
        content: const Text(
          'This will scrape every gear page on the SWRPG FFG Fandom '
          'wiki, across all 18 sections. The process can take several '
          'minutes and uses your data connection. Existing cached gear '
          'will be replaced.',
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

    final result = await ref.read(gearScrapeProvider.notifier).refresh();
    if (!context.mounted) return;

    final hasError = result.gearError != null ||
        result.qualitiesError != null ||
        result.failedPages > 0;

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
                Text(result.gearError == null
                    ? 'Gear: saved ${result.gear}.'
                    : 'Gear FAILED:\n${result.gearError}'),
                if (result.failedPages > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${result.failedPages} page(s) could not be fetched '
                    '(network blip during scrape). Tap Fetch again to '
                    'fill in the missing items.',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ],
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
          'Saved ${result.gear} gear items · ${result.qualities} qualities',
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

String _categoryOf(Gear g) {
  final c = g.category;
  if (c == null) return kGearCategoryOther;
  return kGearCategoryOrder.contains(c) ? c : kGearCategoryOther;
}

Map<String, List<Gear>> _groupByCategory(List<Gear> all) {
  final out = <String, List<Gear>>{};
  for (final g in all) {
    out.putIfAbsent(_categoryOf(g), () => []).add(g);
  }
  return out;
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

class _GearScrapeBanner extends ConsumerWidget
    implements PreferredSizeWidget {
  final ScrapeState state;
  const _GearScrapeBanner({required this.state});

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
                    ? 'Discovering gear…'
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
                  ref.read(gearScrapeProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/beast.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/beast_view_screen.dart';
import 'package:swrpg_quickypedia/screens/category_grid_screen.dart';
import 'package:swrpg_quickypedia/theme.dart';
import 'package:swrpg_quickypedia/widgets/beast_sort_menu.dart';
import 'package:swrpg_quickypedia/widgets/beast_tile.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/download_from_cloud_button.dart';
import 'package:swrpg_quickypedia/widgets/search_bar_field.dart';

class BeastsTypeScreen extends ConsumerWidget {
  const BeastsTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beastsAsync = ref.watch(beastsProvider);
    final scrape = ref.watch(beastsScrapeProvider);
    final running = scrape is ScrapeRunning;
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beasts'),
        actions: [
          const DownloadFromCloudButton(),
          const BeastSortMenu(),
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Fetch from wiki',
              onPressed: running ? null : () => _runScrape(context, ref),
            ),
        ],
        bottom: _BeastsScrapeBanner(state: scrape),
      ),
      body: Column(
        children: [
          const SearchBarField(),
          Expanded(
            child: beastsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load beasts: $error')),
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
      BuildContext context, WidgetRef ref, List<Beast> all, String query) {
    final groups = _groupByCategory(all);
    return ListView.builder(
      itemCount: kBeastCategoryOrder.length,
      itemBuilder: (_, i) {
        final type = kBeastCategoryOrder[i];
        final items = groups[type] ?? const <Beast>[];
        if (items.isEmpty) return const SizedBox.shrink();
        final filtered = query.isEmpty
            ? items
            : items
                .where((b) =>
                    b.name.toLowerCase().contains(query.toLowerCase()))
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
                    final b = filtered[j];
                    return SizedBox(
                      width: 120,
                      child: BeastTile(
                        beast: b,
                        onTap: () {
                          ref
                              .read(recentlyViewedProvider.notifier)
                              .record('beast', b.name);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BeastViewScreen(beast: b),
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
            Icon(Icons.pets, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No beasts cached yet',
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
      List<Beast> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryGridScreen<Beast>(
          title: type,
          icon: Icons.pets,
          watchItems: (ref) {
            final all = ref.watch(beastsProvider);
            return all.whenData((list) =>
                list.where((b) => _categoryOf(b) == type).toList());
          },
          matchesQuery: (b, q) =>
              b.name.toLowerCase().contains(q.toLowerCase()),
          itemBuilder: (ctx, b) => BeastTile(
            beast: b,
            onTap: () {
              ref
                  .read(recentlyViewedProvider.notifier)
                  .record('beast', b.name);
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => BeastViewScreen(beast: b),
                ),
              );
            },
          ),
          searchHint: 'Search $type',
          appBarActionsBuilder: (_, _) => const [BeastSortMenu()],
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
        title: const Text('Fetch beasts from wiki?'),
        content: const Text(
          'This will scrape every beast page on the SWRPG FFG Fandom '
          'wiki, across all 3 sections. The process uses your data '
          'connection. Existing cached beasts will be replaced.',
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

    final result = await ref.read(beastsScrapeProvider.notifier).refresh();
    if (!context.mounted) return;

    final hasError =
        result.beastsError != null || result.failedPages > 0;

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
                Text(result.beastsError == null
                    ? 'Beasts: saved ${result.beasts}.'
                    : 'Beasts FAILED:\n${result.beastsError}'),
                if (result.failedPages > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${result.failedPages} page(s) could not be fetched '
                    '(network blip during scrape). Tap Fetch again to '
                    'fill in the missing items.',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ],
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
        content: Text('Saved ${result.beasts} beasts'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Push to cloud',
          onPressed: () => _pushCloud(context, ref),
        ),
      ),
    );
  }
}

String _categoryOf(Beast b) {
  final c = b.category;
  if (c == null) return kBeastCategoryOther;
  return kBeastCategoryOrder.contains(c) ? c : kBeastCategoryOther;
}

Map<String, List<Beast>> _groupByCategory(List<Beast> all) {
  final out = <String, List<Beast>>{};
  for (final b in all) {
    out.putIfAbsent(_categoryOf(b), () => []).add(b);
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

class _BeastsScrapeBanner extends ConsumerWidget
    implements PreferredSizeWidget {
  final ScrapeState state;
  const _BeastsScrapeBanner({required this.state});

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
                    ? 'Discovering beasts…'
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
                  ref.read(beastsScrapeProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

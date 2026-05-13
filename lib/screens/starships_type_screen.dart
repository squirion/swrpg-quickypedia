import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/models/starship.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/screens/category_grid_screen.dart';
import 'package:swrpg_quickypedia/screens/starship_view_screen.dart';
import 'package:swrpg_quickypedia/widgets/category_row.dart';
import 'package:swrpg_quickypedia/widgets/starship_sort_menu.dart';
import 'package:swrpg_quickypedia/widgets/starship_tile.dart';

class StarshipsTypeScreen extends ConsumerWidget {
  const StarshipsTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starshipsAsync = ref.watch(starshipsProvider);
    final scrape = ref.watch(starshipsScrapeProvider);
    final running = scrape is ScrapeRunning;

    final cloud = ref.watch(cloudSyncProvider);
    final cloudBusy = cloud is CloudSyncRunning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Starships'),
        actions: [
          PopupMenuButton<String>(
            icon: cloudBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Cloud sync',
            onSelected: (action) => switch (action) {
              'pull' => _pullCloud(context, ref),
              'push' => _pushCloud(context, ref),
              'test' => _testCloud(context, ref),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'pull',
                child: ListTile(
                  leading: Icon(Icons.cloud_download_outlined),
                  title: Text('Pull databases'),
                  subtitle: Text('Replace local with cloud'),
                ),
              ),
              PopupMenuItem(
                value: 'push',
                child: ListTile(
                  leading: Icon(Icons.cloud_upload_outlined),
                  title: Text('Push databases'),
                  subtitle: Text('Share local with cloud'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'test',
                child: ListTile(
                  leading: Icon(Icons.cloud_done_outlined),
                  title: Text('Test connection'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Fetch from wiki',
            onPressed: running ? null : () => _runScrape(context, ref),
          ),
        ],
        bottom: _StarshipsScrapeBanner(state: scrape),
      ),
      body: starshipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load starships: $error')),
        data: (all) {
          if (all.isEmpty) return _emptyState(context, ref, running, scrape);
          return _buildRows(context, all);
        },
      ),
    );
  }

  Widget _buildRows(BuildContext context, List<Starship> all) {
    final groups = _groupByCategory(all);
    return ListView.builder(
      itemCount: kStarshipCategoryOrder.length,
      itemBuilder: (_, i) {
        final type = kStarshipCategoryOrder[i];
        final items = groups[type] ?? const <Starship>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return CategoryRow(
          title: type,
          onTitleTap: () => _openTypeGrid(context, type, items),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, j) {
              final s = items[j];
              return SizedBox(
                width: 120,
                child: StarshipTile(
                  starship: s,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StarshipViewScreen(starship: s),
                    ),
                  ),
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
            Icon(Icons.rocket_launch,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No starships cached yet',
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
            FilledButton.icon(
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Pull from cloud'),
              onPressed:
                  running ? null : () => _pullCloud(context, ref),
            ),
            const SizedBox(height: 8),
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

  void _openTypeGrid(BuildContext context, String type, List<Starship> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryGridScreen<Starship>(
          title: type,
          icon: Icons.rocket_launch,
          watchItems: (ref) {
            final all = ref.watch(starshipsProvider);
            return all.whenData((list) =>
                list.where((s) => _categoryOf(s) == type).toList());
          },
          matchesQuery: (s, q) =>
              s.name.toLowerCase().contains(q.toLowerCase()),
          itemBuilder: (ctx, s) => StarshipTile(
            starship: s,
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => StarshipViewScreen(starship: s),
              ),
            ),
          ),
          searchHint: 'Search $type',
          appBarActionsBuilder: (_, _) => const [StarshipSortMenu()],
        ),
      ),
    );
  }

  Future<void> _pullCloud(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Pulling databases from cloud…')),
    );
    final result = await ref.read(cloudSyncProvider.notifier).pullDatabases();
    if (!context.mounted) return;
    _showSyncResult(context, result);
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
    final verb = result.direction == 'pull' ? 'Pulled' : 'Pushed';
    final summary = result.errors.isEmpty
        ? '$verb ${result.succeeded} '
            '${result.succeeded == 1 ? 'file' : 'files'}'
            '${result.skipped > 0 ? ' (${result.skipped} skipped)' : ''}.'
        : 'Some files failed:\n${result.errors.join('\n')}';
    if (result.errors.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Cloud ${result.direction} report'),
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

  Future<void> _testCloud(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(githubDataRepoProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking cloud connection…')),
    );
    final result = await repo.healthCheck();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.ok ? 'Cloud OK' : 'Cloud unreachable'),
        content: SingleChildScrollView(child: Text(result.detail)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _runScrape(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fetch starships from wiki?'),
        content: const Text(
          'This will scrape every starship page on the SWRPG FFG '
          'Fandom wiki, across all 8 sections. The process can take '
          'several minutes and uses your data connection. Existing '
          'cached starships will be replaced.',
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

    final result = await ref.read(starshipsScrapeProvider.notifier).refresh();
    if (!context.mounted) return;

    final hasError = result.starshipsError != null ||
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
                Text(result.starshipsError == null
                    ? 'Starships: saved ${result.starships}.'
                    : 'Starships FAILED:\n${result.starshipsError}'),
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
          'Saved ${result.starships} starships · ${result.qualities} qualities',
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

String _categoryOf(Starship s) {
  final c = s.category;
  if (c == null) return kStarshipCategoryOther;
  return kStarshipCategoryOrder.contains(c) ? c : kStarshipCategoryOther;
}

Map<String, List<Starship>> _groupByCategory(List<Starship> all) {
  final out = <String, List<Starship>>{};
  for (final s in all) {
    out.putIfAbsent(_categoryOf(s), () => []).add(s);
  }
  return out;
}

class _StarshipsScrapeBanner extends ConsumerWidget
    implements PreferredSizeWidget {
  final ScrapeState state;
  const _StarshipsScrapeBanner({required this.state});

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
                    ? 'Discovering starships…'
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
                  ref.read(starshipsScrapeProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';
import 'package:swrpg_quickypedia/widgets/download_from_cloud_button.dart';
import 'package:swrpg_quickypedia/widgets/search_bar_field.dart';

/// Generic grid screen for any category.
///
/// Use the default constructor for categories backed by real data — supply
/// a provider of [AsyncValue<List<T>>], a `matchesQuery` predicate, and a
/// `itemBuilder` to render each tile.
///
/// Use [CategoryGridScreen.comingSoon] for categories that aren't ready yet
/// — only `title` and `icon` are needed, and the screen displays a
/// placeholder.
class CategoryGridScreen<T> extends ConsumerWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<T>> Function(WidgetRef ref)? watchItems;
  final bool Function(T item, String query)? matchesQuery;
  final Widget Function(BuildContext context, T item)? itemBuilder;
  final String searchHint;

  /// Optional widget shown in place of the grid when the underlying list is
  /// empty (e.g. a "Fetch from wiki" call-to-action for system categories).
  final Widget Function(BuildContext context, WidgetRef ref)? emptyStateBuilder;

  /// Optional `AppBar` actions (e.g. a sort menu).
  final List<Widget> Function(BuildContext context, WidgetRef ref)?
      appBarActionsBuilder;

  /// Optional widget rendered below the `AppBar` (e.g. a scrape-progress bar).
  /// Must be a `PreferredSizeWidget` so the `AppBar` can reserve the right
  /// height — return `PreferredSize` with `Size.zero` when there's nothing
  /// to show.
  final PreferredSizeWidget Function(BuildContext context, WidgetRef ref)?
      belowAppBarBuilder;

  const CategoryGridScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.watchItems,
    required this.matchesQuery,
    required this.itemBuilder,
    this.searchHint = 'Search',
    this.emptyStateBuilder,
    this.appBarActionsBuilder,
    this.belowAppBarBuilder,
  });

  const CategoryGridScreen.comingSoon({
    super.key,
    required this.title,
    required this.icon,
  })  : watchItems = null,
        matchesQuery = null,
        itemBuilder = null,
        searchHint = '',
        emptyStateBuilder = null,
        appBarActionsBuilder = null,
        belowAppBarBuilder = null;

  bool get _isComingSoon => watchItems == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = appBarActionsBuilder?.call(context, ref) ?? const [];
    final belowAppBar = belowAppBarBuilder?.call(context, ref);
    // Download from cloud + any caller-supplied actions (sort menu,
    // refresh, etc.). Download sits first so it's the same position
    // as on the home AppBar.
    final actions = <Widget>[const DownloadFromCloudButton(), ...extra];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        bottom: belowAppBar,
      ),
      body: _isComingSoon ? _buildComingSoon(context) : _buildGrid(context, ref),
    );
  }

  Widget _buildComingSoon(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Coming soon',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              "This category isn't available yet.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref) {
    final itemsAsync = watchItems!(ref);
    final query = ref.watch(searchQueryProvider);
    return Column(
      children: [
        SearchBarField(hintText: searchHint),
        Expanded(
          child: itemsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load: $error'),
              ),
            ),
            data: (all) {
              if (all.isEmpty && emptyStateBuilder != null) {
                return emptyStateBuilder!(context, ref);
              }
              final filtered = query.isEmpty
                  ? all
                  : all
                      .where((item) => matchesQuery!(item, query))
                      .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    query.isEmpty
                        ? 'No items in this category.'
                        : 'No items match "$query".',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => itemBuilder!(ctx, filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

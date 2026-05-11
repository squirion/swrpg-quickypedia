import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic grid screen for any category.
///
/// Use the default constructor for categories backed by real data — supply
/// a provider of [AsyncValue<List<T>>], a `matchesQuery` predicate, and a
/// `itemBuilder` to render each tile.
///
/// Use [CategoryGridScreen.comingSoon] for categories that aren't ready yet
/// — only `title` and `icon` are needed, and the screen displays a
/// placeholder.
class CategoryGridScreen<T> extends ConsumerStatefulWidget {
  final String title;
  final IconData icon;
  final AsyncValue<List<T>> Function(WidgetRef ref)? watchItems;
  final bool Function(T item, String query)? matchesQuery;
  final Widget Function(BuildContext context, T item)? itemBuilder;
  final String searchHint;

  const CategoryGridScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.watchItems,
    required this.matchesQuery,
    required this.itemBuilder,
    this.searchHint = 'Search',
  });

  const CategoryGridScreen.comingSoon({
    super.key,
    required this.title,
    required this.icon,
  })  : watchItems = null,
        matchesQuery = null,
        itemBuilder = null,
        searchHint = '';

  bool get _isComingSoon => watchItems == null;

  @override
  ConsumerState<CategoryGridScreen<T>> createState() =>
      _CategoryGridScreenState<T>();
}

class _CategoryGridScreenState<T>
    extends ConsumerState<CategoryGridScreen<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: widget._isComingSoon ? _buildComingSoon() : _buildGrid(),
    );
  }

  Widget _buildComingSoon() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 80, color: Colors.grey.shade400),
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

  Widget _buildGrid() {
    final itemsAsync = widget.watchItems!(ref);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
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
              final filtered = _query.isEmpty
                  ? all
                  : all
                      .where((item) => widget.matchesQuery!(item, _query))
                      .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty
                        ? 'No items in this category.'
                        : 'No items match "$_query".',
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
                itemBuilder: (ctx, i) =>
                    widget.itemBuilder!(ctx, filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

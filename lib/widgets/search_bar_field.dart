import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swrpg_quickypedia/providers/providers.dart';

/// Shared search input bound to the global [searchQueryProvider].
///
/// Used at every tier (home, type screens, grid screen). Persistence is
/// automatic — the provider keeps the query string across navigation
/// until the user taps the clear (X) button.
///
/// The widget keeps a local [TextEditingController] so typing doesn't
/// have to round-trip through the provider before showing characters;
/// the controller is the source of truth for the visible text, and we
/// only push updates into the provider on every change.
class SearchBarField extends ConsumerStatefulWidget {
  final String hintText;

  const SearchBarField({super.key, this.hintText = 'Search'});

  @override
  ConsumerState<SearchBarField> createState() => _SearchBarFieldState();
}

class _SearchBarFieldState extends ConsumerState<SearchBarField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When the provider changes externally (e.g. cleared elsewhere or
    // pre-populated by a different screen), reflect it in the field.
    ref.listen<String>(searchQueryProvider, (prev, next) {
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    final query = ref.watch(searchQueryProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _controller,
        onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    ref.read(searchQueryProvider.notifier).clear();
                  },
                ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

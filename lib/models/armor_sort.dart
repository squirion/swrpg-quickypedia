/// Which armor attribute the user wants to sort by. Every attribute
/// parses out as an integer (Soak 2, Defense 1, …). Missing values
/// always sort to the end of the list, regardless of [ArmorSort.ascending].
enum ArmorSortAttr {
  rarity,
  price,
  soak,
  defense,
  encumbrance,
  hardpoints,
  alphabetical,
}

extension ArmorSortAttrLabel on ArmorSortAttr {
  /// Full label for the sort menu.
  String get label => switch (this) {
        ArmorSortAttr.rarity => 'Rarity',
        ArmorSortAttr.price => 'Price',
        ArmorSortAttr.soak => 'Soak',
        ArmorSortAttr.defense => 'Defense',
        ArmorSortAttr.encumbrance => 'Encumbrance',
        ArmorSortAttr.hardpoints => 'Hard Points',
        ArmorSortAttr.alphabetical => 'Alphabetical',
      };

  /// Short badge label used on tiles.
  String get shortLabel => switch (this) {
        ArmorSortAttr.rarity => 'RAR',
        ArmorSortAttr.price => 'PRC',
        ArmorSortAttr.soak => 'SOAK',
        ArmorSortAttr.defense => 'DEF',
        ArmorSortAttr.encumbrance => 'ENC',
        ArmorSortAttr.hardpoints => 'HP',
        ArmorSortAttr.alphabetical => 'A→Z',
      };
}

class ArmorSort {
  final ArmorSortAttr attr;
  final bool ascending;
  const ArmorSort({required this.attr, required this.ascending});

  /// Default for the whole app: rarity ascending (most common first),
  /// with name asc as the implicit secondary sort handled by the
  /// comparator.
  static const ArmorSort defaultSort =
      ArmorSort(attr: ArmorSortAttr.rarity, ascending: true);

  ArmorSort copyWith({ArmorSortAttr? attr, bool? ascending}) =>
      ArmorSort(
        attr: attr ?? this.attr,
        ascending: ascending ?? this.ascending,
      );
}

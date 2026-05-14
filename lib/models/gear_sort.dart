/// Which gear attribute the user wants to sort by. Missing values
/// always sort to the end, regardless of [GearSort.ascending].
enum GearSortAttr {
  rarity,
  price,
  encumbrance,
  alphabetical,
}

extension GearSortAttrLabel on GearSortAttr {
  String get label => switch (this) {
        GearSortAttr.rarity => 'Rarity',
        GearSortAttr.price => 'Price',
        GearSortAttr.encumbrance => 'Encumbrance',
        GearSortAttr.alphabetical => 'Alphabetical',
      };

  String get shortLabel => switch (this) {
        GearSortAttr.rarity => 'RAR',
        GearSortAttr.price => 'PRC',
        GearSortAttr.encumbrance => 'ENC',
        GearSortAttr.alphabetical => 'A→Z',
      };
}

class GearSort {
  final GearSortAttr attr;
  final bool ascending;
  const GearSort({required this.attr, required this.ascending});

  static const GearSort defaultSort =
      GearSort(attr: GearSortAttr.rarity, ascending: true);

  GearSort copyWith({GearSortAttr? attr, bool? ascending}) =>
      GearSort(
        attr: attr ?? this.attr,
        ascending: ascending ?? this.ascending,
      );
}

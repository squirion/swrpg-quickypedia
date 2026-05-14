/// Which weapon attribute the user wants to sort by. Range is treated as
/// an ordinal (Engaged < Short < Medium < Long < Extreme < Strategic);
/// everything else parses out as an integer. Missing values always sort
/// to the end of the list, regardless of [WeaponSort.ascending].
enum WeaponSortAttr {
  rarity,
  price,
  range,
  encumbrance,
  damage,
  critical,
  hardpoints,
  alphabetical,
}

extension WeaponSortAttrLabel on WeaponSortAttr {
  /// Full label for the sort menu.
  String get label => switch (this) {
        WeaponSortAttr.rarity => 'Rarity',
        WeaponSortAttr.price => 'Price',
        WeaponSortAttr.range => 'Range',
        WeaponSortAttr.encumbrance => 'Encumbrance',
        WeaponSortAttr.damage => 'Damage',
        WeaponSortAttr.critical => 'Critical',
        WeaponSortAttr.hardpoints => 'Hard Points',
        WeaponSortAttr.alphabetical => 'Alphabetical',
      };

  /// Short label used on tile badges.
  String get shortLabel => switch (this) {
        WeaponSortAttr.rarity => 'RAR',
        WeaponSortAttr.price => 'PRC',
        WeaponSortAttr.range => 'RNG',
        WeaponSortAttr.encumbrance => 'ENC',
        WeaponSortAttr.damage => 'DMG',
        WeaponSortAttr.critical => 'CRT',
        WeaponSortAttr.hardpoints => 'HP',
        WeaponSortAttr.alphabetical => 'A→Z',
      };
}

class WeaponSort {
  final WeaponSortAttr attr;
  final bool ascending;
  const WeaponSort({required this.attr, required this.ascending});

  /// Default for the whole app: rarity ascending (most common first),
  /// with name asc as the implicit secondary sort handled by the
  /// comparator.
  static const WeaponSort defaultSort =
      WeaponSort(attr: WeaponSortAttr.rarity, ascending: true);

  WeaponSort copyWith({WeaponSortAttr? attr, bool? ascending}) =>
      WeaponSort(
        attr: attr ?? this.attr,
        ascending: ascending ?? this.ascending,
      );
}

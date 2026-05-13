enum BeastSortAttr {
  rarity,
  price,
  brawn,
  woundThreshold,
}

extension BeastSortAttrLabel on BeastSortAttr {
  String get label => switch (this) {
        BeastSortAttr.rarity => 'Rarity',
        BeastSortAttr.price => 'Price',
        BeastSortAttr.brawn => 'Brawn',
        BeastSortAttr.woundThreshold => 'Wound Threshold',
      };

  String get shortLabel => switch (this) {
        BeastSortAttr.rarity => 'RAR',
        BeastSortAttr.price => 'PRC',
        BeastSortAttr.brawn => 'BR',
        BeastSortAttr.woundThreshold => 'WND',
      };
}

class BeastSort {
  final BeastSortAttr attr;
  final bool ascending;
  const BeastSort({required this.attr, required this.ascending});

  static const BeastSort defaultSort =
      BeastSort(attr: BeastSortAttr.rarity, ascending: true);

  BeastSort copyWith({BeastSortAttr? attr, bool? ascending}) =>
      BeastSort(
        attr: attr ?? this.attr,
        ascending: ascending ?? this.ascending,
      );
}

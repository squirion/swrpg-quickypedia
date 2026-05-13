enum StarshipSortAttr {
  rarity,
  price,
  silhouette,
  speed,
  handling,
  armor,
  hullTrauma,
  encumbranceCapacity,
  passengerCapacity,
}

extension StarshipSortAttrLabel on StarshipSortAttr {
  String get label => switch (this) {
        StarshipSortAttr.rarity => 'Rarity',
        StarshipSortAttr.price => 'Price',
        StarshipSortAttr.silhouette => 'Silhouette',
        StarshipSortAttr.speed => 'Speed',
        StarshipSortAttr.handling => 'Handling',
        StarshipSortAttr.armor => 'Armor',
        StarshipSortAttr.hullTrauma => 'Hull Trauma',
        StarshipSortAttr.encumbranceCapacity => 'Encum. Capacity',
        StarshipSortAttr.passengerCapacity => 'Passengers',
      };

  String get shortLabel => switch (this) {
        StarshipSortAttr.rarity => 'RAR',
        StarshipSortAttr.price => 'PRC',
        StarshipSortAttr.silhouette => 'SIL',
        StarshipSortAttr.speed => 'SPD',
        StarshipSortAttr.handling => 'HND',
        StarshipSortAttr.armor => 'ARM',
        StarshipSortAttr.hullTrauma => 'HULL',
        StarshipSortAttr.encumbranceCapacity => 'ENCAP',
        StarshipSortAttr.passengerCapacity => 'PAX',
      };
}

class StarshipSort {
  final StarshipSortAttr attr;
  final bool ascending;
  const StarshipSort({required this.attr, required this.ascending});

  static const StarshipSort defaultSort =
      StarshipSort(attr: StarshipSortAttr.rarity, ascending: true);

  StarshipSort copyWith({StarshipSortAttr? attr, bool? ascending}) =>
      StarshipSort(
        attr: attr ?? this.attr,
        ascending: ascending ?? this.ascending,
      );
}

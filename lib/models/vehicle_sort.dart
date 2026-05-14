/// Which vehicle attribute the user wants to sort by. Missing values
/// always sort to the end, regardless of [VehicleSort.ascending].
enum VehicleSortAttr {
  rarity,
  price,
  silhouette,
  speed,
  handling,
  armor,
  hullTrauma,
  encumbranceCapacity,
  passengerCapacity,
  alphabetical,
}

extension VehicleSortAttrLabel on VehicleSortAttr {
  String get label => switch (this) {
        VehicleSortAttr.rarity => 'Rarity',
        VehicleSortAttr.price => 'Price',
        VehicleSortAttr.silhouette => 'Silhouette',
        VehicleSortAttr.speed => 'Speed',
        VehicleSortAttr.handling => 'Handling',
        VehicleSortAttr.armor => 'Armor',
        VehicleSortAttr.hullTrauma => 'Hull Trauma',
        VehicleSortAttr.encumbranceCapacity => 'Encum. Capacity',
        VehicleSortAttr.passengerCapacity => 'Passengers',
        VehicleSortAttr.alphabetical => 'Alphabetical',
      };

  String get shortLabel => switch (this) {
        VehicleSortAttr.rarity => 'RAR',
        VehicleSortAttr.price => 'PRC',
        VehicleSortAttr.silhouette => 'SIL',
        VehicleSortAttr.speed => 'SPD',
        VehicleSortAttr.handling => 'HND',
        VehicleSortAttr.armor => 'ARM',
        VehicleSortAttr.hullTrauma => 'HULL',
        VehicleSortAttr.encumbranceCapacity => 'ENCAP',
        VehicleSortAttr.passengerCapacity => 'PAX',
        VehicleSortAttr.alphabetical => 'A→Z',
      };
}

class VehicleSort {
  final VehicleSortAttr attr;
  final bool ascending;
  const VehicleSort({required this.attr, required this.ascending});

  static const VehicleSort defaultSort =
      VehicleSort(attr: VehicleSortAttr.rarity, ascending: true);

  VehicleSort copyWith({VehicleSortAttr? attr, bool? ascending}) =>
      VehicleSort(
        attr: attr ?? this.attr,
        ascending: ascending ?? this.ascending,
      );
}

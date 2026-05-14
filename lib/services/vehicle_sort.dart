import 'package:swrpg_quickypedia/models/vehicle.dart';
import 'package:swrpg_quickypedia/models/vehicle_sort.dart';

/// Comparator for [Vehicle] under a given [VehicleSort]. Missing
/// values sort to the end regardless of direction.
int compareVehicles(Vehicle a, Vehicle b, VehicleSort sort) {
  if (sort.attr == VehicleSortAttr.alphabetical) {
    final c = _nameCmp(a, b);
    return sort.ascending ? c : -c;
  }
  final aVal = _valueFor(a, sort.attr);
  final bVal = _valueFor(b, sort.attr);

  if (aVal == null && bVal == null) return _nameCmp(a, b);
  if (aVal == null) return 1;
  if (bVal == null) return -1;

  final c = aVal.compareTo(bVal);
  if (c != 0) return sort.ascending ? c : -c;
  return _nameCmp(a, b);
}

int _nameCmp(Vehicle a, Vehicle b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

int? _valueFor(Vehicle v, VehicleSortAttr attr) => switch (attr) {
      VehicleSortAttr.rarity => _parseInt(v.rarity),
      VehicleSortAttr.price => _parseInt(v.price),
      VehicleSortAttr.silhouette => _parseInt(v.silhouette),
      VehicleSortAttr.speed => _parseInt(v.speed),
      VehicleSortAttr.handling => _parseInt(v.handling),
      VehicleSortAttr.armor => _parseInt(v.armor),
      VehicleSortAttr.hullTrauma => _parseInt(v.hullTrauma),
      VehicleSortAttr.encumbranceCapacity => _parseInt(v.encumbranceCapacity),
      VehicleSortAttr.passengerCapacity => _parseInt(v.passengerCapacity),
      VehicleSortAttr.alphabetical => null,
    };

int? _parseInt(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '');
  final m = RegExp(r'-?\d+').firstMatch(cleaned);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

import 'package:swrpg_quickypedia/models/starship.dart';
import 'package:swrpg_quickypedia/models/starship_sort.dart';

int compareStarships(Starship a, Starship b, StarshipSort sort) {
  final aVal = _valueFor(a, sort.attr);
  final bVal = _valueFor(b, sort.attr);

  if (aVal == null && bVal == null) return _nameCmp(a, b);
  if (aVal == null) return 1;
  if (bVal == null) return -1;

  final c = aVal.compareTo(bVal);
  if (c != 0) return sort.ascending ? c : -c;
  return _nameCmp(a, b);
}

int _nameCmp(Starship a, Starship b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

int? _valueFor(Starship s, StarshipSortAttr attr) => switch (attr) {
      StarshipSortAttr.rarity => _parseInt(s.rarity),
      StarshipSortAttr.price => _parseInt(s.price),
      StarshipSortAttr.silhouette => _parseInt(s.silhouette),
      StarshipSortAttr.speed => _parseInt(s.speed),
      StarshipSortAttr.handling => _parseInt(s.handling),
      StarshipSortAttr.armor => _parseInt(s.armor),
      StarshipSortAttr.hullTrauma => _parseInt(s.hullTrauma),
      StarshipSortAttr.encumbranceCapacity => _parseInt(s.encumbranceCapacity),
      StarshipSortAttr.passengerCapacity => _parseInt(s.passengerCapacity),
    };

int? _parseInt(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '');
  final m = RegExp(r'-?\d+').firstMatch(cleaned);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

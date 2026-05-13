import 'package:swrpg_quickypedia/models/gear.dart';
import 'package:swrpg_quickypedia/models/gear_sort.dart';

/// Comparator for [Gear] under a given [GearSort]. Same null-safety
/// pattern as the weapon and armor comparators.
int compareGear(Gear a, Gear b, GearSort sort) {
  final aVal = _valueFor(a, sort.attr);
  final bVal = _valueFor(b, sort.attr);

  if (aVal == null && bVal == null) return _nameCmp(a, b);
  if (aVal == null) return 1;
  if (bVal == null) return -1;

  final c = aVal.compareTo(bVal);
  if (c != 0) return sort.ascending ? c : -c;
  return _nameCmp(a, b);
}

int _nameCmp(Gear a, Gear b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

int? _valueFor(Gear g, GearSortAttr attr) => switch (attr) {
      GearSortAttr.rarity => _parseInt(g.rarity),
      GearSortAttr.price => _parseInt(g.price),
      GearSortAttr.encumbrance => _parseInt(g.encumbrance),
    };

int? _parseInt(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '');
  final m = RegExp(r'-?\d+').firstMatch(cleaned);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

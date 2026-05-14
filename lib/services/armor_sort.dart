import 'package:swrpg_quickypedia/models/armor.dart';
import 'package:swrpg_quickypedia/models/armor_sort.dart';

/// Comparator for [Armor] under a given [ArmorSort]. Missing values
/// always sort to the end (regardless of direction) so an armor that
/// just lacks the attribute doesn't clutter the top of the list. Ties
/// on the primary key fall through to ascending case-insensitive name.
int compareArmors(Armor a, Armor b, ArmorSort sort) {
  if (sort.attr == ArmorSortAttr.alphabetical) {
    final c = _nameCmp(a, b);
    return sort.ascending ? c : -c;
  }
  final aVal = _valueFor(a, sort.attr);
  final bVal = _valueFor(b, sort.attr);

  if (aVal == null && bVal == null) {
    return _nameCmp(a, b);
  }
  if (aVal == null) return 1;
  if (bVal == null) return -1;

  final c = aVal.compareTo(bVal);
  if (c != 0) return sort.ascending ? c : -c;
  return _nameCmp(a, b);
}

int _nameCmp(Armor a, Armor b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

int? _valueFor(Armor w, ArmorSortAttr attr) => switch (attr) {
      ArmorSortAttr.rarity => _parseInt(w.rarity),
      ArmorSortAttr.price => _parseInt(w.price),
      ArmorSortAttr.soak => _parseInt(w.soak),
      ArmorSortAttr.defense => _parseInt(w.defense),
      ArmorSortAttr.encumbrance => _parseInt(w.encumbrance),
      ArmorSortAttr.hardpoints => _parseInt(w.hardpoints),
      // Handled above by short-circuit; this arm exists only so the
      // exhaustive switch type-checks.
      ArmorSortAttr.alphabetical => null,
    };

/// Pulls the first integer out of strings like `"2"`, `"1,500"`,
/// `"1/2"` (treats as 1), returning `null` for `"-"` / `"—"` / empty.
int? _parseInt(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '');
  final m = RegExp(r'-?\d+').firstMatch(cleaned);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

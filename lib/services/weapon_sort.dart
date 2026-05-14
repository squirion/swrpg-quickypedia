import 'package:swrpg_quickypedia/models/weapon.dart';
import 'package:swrpg_quickypedia/models/weapon_sort.dart';

/// Comparator for [Weapon] under a given [WeaponSort]. Missing values
/// always sort to the end (regardless of direction) so a weapon that
/// just lacks the attribute doesn't clutter the top of the list. Ties
/// on the primary key fall through to ascending case-insensitive name.
int compareWeapons(Weapon a, Weapon b, WeaponSort sort) {
  // Alphabetical promotes the existing name tiebreaker to the primary
  // key and honors `ascending`; nothing else to compare on.
  if (sort.attr == WeaponSortAttr.alphabetical) {
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

int _nameCmp(Weapon a, Weapon b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

/// Extract a comparable integer for the given attribute. Returns null
/// when the weapon doesn't carry that attribute (so the caller can sort
/// it to the end).
int? _valueFor(Weapon w, WeaponSortAttr attr) => switch (attr) {
      WeaponSortAttr.rarity => _parseInt(w.rarity),
      WeaponSortAttr.price => _parseInt(w.price),
      WeaponSortAttr.damage => _parseInt(w.damage),
      WeaponSortAttr.critical => _parseInt(w.critical),
      WeaponSortAttr.encumbrance => _parseInt(w.encumbrance),
      WeaponSortAttr.hardpoints => _parseInt(w.hardpoints),
      WeaponSortAttr.range => _rangeOrdinal(w.range),
      // Handled above by short-circuit; this arm exists only so the
      // exhaustive switch type-checks.
      WeaponSortAttr.alphabetical => null,
    };

/// Pulls the first integer out of strings like `"7"`, `"+2"`,
/// `"1,500"`, `"6 (R)"`, returning `null` for `"-"` / `"—"` / empty.
int? _parseInt(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '');
  final m = RegExp(r'-?\d+').firstMatch(cleaned);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

/// Engaged < Short < Medium < Long < Extreme < Strategic.
int? _rangeOrdinal(String? range) {
  if (range == null) return null;
  switch (range.toLowerCase().trim()) {
    case 'engaged':
      return 0;
    case 'short':
      return 1;
    case 'medium':
      return 2;
    case 'long':
      return 3;
    case 'extreme':
      return 4;
    case 'strategic':
      return 5;
    default:
      return null;
  }
}

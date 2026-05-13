import 'package:swrpg_quickypedia/models/beast.dart';
import 'package:swrpg_quickypedia/models/beast_sort.dart';

int compareBeasts(Beast a, Beast b, BeastSort sort) {
  final aVal = _valueFor(a, sort.attr);
  final bVal = _valueFor(b, sort.attr);

  if (aVal == null && bVal == null) return _nameCmp(a, b);
  if (aVal == null) return 1;
  if (bVal == null) return -1;

  final c = aVal.compareTo(bVal);
  if (c != 0) return sort.ascending ? c : -c;
  return _nameCmp(a, b);
}

int _nameCmp(Beast a, Beast b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

int? _valueFor(Beast b, BeastSortAttr attr) => switch (attr) {
      BeastSortAttr.rarity => _parseInt(b.rarity),
      BeastSortAttr.price => _parseInt(b.price),
      BeastSortAttr.brawn => _parseInt(b.brawn),
      BeastSortAttr.woundThreshold => _parseInt(b.woundThreshold),
    };

int? _parseInt(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(',', '');
  final m = RegExp(r'-?\d+').firstMatch(cleaned);
  if (m == null) return null;
  return int.tryParse(m.group(0)!);
}

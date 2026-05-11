/// A weapon entry scraped from the SWRPG FFG Fandom wiki.
///
/// Only [name] is required; every other field is nullable because the wiki's
/// infobox coverage is inconsistent (e.g. lightsabers lack a `range`, melee
/// weapons lack hardpoints, vehicle weapons may omit price/rarity, …).
class Weapon {
  final String name;
  final String? skill;
  final String? damage;
  final String? critical;
  final String? range;
  final String? encumbrance;
  final String? hardpoints;
  final String? price;
  final String? rarity;
  final List<String> specialQualities;
  final String? description;
  final String? mechanics;
  final String? sourceUrl;
  final String? imageUrl;

  const Weapon({
    required this.name,
    this.skill,
    this.damage,
    this.critical,
    this.range,
    this.encumbrance,
    this.hardpoints,
    this.price,
    this.rarity,
    this.specialQualities = const [],
    this.description,
    this.mechanics,
    this.sourceUrl,
    this.imageUrl,
  });

  factory Weapon.fromJson(Map<String, dynamic> json) {
    final raw = json['specialQualities'];
    final specials = raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const <String>[];
    return Weapon(
      name: (json['name'] as String?) ?? '',
      skill: json['skill'] as String?,
      damage: json['damage'] as String?,
      critical: json['critical'] as String?,
      range: json['range'] as String?,
      encumbrance: json['encumbrance'] as String?,
      hardpoints: json['hardpoints'] as String?,
      price: json['price'] as String?,
      rarity: json['rarity'] as String?,
      specialQualities: specials,
      description: json['description'] as String?,
      mechanics: json['mechanics'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (skill != null) 'skill': skill,
        if (damage != null) 'damage': damage,
        if (critical != null) 'critical': critical,
        if (range != null) 'range': range,
        if (encumbrance != null) 'encumbrance': encumbrance,
        if (hardpoints != null) 'hardpoints': hardpoints,
        if (price != null) 'price': price,
        if (rarity != null) 'rarity': rarity,
        if (specialQualities.isNotEmpty) 'specialQualities': specialQualities,
        if (description != null) 'description': description,
        if (mechanics != null) 'mechanics': mechanics,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

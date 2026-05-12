/// An armor entry scraped from the SWRPG FFG Fandom wiki.
///
/// Only [name] is required; every other field is nullable because the wiki's
/// coverage is inconsistent (some legendary pieces omit price/rarity, beast
/// armor sometimes lacks hard points, etc.).
///
/// [category] is the Fandom subcategory the armor was found in (e.g.
/// "Armor (Light)", "Legendary"). It's set by the scraper at discovery
/// time so the 3-tier type screen doesn't have to re-derive it.
class Armor {
  final String name;
  final String? soak;
  final String? defense;
  final String? encumbrance;
  final String? hardpoints;
  final String? price;
  final String? rarity;
  final List<String> specialQualities;
  final String? description;
  final String? mechanics;
  final String? sourceUrl;
  final String? imageUrl;
  final String? category;

  const Armor({
    required this.name,
    this.soak,
    this.defense,
    this.encumbrance,
    this.hardpoints,
    this.price,
    this.rarity,
    this.specialQualities = const [],
    this.description,
    this.mechanics,
    this.sourceUrl,
    this.imageUrl,
    this.category,
  });

  factory Armor.fromJson(Map<String, dynamic> json) {
    final raw = json['specialQualities'];
    final specials = raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const <String>[];
    return Armor(
      name: (json['name'] as String?) ?? '',
      soak: json['soak'] as String?,
      defense: json['defense'] as String?,
      encumbrance: json['encumbrance'] as String?,
      hardpoints: json['hardpoints'] as String?,
      price: json['price'] as String?,
      rarity: json['rarity'] as String?,
      specialQualities: specials,
      description: json['description'] as String?,
      mechanics: json['mechanics'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (soak != null) 'soak': soak,
        if (defense != null) 'defense': defense,
        if (encumbrance != null) 'encumbrance': encumbrance,
        if (hardpoints != null) 'hardpoints': hardpoints,
        if (price != null) 'price': price,
        if (rarity != null) 'rarity': rarity,
        if (specialQualities.isNotEmpty) 'specialQualities': specialQualities,
        if (description != null) 'description': description,
        if (mechanics != null) 'mechanics': mechanics,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (category != null) 'category': category,
      };
}

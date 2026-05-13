/// A gear entry scraped from the SWRPG FFG Fandom wiki.
///
/// Gear has the simplest stat block of all system-dependent categories:
/// just Price, Encumbrance, and Rarity. Most gear has no Special
/// Qualities, but the field exists for items like medkits and comlinks
/// that do (resolved through the same glossary as weapons/armor).
class Gear {
  final String name;
  final String? price;
  final String? encumbrance;
  final String? rarity;
  final List<String> specialQualities;
  final String? description;
  final String? mechanics;
  final String? sourceUrl;
  final String? imageUrl;
  final String? category;

  const Gear({
    required this.name,
    this.price,
    this.encumbrance,
    this.rarity,
    this.specialQualities = const [],
    this.description,
    this.mechanics,
    this.sourceUrl,
    this.imageUrl,
    this.category,
  });

  factory Gear.fromJson(Map<String, dynamic> json) {
    final raw = json['specialQualities'];
    final specials = raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const <String>[];
    return Gear(
      name: (json['name'] as String?) ?? '',
      price: json['price'] as String?,
      encumbrance: json['encumbrance'] as String?,
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
        if (price != null) 'price': price,
        if (encumbrance != null) 'encumbrance': encumbrance,
        if (rarity != null) 'rarity': rarity,
        if (specialQualities.isNotEmpty) 'specialQualities': specialQualities,
        if (description != null) 'description': description,
        if (mechanics != null) 'mechanics': mechanics,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (category != null) 'category': category,
      };
}

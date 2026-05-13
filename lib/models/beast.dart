/// A beast entry scraped from the SWRPG FFG Fandom wiki.
///
/// Beasts are creatures, not items, so their stat block is split
/// across two `<img alt="...">` blocks:
///   - Commerce alt: `Encumbrance - Price 2,500 Rarity 1`
///   - Creature alt: `Brawn 5 Agility 1 Intellect 1 Cunning 1
///     Willpower 1 Presence 1 Soak Value 10 Wound Threshold 26
///     Melee Defense 0 Ranged Defense 0`
///
/// The post-stat paragraph lists `Skills:`, `Talents:`, `Abilities:`,
/// and `Equipment:` (natural weapons), each as a single text string —
/// rendered verbatim in the detail view so multi-clause descriptions
/// stay intact.
class Beast {
  final String name;
  // Commerce
  final String? encumbrance;
  final String? price;
  final String? rarity;
  // Characteristics
  final String? brawn;
  final String? agility;
  final String? intellect;
  final String? cunning;
  final String? willpower;
  final String? presence;
  // Combat
  final String? soak;
  final String? woundThreshold;
  final String? meleeDefense;
  final String? rangedDefense;
  // Prose lists (each is the raw post-label text — parsing further is
  // a future refinement)
  final String? skills;
  final String? talents;
  final String? abilities;
  final String? equipment;
  // Pulled from the abilities text when present (e.g. "Silhouette 2")
  final String? silhouette;
  // Shared
  final String? description;
  final String? mechanics;
  final String? sourceUrl;
  final String? imageUrl;
  final String? category;

  const Beast({
    required this.name,
    this.encumbrance,
    this.price,
    this.rarity,
    this.brawn,
    this.agility,
    this.intellect,
    this.cunning,
    this.willpower,
    this.presence,
    this.soak,
    this.woundThreshold,
    this.meleeDefense,
    this.rangedDefense,
    this.skills,
    this.talents,
    this.abilities,
    this.equipment,
    this.silhouette,
    this.description,
    this.mechanics,
    this.sourceUrl,
    this.imageUrl,
    this.category,
  });

  factory Beast.fromJson(Map<String, dynamic> json) {
    return Beast(
      name: (json['name'] as String?) ?? '',
      encumbrance: json['encumbrance'] as String?,
      price: json['price'] as String?,
      rarity: json['rarity'] as String?,
      brawn: json['brawn'] as String?,
      agility: json['agility'] as String?,
      intellect: json['intellect'] as String?,
      cunning: json['cunning'] as String?,
      willpower: json['willpower'] as String?,
      presence: json['presence'] as String?,
      soak: json['soak'] as String?,
      woundThreshold: json['woundThreshold'] as String?,
      meleeDefense: json['meleeDefense'] as String?,
      rangedDefense: json['rangedDefense'] as String?,
      skills: json['skills'] as String?,
      talents: json['talents'] as String?,
      abilities: json['abilities'] as String?,
      equipment: json['equipment'] as String?,
      silhouette: json['silhouette'] as String?,
      description: json['description'] as String?,
      mechanics: json['mechanics'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (encumbrance != null) 'encumbrance': encumbrance,
        if (price != null) 'price': price,
        if (rarity != null) 'rarity': rarity,
        if (brawn != null) 'brawn': brawn,
        if (agility != null) 'agility': agility,
        if (intellect != null) 'intellect': intellect,
        if (cunning != null) 'cunning': cunning,
        if (willpower != null) 'willpower': willpower,
        if (presence != null) 'presence': presence,
        if (soak != null) 'soak': soak,
        if (woundThreshold != null) 'woundThreshold': woundThreshold,
        if (meleeDefense != null) 'meleeDefense': meleeDefense,
        if (rangedDefense != null) 'rangedDefense': rangedDefense,
        if (skills != null) 'skills': skills,
        if (talents != null) 'talents': talents,
        if (abilities != null) 'abilities': abilities,
        if (equipment != null) 'equipment': equipment,
        if (silhouette != null) 'silhouette': silhouette,
        if (description != null) 'description': description,
        if (mechanics != null) 'mechanics': mechanics,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (category != null) 'category': category,
      };
}

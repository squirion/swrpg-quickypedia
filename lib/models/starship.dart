/// A starship entry scraped from the SWRPG FFG Fandom wiki.
///
/// Starships share the vehicle stat-image layout (Silhouette / Speed /
/// Handling / 4-zone Defense / Armor / Hull Trauma Threshold / System
/// Strain Threshold) but the post-stat text paragraph carries extra
/// labels: Hull Type/Class, Manufacturer, Hyperdrive, Navicomputer,
/// and renames Crew → Ship's Complement.
///
/// Every field is nullable except `name`.
class Starship {
  final String name;
  // Combat stats (alt-text)
  final String? silhouette;
  final String? speed;
  final String? handling;
  final String? defenseFore;
  final String? defensePort;
  final String? defenseStarboard;
  final String? defenseAft;
  final String? armor;
  final String? hullTrauma;
  final String? systemStrain;
  // Transport / logistics (post-stat text)
  final String? hullTypeClass;
  final String? manufacturer;
  final String? hyperdrive;
  final String? navicomputer;
  final String? sensorRange;
  final String? shipsComplement;
  final String? encumbranceCapacity;
  final String? passengerCapacity;
  final String? consumables;
  final String? hardpoints;
  final String? weapons;
  final String? price;
  final String? rarity;
  // Shared
  final List<String> specialQualities;
  final String? description;
  final String? mechanics;
  final String? sourceUrl;
  final String? imageUrl;
  final String? category;

  const Starship({
    required this.name,
    this.silhouette,
    this.speed,
    this.handling,
    this.defenseFore,
    this.defensePort,
    this.defenseStarboard,
    this.defenseAft,
    this.armor,
    this.hullTrauma,
    this.systemStrain,
    this.hullTypeClass,
    this.manufacturer,
    this.hyperdrive,
    this.navicomputer,
    this.sensorRange,
    this.shipsComplement,
    this.encumbranceCapacity,
    this.passengerCapacity,
    this.consumables,
    this.hardpoints,
    this.weapons,
    this.price,
    this.rarity,
    this.specialQualities = const [],
    this.description,
    this.mechanics,
    this.sourceUrl,
    this.imageUrl,
    this.category,
  });

  factory Starship.fromJson(Map<String, dynamic> json) {
    final raw = json['specialQualities'];
    final specials = raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const <String>[];
    return Starship(
      name: (json['name'] as String?) ?? '',
      silhouette: json['silhouette'] as String?,
      speed: json['speed'] as String?,
      handling: json['handling'] as String?,
      defenseFore: json['defenseFore'] as String?,
      defensePort: json['defensePort'] as String?,
      defenseStarboard: json['defenseStarboard'] as String?,
      defenseAft: json['defenseAft'] as String?,
      armor: json['armor'] as String?,
      hullTrauma: json['hullTrauma'] as String?,
      systemStrain: json['systemStrain'] as String?,
      hullTypeClass: json['hullTypeClass'] as String?,
      manufacturer: json['manufacturer'] as String?,
      hyperdrive: json['hyperdrive'] as String?,
      navicomputer: json['navicomputer'] as String?,
      sensorRange: json['sensorRange'] as String?,
      shipsComplement: json['shipsComplement'] as String?,
      encumbranceCapacity: json['encumbranceCapacity'] as String?,
      passengerCapacity: json['passengerCapacity'] as String?,
      consumables: json['consumables'] as String?,
      hardpoints: json['hardpoints'] as String?,
      weapons: json['weapons'] as String?,
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
        if (silhouette != null) 'silhouette': silhouette,
        if (speed != null) 'speed': speed,
        if (handling != null) 'handling': handling,
        if (defenseFore != null) 'defenseFore': defenseFore,
        if (defensePort != null) 'defensePort': defensePort,
        if (defenseStarboard != null) 'defenseStarboard': defenseStarboard,
        if (defenseAft != null) 'defenseAft': defenseAft,
        if (armor != null) 'armor': armor,
        if (hullTrauma != null) 'hullTrauma': hullTrauma,
        if (systemStrain != null) 'systemStrain': systemStrain,
        if (hullTypeClass != null) 'hullTypeClass': hullTypeClass,
        if (manufacturer != null) 'manufacturer': manufacturer,
        if (hyperdrive != null) 'hyperdrive': hyperdrive,
        if (navicomputer != null) 'navicomputer': navicomputer,
        if (sensorRange != null) 'sensorRange': sensorRange,
        if (shipsComplement != null) 'shipsComplement': shipsComplement,
        if (encumbranceCapacity != null)
          'encumbranceCapacity': encumbranceCapacity,
        if (passengerCapacity != null)
          'passengerCapacity': passengerCapacity,
        if (consumables != null) 'consumables': consumables,
        if (hardpoints != null) 'hardpoints': hardpoints,
        if (weapons != null) 'weapons': weapons,
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

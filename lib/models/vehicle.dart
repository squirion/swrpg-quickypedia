/// A vehicle entry scraped from the SWRPG FFG Fandom wiki.
///
/// Vehicle pages carry their stats in two places:
///   1. The stat-image alt text: Silhouette, Speed, Handling, Defense
///      (4 zones), Armor, Hull Trauma Threshold, System Strain Threshold.
///   2. Plain text below the image: Sensor Range, Crew, Encumbrance
///      Capacity, Passenger Capacity, Price/Rarity, Hard Points, Weapons.
///
/// Defense is broken into 4 separate fields so the diamond tile in the
/// detail screen can render each zone independently. Every field is
/// nullable except `name` — many vehicles omit Hard Points, beasts of
/// burden omit Weapons, podracers may have no Passenger Capacity, etc.
class Vehicle {
  final String name;
  // Combat stats (from stat-image alt)
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
  // Transport / logistics (from page text)
  final String? sensorRange;
  final String? crew;
  final String? encumbranceCapacity;
  final String? passengerCapacity;
  final String? consumables;
  final String? hardpoints;
  final String? weapons;
  final String? price;
  final String? rarity;
  // Shared with weapons/armor/gear
  final List<String> specialQualities;
  final String? description;
  final String? mechanics;
  final String? sourceUrl;
  final String? imageUrl;
  final String? category;

  const Vehicle({
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
    this.sensorRange,
    this.crew,
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

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final raw = json['specialQualities'];
    final specials = raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const <String>[];
    return Vehicle(
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
      sensorRange: json['sensorRange'] as String?,
      crew: json['crew'] as String?,
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
        if (sensorRange != null) 'sensorRange': sensorRange,
        if (crew != null) 'crew': crew,
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

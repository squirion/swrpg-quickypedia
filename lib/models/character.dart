class UserMini {
  final String id;
  final String username;
  final String profileUrl;

  const UserMini({
    required this.id,
    required this.username,
    required this.profileUrl,
  });

  factory UserMini.fromJson(Map<String, dynamic> json) {
    return UserMini(
      id: json['id'] as String,
      username: json['username'] as String,
      profileUrl: json['profile_url'] as String,
    );
  }
}

class CampaignMini {
  final String id;
  final String name;
  final String slug;
  final String campaignUrl;

  const CampaignMini({
    required this.id,
    required this.name,
    required this.slug,
    required this.campaignUrl,
  });

  factory CampaignMini.fromJson(Map<String, dynamic> json) {
    return CampaignMini(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      campaignUrl: json['campaign_url'] as String,
    );
  }
}

class Character {
  final String id;
  final String? slug;
  final String name;
  final String? characterUrl;
  final String? avatarUrl;
  final String? content;
  final CampaignMini? campaign;
  final String visibility;
  final UserMini? author;
  final bool isPlayerCharacter;
  final bool isGameMasterOnly;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Character({
    required this.id,
    this.slug,
    required this.name,
    this.characterUrl,
    this.avatarUrl,
    this.content,
    this.campaign,
    required this.visibility,
    this.author,
    required this.isPlayerCharacter,
    required this.isGameMasterOnly,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String,
      slug: json['slug'] as String?,
      name: json['name'] as String,
      characterUrl: json['character_url'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      content: json['content'] as String? ??
          json['description'] as String? ??
          json['bio'] as String?,
      campaign: json['campaign'] != null
          ? CampaignMini.fromJson(json['campaign'] as Map<String, dynamic>)
          : null,
      visibility: json['visibility'] as String? ?? 'public',
      author: json['author'] != null
          ? UserMini.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      isPlayerCharacter: json['is_player_character'] as bool? ?? false,
      isGameMasterOnly: json['is_game_master_only'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

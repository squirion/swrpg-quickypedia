class Campaign {
  final String id;
  final String name;
  final String slug;
  final String campaignUrl;
  final String? visibility;
  final String? role;

  const Campaign({
    required this.id,
    required this.name,
    required this.slug,
    required this.campaignUrl,
    this.visibility,
    this.role,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      campaignUrl: json['campaign_url'] as String? ?? '',
      visibility: json['visibility'] as String?,
      role: json['role'] as String?,
    );
  }

  @override
  String toString() => name;
}

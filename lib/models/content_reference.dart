class ContentReference {
  final String kind; // shop | market | module
  final String key;
  final int id;
  final String slug;
  final String featureKey;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String emoji;
  final DateTime savedAt;

  const ContentReference({
    required this.kind,
    required this.key,
    this.id = 0,
    this.slug = '',
    this.featureKey = '',
    required this.title,
    this.subtitle = '',
    this.imageUrl = '',
    this.emoji = '',
    required this.savedAt,
  });

  factory ContentReference.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['saved_at'] ?? '').toString();
    return ContentReference(
      kind: (json['kind'] ?? '').toString().trim(),
      key: (json['key'] ?? '').toString().trim(),
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      slug: (json['slug'] ?? '').toString().trim(),
      featureKey: (json['feature_key'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      subtitle: (json['subtitle'] ?? '').toString().trim(),
      imageUrl: (json['image_url'] ?? '').toString().trim(),
      emoji: (json['emoji'] ?? '').toString().trim(),
      savedAt: DateTime.tryParse(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'key': key,
        'id': id,
        'slug': slug,
        'feature_key': featureKey,
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'emoji': emoji,
        'saved_at': savedAt.toIso8601String(),
      };

  ContentReference copyWith({DateTime? savedAt}) => ContentReference(
        kind: kind,
        key: key,
        id: id,
        slug: slug,
        featureKey: featureKey,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
        emoji: emoji,
        savedAt: savedAt ?? this.savedAt,
      );

  static String shopKey(String slug) => 'shop:${slug.trim().toLowerCase()}';
  static String marketKey(int id) => 'market:$id';
  static String moduleKey(String featureKey, int id) =>
      'module:${featureKey.trim().toLowerCase()}:$id';
}

class GlobalSearchResult {
  final String kind; // shop | market | module
  final int id;
  final String slug;
  final String featureKey;
  final String title;
  final String subtitle;
  final String location;
  final String imageUrl;
  final String emoji;
  final bool verified;
  final bool featured;

  const GlobalSearchResult({
    required this.kind,
    required this.id,
    required this.slug,
    required this.featureKey,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.imageUrl,
    required this.emoji,
    required this.verified,
    required this.featured,
  });

  factory GlobalSearchResult.fromJson(Map<String, dynamic> json) {
    return GlobalSearchResult(
      kind: (json['kind'] ?? '').toString().trim(),
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      slug: (json['slug'] ?? '').toString().trim(),
      featureKey: (json['feature_key'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      subtitle: (json['subtitle'] ?? '').toString().trim(),
      location: (json['location'] ?? '').toString().trim(),
      imageUrl: (json['image_url'] ?? '').toString().trim(),
      emoji: (json['emoji'] ?? '').toString().trim(),
      verified: _bool(json['verified']),
      featured: _bool(json['featured']),
    );
  }

  String get kindLabel {
    switch (kind) {
      case 'shop':
        return 'دووکان';
      case 'market':
        return 'بازاڕ';
      case 'module':
        return 'خزمەتگوزاری';
      default:
        return 'ئەنجام';
    }
  }
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'yes';
}

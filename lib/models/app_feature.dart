class AppFeature {
  final String key;
  final String group;
  final String title;
  final String subtitle;
  final String icon;
  final String contentMode;
  final bool requiresLocation;
  final int sortOrder;

  const AppFeature({
    required this.key,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.contentMode,
    required this.requiresLocation,
    required this.sortOrder,
  });

  factory AppFeature.fromJson(Map<String, dynamic> json) {
    return AppFeature(
      key: (json['feature_key'] ?? '').toString().trim(),
      group: (json['group_key'] ?? 'other').toString().trim(),
      title: (json['title_ku'] ?? '').toString().trim(),
      subtitle: (json['subtitle_ku'] ?? '').toString().trim(),
      icon: (json['icon'] ?? '').toString().trim(),
      contentMode: (json['content_mode'] ?? '').toString().trim(),
      requiresLocation: _toInt(json['requires_location']) == 1,
      sortOrder: _toInt(json['sort_order'], fallback: 100),
    );
  }
}

class AppConfig {
  final int revision;
  final List<AppFeature> features;

  const AppConfig({
    required this.revision,
    required this.features,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['features'];

    return AppConfig(
      revision: _toInt(json['revision']),
      features: raw is List
          ? raw
              .whereType<Map>()
              .map((item) => AppFeature.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.key.isNotEmpty)
              .toList()
          : const <AppFeature>[],
    );
  }

  Set<String> get enabledKeys =>
      features.map((feature) => feature.key).toSet();

  bool isEnabled(String key) => enabledKeys.contains(key);
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

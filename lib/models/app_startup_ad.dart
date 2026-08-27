class AppStartupAd {
  final bool enabled;
  final String imageUrl;
  final String? linkUrl;
  final int delaySeconds;
  final int durationSeconds;
  final String versionToken;

  const AppStartupAd({
    required this.enabled,
    required this.imageUrl,
    required this.linkUrl,
    required this.delaySeconds,
    required this.durationSeconds,
    required this.versionToken,
  });

  factory AppStartupAd.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value, int fallback) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final delay = asInt(json['delay_seconds'], 2).clamp(0, 30);
    final duration =
        asInt(json['duration_seconds'], 5).clamp(5, 300);

    final rawLink = (json['link_url'] ?? '').toString().trim();

    return AppStartupAd(
      enabled: json['enabled'] == true ||
          json['enabled']?.toString() == '1',
      imageUrl: (json['image_url'] ?? '').toString().trim(),
      linkUrl: rawLink.isEmpty ? null : rawLink,
      delaySeconds: delay,
      durationSeconds: duration,
      versionToken:
          (json['version'] ?? json['updated_at'] ?? '').toString(),
    );
  }

  String get cacheSafeImageUrl {
    if (versionToken.isEmpty) return imageUrl;

    final uri = Uri.tryParse(imageUrl);
    if (uri == null) return imageUrl;

    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'v': versionToken,
      },
    ).toString();
  }
}

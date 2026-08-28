class ModuleMedia {
  final int id;
  final String imageUrl;
  final int sortOrder;

  const ModuleMedia({
    required this.id,
    required this.imageUrl,
    required this.sortOrder,
  });

  factory ModuleMedia.fromJson(Map<String, dynamic> json) {
    return ModuleMedia(
      id: _toInt(json['id']),
      imageUrl: (json['image_url'] ?? '').toString().trim(),
      sortOrder: _toInt(json['sort_order'], fallback: 100),
    );
  }
}

class ModuleItem {
  final Map<String, dynamic> data;
  final List<ModuleMedia> media;

  const ModuleItem({
    required this.data,
    required this.media,
  });

  factory ModuleItem.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['media'];

    return ModuleItem(
      data: Map<String, dynamic>.unmodifiable(json),
      media: rawMedia is List
          ? rawMedia
              .whereType<Map>()
              .map((item) => ModuleMedia.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const <ModuleMedia>[],
    );
  }

  int get id => _toInt(data['id']);
  String get title => (data['title'] ?? '').toString().trim();
  String get summary => (data['summary'] ?? '').toString().trim();
  String get description => (data['description'] ?? '').toString().trim();
  String get cityName => (data['city_name'] ?? '').toString().trim();
  String get regionName => (data['region_name'] ?? '').toString().trim();
  String get address => (data['address_detail'] ?? '').toString().trim();
  String get phone => (data['phone'] ?? '').toString().trim();
  String get whatsapp => (data['whatsapp'] ?? '').toString().trim();
  String get externalUrl => (data['external_url'] ?? '').toString().trim();
  String get currency => (data['currency'] ?? 'IQD').toString().trim();
  bool get featured => _toInt(data['featured']) == 1;
  bool get verified => _toInt(data['verified']) == 1 || data['verified'] == true;

  String get imageUrl => (data['image_url'] ?? '').toString().trim();

  List<String> get imageUrls {
    final result = <String>[];

    if (imageUrl.isNotEmpty) {
      result.add(imageUrl);
    }

    final sorted = List<ModuleMedia>.of(media)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final item in sorted) {
      final value = item.imageUrl.trim();
      if (value.isNotEmpty && !result.contains(value)) {
        result.add(value);
      }
    }

    return result;
  }

  String get locationLabel {
    final parts = <String>[
      if (cityName.isNotEmpty) cityName,
      if (regionName.isNotEmpty) regionName,
    ];

    if (parts.isNotEmpty) return parts.join(' - ');
    if (address.isNotEmpty) return address;
    return 'شوێن دیاری نەکراوە';
  }

  dynamic value(String key) => data[key];
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

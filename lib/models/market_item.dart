class MarketItem {
  final int id;
  final String title;
  final double? price;
  final String currency;
  final String itemCondition;
  final String status;
  final bool isFeatured;
  final String? cityName;
  final String? regionName;
  final String? imageUrl;

  const MarketItem({
    required this.id,
    required this.title,
    required this.price,
    required this.currency,
    required this.itemCondition,
    required this.status,
    required this.isFeatured,
    required this.cityName,
    required this.regionName,
    required this.imageUrl,
  });

  factory MarketItem.fromJson(Map<String, dynamic> json) {
    return MarketItem(
      id: _toInt(json['id']),
      title: (json['title'] ?? '').toString(),
      price: _toDoubleOrNull(json['price']),
      currency: (json['currency'] ?? 'IQD').toString(),
      itemCondition: (json['item_condition'] ?? 'used').toString(),
      status: (json['status'] ?? 'available').toString(),
      isFeatured: _toInt(json['is_featured']) == 1,
      cityName: _nullableString(json['city_name']),
      regionName: _nullableString(json['region_name']),
      imageUrl: _nullableString(json['image_url']),
    );
  }

  String get conditionLabel {
    switch (itemCondition) {
      case 'new':
        return 'نوێ';
      case 'like_new':
        return 'وەک نوێ';
      default:
        return 'بەکارهاتوو';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'sold':
        return 'فرۆشراو';
      case 'hidden':
        return 'شاردراو';
      default:
        return 'بەردەست';
    }
  }

  String get locationLabel {
    final parts = <String>[
      if (cityName != null && cityName!.isNotEmpty) cityName!,
      if (regionName != null && regionName!.isNotEmpty) regionName!,
    ];

    return parts.isEmpty ? 'شوێن دیاری نەکراوە' : parts.join(' - ');
  }

  String get priceLabel {
    if (price == null) return 'نرخ دیاری نەکراوە';

    final value = price!;
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);

    return '$formatted $currency';
  }
}

class MarketItemDetail {
  final int id;
  final String title;
  final String description;
  final double? price;
  final String currency;
  final String? phone;
  final String? whatsapp;
  final String itemCondition;
  final String status;
  final bool isFeatured;
  final String? cityName;
  final String? regionName;
  final List<String> images;

  const MarketItemDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.phone,
    required this.whatsapp,
    required this.itemCondition,
    required this.status,
    required this.isFeatured,
    required this.cityName,
    required this.regionName,
    required this.images,
  });

  factory MarketItemDetail.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];

    return MarketItemDetail(
      id: _toInt(json['id']),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _toDoubleOrNull(json['price']),
      currency: (json['currency'] ?? 'IQD').toString(),
      phone: _nullableString(json['phone']),
      whatsapp: _nullableString(json['whatsapp']),
      itemCondition: (json['item_condition'] ?? 'used').toString(),
      status: (json['status'] ?? 'available').toString(),
      isFeatured: _toInt(json['is_featured']) == 1,
      cityName: _nullableString(json['city_name']),
      regionName: _nullableString(json['region_name']),
      images: rawImages is List
          ? rawImages
              .map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList()
          : const [],
    );
  }

  String get conditionLabel {
    switch (itemCondition) {
      case 'new':
        return 'نوێ';
      case 'like_new':
        return 'وەک نوێ';
      default:
        return 'بەکارهاتوو';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'sold':
        return 'فرۆشراو';
      case 'hidden':
        return 'شاردراو';
      default:
        return 'بەردەست';
    }
  }

  String get locationLabel {
    final parts = <String>[
      if (cityName != null && cityName!.isNotEmpty) cityName!,
      if (regionName != null && regionName!.isNotEmpty) regionName!,
    ];

    return parts.isEmpty ? 'شوێن دیاری نەکراوە' : parts.join(' - ');
  }

  String get priceLabel {
    if (price == null) return 'نرخ دیاری نەکراوە';

    final value = price!;
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);

    return '$formatted $currency';
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

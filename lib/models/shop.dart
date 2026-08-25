import 'dart:convert';

class Shop {
  final int id;
  final String name;
  final String slug;
  final String? phone;
  final String? bio;
  final String? logoUrl;
  final String? googleMapsUrl;
  final String? businessType;
  final int? cityId;
  final int? regionId;
  final String? cityName;
  final String? regionName;
  final String? addressDetail;

  const Shop({
    required this.id,
    required this.name,
    required this.slug,
    required this.phone,
    required this.bio,
    required this.logoUrl,
    required this.googleMapsUrl,
    required this.businessType,
    required this.cityId,
    required this.regionId,
    required this.cityName,
    required this.regionName,
    required this.addressDetail,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: _int(json['id']),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      phone: _str(json['phone']),
      bio: _str(json['bio']),
      logoUrl: _str(json['logo_url']),
      googleMapsUrl: _str(json['google_maps_url']),
      businessType: _str(json['business_type']),
      cityId: _nullableInt(json['city_id']),
      regionId: _nullableInt(json['region_id']),
      cityName: _str(json['city_name']),
      regionName: _str(json['region_name']),
      addressDetail: _str(json['address_detail']),
    );
  }

  String get typeLabel {
    switch ((businessType ?? '').toLowerCase()) {
      case 'restaurant':
        return 'خواردنگە';
      case 'cafe':
        return 'کافێ';
      case 'market':
        return 'مارکێت';
      case 'clothing':
        return 'جلوبەرگ';
      case 'other':
        return 'گشتی';
      default:
        final value = businessType?.trim() ?? '';
        return value.isEmpty ? 'بزنس' : value;
    }
  }

  String get locationLabel {
    final parts = <String>[
      if (cityName != null && cityName!.isNotEmpty) cityName!,
      if (regionName != null && regionName!.isNotEmpty) regionName!,
    ];

    if (parts.isNotEmpty) return parts.join(' - ');

    if (addressDetail != null && addressDetail!.isNotEmpty) {
      return addressDetail!;
    }

    return 'شوێن دیاری نەکراوە';
  }
}

class ShopCity {
  final int id;
  final String name;

  const ShopCity({
    required this.id,
    required this.name,
  });

  factory ShopCity.fromJson(Map<String, dynamic> json) {
    return ShopCity(
      id: _int(json['id']),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class ShopRegion {
  final int id;
  final int cityId;
  final String name;

  const ShopRegion({
    required this.id,
    required this.cityId,
    required this.name,
  });

  factory ShopRegion.fromJson(Map<String, dynamic> json) {
    return ShopRegion(
      id: _int(json['id']),
      cityId: _int(json['city_id']),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class ShopBusinessType {
  final String key;
  final String name;

  const ShopBusinessType({
    required this.key,
    required this.name,
  });

  factory ShopBusinessType.fromJson(Map<String, dynamic> json) {
    return ShopBusinessType(
      key: (json['key'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class ShopMetadata {
  final List<ShopCity> cities;
  final List<ShopRegion> regions;
  final List<ShopBusinessType> businessTypes;

  const ShopMetadata({
    required this.cities,
    required this.regions,
    required this.businessTypes,
  });
}


class ShopCoordinates {
  final double lat;
  final double lng;

  const ShopCoordinates({
    required this.lat,
    required this.lng,
  });

  factory ShopCoordinates.fromJson(
    Map<String, dynamic> json,
  ) {
    return ShopCoordinates(
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lng'].toString()),
    );
  }
}

class ShopDetail {
  final Shop shop;
  final String? workingHours;
  final List<ShopSocialLink> socialLinks;
  final List<ShopCategory> categories;
  final List<ShopMenuItem> menuItems;

  const ShopDetail({
    required this.shop,
    required this.workingHours,
    required this.socialLinks,
    required this.categories,
    required this.menuItems,
  });

  factory ShopDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['menu_items'];
    final rawCategories = json['shop_categories'];

    return ShopDetail(
      shop: Shop.fromJson(json),
      workingHours: _str(json['working_hours']),
      socialLinks: _parseSocialLinks(json['social_links']),
      categories: rawCategories is List
          ? rawCategories
              .whereType<Map<String, dynamic>>()
              .map(ShopCategory.fromJson)
              .toList()
          : const [],
      menuItems: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(ShopMenuItem.fromJson)
              .toList()
          : const [],
    );
  }
}

class ShopSocialLink {
  final String platform;
  final String url;

  const ShopSocialLink({
    required this.platform,
    required this.url,
  });

  factory ShopSocialLink.fromJson(Map<String, dynamic> json) {
    return ShopSocialLink(
      platform: (json['platform'] ?? json['name'] ?? 'Link')
          .toString()
          .trim(),
      url: (json['url'] ?? json['link'] ?? '').toString().trim(),
    );
  }

  String get label {
    final p = platform.toLowerCase();

    if (p.contains('instagram')) return 'Instagram';
    if (p.contains('facebook') || p.contains('فەیسبووک')) {
      return 'Facebook';
    }
    if (p.contains('whatsapp') || p.contains('واتس')) {
      return 'WhatsApp';
    }
    if (p.contains('telegram') || p.contains('تێلیگرام')) {
      return 'Telegram';
    }
    if (p.contains('tiktok')) return 'TikTok';
    if (p.contains('youtube')) return 'YouTube';
    if (p.contains('x') || p.contains('twitter')) return 'X / Twitter';

    return platform.isEmpty ? 'Link' : platform;
  }
}

class ShopCategory {
  final int id;
  final String name;
  final String icon;

  const ShopCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory ShopCategory.fromJson(Map<String, dynamic> json) {
    return ShopCategory(
      id: _int(json['category_id'] ?? json['id']),
      name: (json['name'] ?? '').toString(),
      icon: (json['icon'] ?? '•').toString(),
    );
  }
}

class ShopMenuItem {
  final int id;
  final int? categoryId;
  final String title;
  final double? price;
  final String? description;
  final String? imageUrl;

  const ShopMenuItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.price,
    required this.description,
    required this.imageUrl,
  });

  factory ShopMenuItem.fromJson(Map<String, dynamic> json) {
    return ShopMenuItem(
      id: _int(json['id']),
      categoryId: _nullableInt(json['category_id']),
      title: (json['title'] ?? '').toString(),
      price: _double(json['price']),
      description: _str(json['description']),
      imageUrl: _str(json['image_url']),
    );
  }

  String get priceLabel {
    if (price == null) return '';

    final value = price!;
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}

List<ShopSocialLink> _parseSocialLinks(dynamic value) {
  dynamic decoded = value;

  if (decoded is String) {
    final text = decoded.trim();

    if (text.isEmpty) return const [];

    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const [];
    }
  }

  if (decoded is! List) {
    return const [];
  }

  final result = <ShopSocialLink>[];

  for (final item in decoded) {
    if (item is Map) {
      final map = <String, dynamic>{};

      item.forEach((key, value) {
        map[key.toString()] = value;
      });

      final social = ShopSocialLink.fromJson(map);

      if (social.url.isNotEmpty) {
        result.add(social);
      }
    }
  }

  return result;
}

int _int(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _double(dynamic value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}

String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

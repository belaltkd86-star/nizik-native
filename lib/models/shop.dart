import 'dart:convert';

int _toInt(dynamic value) {
  return int.tryParse('${value ?? 0}') ?? 0;
}

String _toText(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return {};
}

List<Map<String, dynamic>> _toMapList(dynamic value) {
  if (value is! List) return [];

  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

String normalizeNizikUrl(String value) {
  final url = value.trim();

  if (url.isEmpty) return '';

  if (url.startsWith('http://') ||
      url.startsWith('https://') ||
      url.startsWith('tel:') ||
      url.startsWith('mailto:') ||
      url.startsWith('sms:')) {
    return url;
  }

  if (url.startsWith('//')) {
    return 'https:$url';
  }

  if (url.startsWith('/')) {
    return 'https://my-pro.click$url';
  }

  return 'https://my-pro.click/$url';
}

class Shop {
  final int id;
  final String name;
  final String slug;
  final String logoUrl;
  final String bio;
  final String businessType;
  final int cityId;
  final int regionId;
  final String cityName;
  final String regionName;

  const Shop({
    required this.id,
    required this.name,
    required this.slug,
    required this.logoUrl,
    required this.bio,
    required this.businessType,
    required this.cityId,
    required this.regionId,
    required this.cityName,
    required this.regionName,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: _toInt(json['id']),
      name: _toText(json['name']),
      slug: _toText(json['slug']),
      logoUrl: _toText(json['logo_url'] ?? json['logoUrl']),
      bio: _toText(json['bio']),
      businessType: _toText(
        json['business_type'] ?? json['businessType'],
      ),
      cityId: _toInt(json['city_id'] ?? json['cityId']),
      regionId: _toInt(json['region_id'] ?? json['regionId']),
      cityName: _toText(json['city_name'] ?? json['cityName']),
      regionName: _toText(
        json['region_name'] ?? json['regionName'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo_url': logoUrl,
      'bio': bio,
      'business_type': businessType,
      'city_id': cityId,
      'region_id': regionId,
      'city_name': cityName,
      'region_name': regionName,
    };
  }

  String get location {
    final parts = <String>[
      if (cityName.isNotEmpty) cityName,
      if (regionName.isNotEmpty) regionName,
    ];

    if (parts.isEmpty) {
      return 'شوێن دیاری نەکراوە';
    }

    return parts.join(' • ');
  }
}

class CityOption {
  final int id;
  final String name;

  const CityOption({
    required this.id,
    required this.name,
  });

  factory CityOption.fromJson(Map<String, dynamic> json) {
    return CityOption(
      id: _toInt(json['id']),
      name: _toText(json['name']),
    );
  }
}

class RegionOption {
  final int id;
  final int cityId;
  final String name;

  const RegionOption({
    required this.id,
    required this.cityId,
    required this.name,
  });

  factory RegionOption.fromJson(Map<String, dynamic> json) {
    return RegionOption(
      id: _toInt(json['id']),
      cityId: _toInt(json['city_id']),
      name: _toText(json['name']),
    );
  }
}

class BusinessTypeOption {
  final int id;
  final String code;
  final String name;
  final String icon;

  const BusinessTypeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.icon,
  });

  factory BusinessTypeOption.fromJson(Map<String, dynamic> json) {
    return BusinessTypeOption(
      id: _toInt(json['id']),
      code: _toText(json['code']),
      name: _toText(json['name']),
      icon: _toText(json['icon']),
    );
  }

  String get filterValue {
    if (code.isNotEmpty) return code;
    return id.toString();
  }

  bool matches(String value) {
    final v = value.trim();

    return v == id.toString() ||
        (code.isNotEmpty && v == code) ||
        v == filterValue ||
        v == name;
  }
}

class ShopsResponse {
  final List<Shop> shops;
  final List<CityOption> cities;
  final List<RegionOption> regions;
  final List<BusinessTypeOption> businessTypes;
  final int page;
  final int? total;
  final bool hasMore;

  const ShopsResponse({
    required this.shops,
    required this.cities,
    required this.regions,
    required this.businessTypes,
    required this.page,
    required this.total,
    required this.hasMore,
  });

  factory ShopsResponse.fromJson(Map<String, dynamic> json) {
    final totalValue = json['total'];

    return ShopsResponse(
      shops: _toMapList(json['shops']).map(Shop.fromJson).toList(),
      cities:
          _toMapList(json['cities']).map(CityOption.fromJson).toList(),
      regions: _toMapList(json['regions'])
          .map(RegionOption.fromJson)
          .toList(),
      businessTypes: _toMapList(json['business_types'])
          .map(BusinessTypeOption.fromJson)
          .toList(),
      page: _toInt(json['page']),
      total: totalValue == null ? null : _toInt(totalValue),
      hasMore: json['has_more'] == true ||
          json['has_more'] == 1 ||
          json['has_more'] == '1',
    );
  }
}

class SocialLink {
  final String platform;
  final String url;

  const SocialLink({
    required this.platform,
    required this.url,
  });

  factory SocialLink.fromJson(Map<String, dynamic> json) {
    return SocialLink(
      platform: _toText(
        json['platform'] ?? json['name'] ?? json['type'],
      ),
      url: _toText(
        json['url'] ?? json['link'] ?? json['value'],
      ),
    );
  }
}

class MenuCategory {
  final int categoryId;
  final String name;
  final String icon;

  const MenuCategory({
    required this.categoryId,
    required this.name,
    required this.icon,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      categoryId: _toInt(json['category_id'] ?? json['id']),
      name: _toText(json['name']),
      icon: _toText(json['icon']),
    );
  }
}

class MenuItem {
  final int id;
  final int categoryId;
  final String title;
  final String price;
  final String description;
  final String imageUrl;

  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.price,
    required this.description,
    required this.imageUrl,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: _toInt(json['id']),
      categoryId: _toInt(json['category_id']),
      title: _toText(json['title']),
      price: _toText(json['price']),
      description: _toText(json['description']),
      imageUrl: _toText(
        json['image_url'] ?? json['photo_url'] ?? json['image'],
      ),
    );
  }
}

class ShopProfileData {
  final int userId;
  final String name;
  final String slug;

  final String logoUrl;
  final String bio;
  final String googleMapsUrl;
  final String addressDetail;

  final String businessTypeRaw;
  final String businessTypeName;
  final String businessTypeIcon;

  final int cityId;
  final int regionId;
  final String cityName;
  final String regionName;

  final List<SocialLink> socialLinks;
  final List<MenuCategory> categories;
  final List<MenuItem> items;

  const ShopProfileData({
    required this.userId,
    required this.name,
    required this.slug,
    required this.logoUrl,
    required this.bio,
    required this.googleMapsUrl,
    required this.addressDetail,
    required this.businessTypeRaw,
    required this.businessTypeName,
    required this.businessTypeIcon,
    required this.cityId,
    required this.regionId,
    required this.cityName,
    required this.regionName,
    required this.socialLinks,
    required this.categories,
    required this.items,
  });

  factory ShopProfileData.fromJson(Map<String, dynamic> json) {
    final user = _toMap(json['user']);
    final profile = _toMap(json['profile']);

    final types = _toMapList(json['business_types'])
        .map(BusinessTypeOption.fromJson)
        .toList();

    final cities =
        _toMapList(json['cities']).map(CityOption.fromJson).toList();

    final regions = _toMapList(json['regions'])
        .map(RegionOption.fromJson)
        .toList();

    final businessTypeRaw = _toText(profile['business_type']);

    BusinessTypeOption? businessType;

    for (final type in types) {
      if (type.matches(businessTypeRaw)) {
        businessType = type;
        break;
      }
    }

    final cityId = _toInt(profile['city_id']);
    final regionId = _toInt(profile['region_id']);

    String cityName = '';
    String regionName = '';

    for (final city in cities) {
      if (city.id == cityId) {
        cityName = city.name;
        break;
      }
    }

    for (final region in regions) {
      if (region.id == regionId) {
        regionName = region.name;
        break;
      }
    }

    final socialLinks = <SocialLink>[];
    dynamic socialRaw = profile['social_links'];

    if (socialRaw is String && socialRaw.trim().isNotEmpty) {
      try {
        socialRaw = jsonDecode(socialRaw);
      } catch (_) {
        socialRaw = null;
      }
    }

    if (socialRaw is List) {
      for (final item in socialRaw) {
        if (item is Map) {
          final social = SocialLink.fromJson(
            Map<String, dynamic>.from(item),
          );

          if (social.url.trim().isNotEmpty) {
            socialLinks.add(social);
          }
        }
      }
    } else if (socialRaw is Map) {
      final map = Map<String, dynamic>.from(socialRaw);

      for (final entry in map.entries) {
        final value = _toText(entry.value).trim();

        if (value.isNotEmpty) {
          socialLinks.add(
            SocialLink(
              platform: entry.key,
              url: value,
            ),
          );
        }
      }
    }

    return ShopProfileData(
      userId: _toInt(user['id']),
      name: _toText(user['name']),
      slug: _toText(user['slug']),
      logoUrl: _toText(profile['logo_url']),
      bio: _toText(profile['bio']),
      googleMapsUrl: _toText(profile['google_maps_url']),
      addressDetail: _toText(profile['address_detail']),
      businessTypeRaw: businessTypeRaw,
      businessTypeName: businessType?.name ??
          (businessTypeRaw.isEmpty ? 'دوکان' : businessTypeRaw),
      businessTypeIcon: businessType?.icon.isNotEmpty == true
          ? businessType!.icon
          : '🏪',
      cityId: cityId,
      regionId: regionId,
      cityName: cityName,
      regionName: regionName,
      socialLinks: socialLinks,
      categories: _toMapList(
        json['shop_categories'] ?? json['categories'],
      ).map(MenuCategory.fromJson).toList(),
      items: _toMapList(json['items']).map(MenuItem.fromJson).toList(),
    );
  }

  String get locationText {
    final parts = <String>[
      if (cityName.isNotEmpty) cityName,
      if (regionName.isNotEmpty) regionName,
      if (addressDetail.isNotEmpty) addressDetail,
    ];

    return parts.join(' • ');
  }

  List<String> get galleryUrls {
    final result = <String>[];

    for (final item in items) {
      final url = normalizeNizikUrl(item.imageUrl);

      if (url.isNotEmpty && !result.contains(url)) {
        result.add(url);
      }
    }

    return result;
  }

  Shop toShop() {
    return Shop(
      id: userId,
      name: name,
      slug: slug,
      logoUrl: logoUrl,
      bio: bio,
      businessType: businessTypeRaw,
      cityId: cityId,
      regionId: regionId,
      cityName: cityName,
      regionName: regionName,
    );
  }
}

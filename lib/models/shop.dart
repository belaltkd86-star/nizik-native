import 'dart:convert';

import '../security/nizik_network.dart';

class Shop {
  final int id;
  final String name;
  final String slug;
  final String? phone;
  final String? bio;
  final String? logoUrl;
  final String? googleMapsUrl;
  final String? businessType;
  final String? businessTypeName;
  final String? businessTypeIcon;
  final int? cityId;
  final int? regionId;
  final String? cityName;
  final String? regionName;
  final String? addressDetail;
  final bool isPinned;
  final bool isVerified;
  final ShopOpeningStatus? openingStatus;

  const Shop({
    required this.id,
    required this.name,
    required this.slug,
    required this.phone,
    required this.bio,
    required this.logoUrl,
    required this.googleMapsUrl,
    required this.businessType,
    this.businessTypeName,
    this.businessTypeIcon,
    required this.cityId,
    required this.regionId,
    required this.cityName,
    required this.regionName,
    required this.addressDetail,
    required this.isPinned,
    this.isVerified = false,
    this.openingStatus,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: _int(json['id']),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      phone: _str(json['phone']),
      bio: _str(json['bio']),
      logoUrl: _mediaUrl(json['logo_url']),
      googleMapsUrl: _str(json['google_maps_url']),
      businessType: _str(json['business_type']),
      businessTypeName: _str(json['business_type_name']),
      businessTypeIcon: _str(json['business_type_icon']),
      cityId: _nullableInt(json['city_id']),
      regionId: _nullableInt(json['region_id']),
      cityName: _str(json['city_name']),
      regionName: _str(json['region_name']),
      addressDetail: _str(json['address_detail']),
      isPinned: _int(json['is_pinned']) == 1 || json['is_pinned'] == true,
      isVerified: _int(json['is_verified']) == 1 || json['is_verified'] == true,
      openingStatus: json['opening_status'] is Map
          ? ShopOpeningStatus.fromJson(
              Map<String, dynamic>.from(json['opening_status'] as Map),
            )
          : null,
    );
  }

  String get typeLabel {
    final label = businessTypeName?.trim() ?? '';
    if (label.isNotEmpty) return label;

    final value = businessType?.trim() ?? '';
    return value.isEmpty ? 'بزنس' : value;
  }

  String get typeIcon {
    final icon = businessTypeIcon?.trim() ?? '';
    return icon.isEmpty ? '🏪' : icon;
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

  // Compatibility getter used by the map/profile UI.
  String get location => locationLabel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'slug': slug,
      'phone': phone,
      'bio': bio,
      'logo_url': logoUrl,
      'google_maps_url': googleMapsUrl,
      'business_type': businessType,
      'business_type_name': businessTypeName,
      'business_type_icon': businessTypeIcon,
      'city_id': cityId,
      'region_id': regionId,
      'city_name': cityName,
      'region_name': regionName,
      'address_detail': addressDetail,
      'is_pinned': isPinned ? 1 : 0,
      'is_verified': isVerified ? 1 : 0,
      if (openingStatus != null) 'opening_status': openingStatus!.toJson(),
    };
  }
}


class ShopOpeningStatus {
  final bool isOpen;
  final String state;
  final String label;
  final String? nextChange;
  final int? nextOpenWeekday;
  final String? nextOpenTime;
  final int? nextOpenDaysAhead;

  const ShopOpeningStatus({
    required this.isOpen,
    required this.state,
    required this.label,
    this.nextChange,
    this.nextOpenWeekday,
    this.nextOpenTime,
    this.nextOpenDaysAhead,
  });

  factory ShopOpeningStatus.fromJson(Map<String, dynamic> json) {
    final nextOpen = json['next_open'];
    final nextMap = nextOpen is Map
        ? Map<String, dynamic>.from(nextOpen)
        : const <String, dynamic>{};
    return ShopOpeningStatus(
      isOpen: _bool(json['is_open']),
      state: (json['state'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
      nextChange: _str(json['next_change']),
      nextOpenWeekday: _nullableInt(nextMap['weekday']),
      nextOpenTime: _str(nextMap['time']),
      nextOpenDaysAhead: _nullableInt(nextMap['days_ahead']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'is_open': isOpen,
        'state': state,
        'label': label,
        'next_change': nextChange,
        if (nextOpenWeekday != null || nextOpenTime != null)
          'next_open': <String, dynamic>{
            'weekday': nextOpenWeekday,
            'time': nextOpenTime,
            'days_ahead': nextOpenDaysAhead,
          },
      };

  String get compactLabel {
    if (isOpen && nextChange != null && nextChange!.isNotEmpty) {
      return 'کراوەیە • تا $nextChange';
    }
    return label.isEmpty ? (isOpen ? 'کراوەیە' : 'داخراوە') : label;
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
  final int id;
  final String key;
  final String name;
  final String icon;
  final int shopCount;

  const ShopBusinessType({
    this.id = 0,
    required this.key,
    required this.name,
    this.icon = '🏪',
    this.shopCount = 0,
  });

  factory ShopBusinessType.fromJson(Map<String, dynamic> json) {
    return ShopBusinessType(
      id: _int(json['id']),
      key: (json['key'] ?? json['code'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      icon: (json['icon'] ?? '🏪').toString().trim(),
      shopCount: _int(json['shop_count']),
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

  int get categoryId => id;
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
      imageUrl: _mediaUrl(json['image_url']),
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



/// Business-type model used by the paged public shop API and map filters.
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
      id: _int(json['id']),
      code: (json['code'] ?? json['key'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      icon: (json['icon'] ?? '🏪').toString().trim(),
    );
  }

  String get filterValue {
    final value = code.trim();
    return value.isNotEmpty ? value : name.trim().toLowerCase();
  }

  bool matches(String? value) {
    final candidate = (value ?? '').trim().toLowerCase();
    if (candidate.isEmpty) return false;

    final normalizedCode = code.trim().toLowerCase();
    final normalizedName = name.trim().toLowerCase();

    return (normalizedCode.isNotEmpty && candidate == normalizedCode) ||
        (normalizedName.isNotEmpty && candidate == normalizedName);
  }
}

/// Response model for /public/index.php?action=shops.
class ShopsResponse {
  final List<Shop> shops;
  final List<ShopCity> cities;
  final List<ShopRegion> regions;
  final List<BusinessTypeOption> businessTypes;
  final int page;
  final int total;
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
    return ShopsResponse(
      shops: _mapList(json['shops']).map(Shop.fromJson).toList(),
      cities: _mapList(json['cities']).map(ShopCity.fromJson).toList(),
      regions: _mapList(json['regions']).map(ShopRegion.fromJson).toList(),
      businessTypes: _mapList(json['business_types'])
          .map(BusinessTypeOption.fromJson)
          .toList(),
      page: _int(json['page']) <= 0 ? 1 : _int(json['page']),
      total: _int(json['total']),
      hasMore: _bool(json['has_more']),
    );
  }
}

/// Compatibility alias for the public-profile contact UI.
typedef SocialLink = ShopSocialLink;

/// Public-profile menu item. The profile sheet renders these values as text,
/// so price/description/image are intentionally normalized to non-null strings.
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
      id: _int(json['id']),
      categoryId: _int(json['category_id']),
      title: (json['title'] ?? json['name'] ?? '').toString().trim(),
      price: (json['price'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      imageUrl: _mediaUrl(
            json['image_url'] ?? json['photo_url'] ?? json['image'],
          ) ??
          '',
    );
  }
}

/// Model for client_api.php?action=get_public_profile.
/// It accepts both the older client_api nested response and the newer public
/// response shape, so cached/profile data remains backwards compatible.
class ShopProfileData {
  final int id;
  final String name;
  final String slug;
  final String phone;
  final String bio;
  final String workingHours;
  final String logoUrl;
  final String googleMapsUrl;
  final String businessType;
  final String businessTypeName;
  final String businessTypeIcon;
  final int? cityId;
  final int? regionId;
  final String cityName;
  final String regionName;
  final String addressDetail;
  final List<ShopCategory> categories;
  final List<MenuItem> items;
  final List<SocialLink> socialLinks;
  final bool isPinned;

  const ShopProfileData({
    required this.id,
    required this.name,
    required this.slug,
    required this.phone,
    required this.bio,
    required this.workingHours,
    required this.logoUrl,
    required this.googleMapsUrl,
    required this.businessType,
    required this.businessTypeName,
    required this.businessTypeIcon,
    required this.cityId,
    required this.regionId,
    required this.cityName,
    required this.regionName,
    required this.addressDetail,
    required this.categories,
    required this.items,
    required this.socialLinks,
    required this.isPinned,
  });

  factory ShopProfileData.fromJson(Map<String, dynamic> json) {
    final user = _asStringMap(json['user']);
    final profile = _asStringMap(json['profile']);

    // Some public endpoints may return a flattened shop/profile object.
    final sourceUser = user.isEmpty ? json : user;
    final sourceProfile = profile.isEmpty ? json : profile;

    final cityId = _nullableInt(sourceProfile['city_id']);
    final regionId = _nullableInt(sourceProfile['region_id']);

    var cityName = _str(sourceProfile['city_name']) ?? '';
    var regionName = _str(sourceProfile['region_name']) ?? '';

    if (cityName.isEmpty && cityId != null) {
      for (final city in _mapList(json['cities'])) {
        if (_int(city['id']) == cityId) {
          cityName = (city['name'] ?? '').toString().trim();
          break;
        }
      }
    }

    if (regionName.isEmpty && regionId != null) {
      for (final region in _mapList(json['regions'])) {
        if (_int(region['id']) == regionId) {
          regionName = (region['name'] ?? '').toString().trim();
          break;
        }
      }
    }

    final businessType =
        (_str(sourceProfile['business_type']) ?? '').toLowerCase();

    String businessTypeName = '';
    String businessTypeIcon = '';

    for (final rawType in _mapList(json['business_types'])) {
      final type = BusinessTypeOption.fromJson(rawType);
      if (type.matches(businessType)) {
        businessTypeName = type.name;
        businessTypeIcon = type.icon;
        break;
      }
    }

    if (businessTypeName.isEmpty) {
      businessTypeName = _businessTypeLabel(businessType);
    }
    if (businessTypeIcon.isEmpty) {
      businessTypeIcon = _businessTypeIcon(businessType);
    }

    final rawCategories = json['shop_categories'] ??
        sourceProfile['shop_categories'] ??
        json['categories'];
    final rawItems = json['items'] ??
        sourceProfile['items'] ??
        json['menu_items'];

    final categories = _mapList(rawCategories)
        .map(ShopCategory.fromJson)
        .toList();
    final items = _mapList(rawItems).map(MenuItem.fromJson).toList();

    return ShopProfileData(
      id: _int(sourceUser['id'] ?? sourceProfile['user_id']),
      name: (sourceUser['name'] ?? sourceProfile['name'] ?? '')
          .toString()
          .trim(),
      slug: (sourceUser['slug'] ?? sourceProfile['slug'] ?? '')
          .toString()
          .trim(),
      phone: (_str(sourceUser['phone'] ?? sourceProfile['phone']) ?? ''),
      bio: _str(sourceProfile['bio']) ?? '',
      workingHours: _str(sourceProfile['working_hours']) ?? '',
      logoUrl: _mediaUrl(sourceProfile['logo_url']) ?? '',
      googleMapsUrl: _str(sourceProfile['google_maps_url']) ?? '',
      businessType: businessType,
      businessTypeName: businessTypeName,
      businessTypeIcon: businessTypeIcon,
      cityId: cityId,
      regionId: regionId,
      cityName: cityName,
      regionName: regionName,
      addressDetail: _str(sourceProfile['address_detail']) ?? '',
      categories: categories,
      items: items,
      socialLinks: _parseSocialLinks(sourceProfile['social_links']),
      isPinned: _bool(sourceProfile['is_pinned'] ?? sourceUser['is_pinned']),
    );
  }

  String get locationText {
    final parts = <String>[
      if (cityName.trim().isNotEmpty) cityName.trim(),
      if (regionName.trim().isNotEmpty) regionName.trim(),
      if (addressDetail.trim().isNotEmpty) addressDetail.trim(),
    ];
    return parts.join(' • ');
  }

  List<String> get galleryUrls {
    final seen = <String>{};
    final result = <String>[];

    for (final item in items) {
      final url = normalizeNizikUrl(item.imageUrl);
      if (url.isNotEmpty && seen.add(url)) {
        result.add(url);
      }
    }

    return result;
  }

  Shop toShop() {
    return Shop(
      id: id,
      name: name,
      slug: slug,
      phone: phone.isEmpty ? null : phone,
      bio: bio.isEmpty ? null : bio,
      logoUrl: logoUrl.isEmpty ? null : logoUrl,
      googleMapsUrl: googleMapsUrl.isEmpty ? null : googleMapsUrl,
      businessType: businessType.isEmpty ? null : businessType,
      businessTypeName: businessTypeName.isEmpty ? null : businessTypeName,
      businessTypeIcon: businessTypeIcon.isEmpty ? null : businessTypeIcon,
      cityId: cityId,
      regionId: regionId,
      cityName: cityName.isEmpty ? null : cityName,
      regionName: regionName.isEmpty ? null : regionName,
      addressDetail: addressDetail.isEmpty ? null : addressDetail,
      isPinned: isPinned,
    );
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



Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];

  final result = <Map<String, dynamic>>[];
  for (final item in value) {
    final map = _asStringMap(item);
    if (map.isNotEmpty) {
      result.add(map);
    }
  }
  return result;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'yes';
}

String _businessTypeLabel(String code) {
  switch (code.trim().toLowerCase()) {
    case 'restaurant':
      return 'خواردنگە';
    case 'cafe':
      return 'کافێ';
    case 'market':
      return 'سوپەرمارکێت';
    case 'clothing':
      return 'جلوبەرگ';
    case 'other':
      return 'گشتی';
    default:
      final value = code.trim();
      return value.isEmpty ? 'دوکان' : value;
  }
}

String _businessTypeIcon(String code) {
  switch (code.trim().toLowerCase()) {
    case 'restaurant':
      return '🍔';
    case 'cafe':
      return '☕';
    case 'market':
      return '🛒';
    case 'clothing':
      return '👕';
    default:
      return '🏪';
  }
}

String? _mediaUrl(dynamic value) {
  final raw = _str(value);
  if (raw == null) return null;

  final normalized = normalizeNizikUrl(raw);
  return normalized.isEmpty ? null : normalized;
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

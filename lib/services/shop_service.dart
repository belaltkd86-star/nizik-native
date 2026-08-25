import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shop.dart';

class ShopService {
  static const String _baseUrl =
      'https://my-pro.click/api/shops_public.php';

  static Future<ShopMetadata> fetchMetadata() async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': 'metadata',
      },
    );

    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode != 200) {
      throw Exception('فلتەرەکان لۆد نەکران.');
    }

    final dynamic decoded =
        jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true) {
      throw Exception(
        decoded is Map<String, dynamic>
            ? (decoded['error'] ?? 'هەڵەی نەناسراو').toString()
            : 'داتای API دروست نییە.',
      );
    }

    final rawCities = decoded['cities'];
    final rawRegions = decoded['regions'];
    final rawTypes = decoded['business_types'];

    return ShopMetadata(
      cities: rawCities is List
          ? rawCities
              .whereType<Map<String, dynamic>>()
              .map(ShopCity.fromJson)
              .toList()
          : const [],
      regions: rawRegions is List
          ? rawRegions
              .whereType<Map<String, dynamic>>()
              .map(ShopRegion.fromJson)
              .toList()
          : const [],
      businessTypes: rawTypes is List
          ? rawTypes
              .whereType<Map<String, dynamic>>()
              .map(ShopBusinessType.fromJson)
              .toList()
          : const [],
    );
  }

  static Future<List<Shop>> fetchShops({
    String? query,
    String? type,
    int? cityId,
    int? regionId,
  }) async {
    final params = <String, String>{
      'action': 'list',
    };

    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }

    if (type != null && type.isNotEmpty && type != 'all') {
      params['type'] = type;
    }

    if (cityId != null) {
      params['city_id'] = cityId.toString();
    }

    if (regionId != null) {
      params['region_id'] = regionId.toString();
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: params,
    );

    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode != 200) {
      throw Exception('هەڵە لە پەیوەندی بە سێرڤەر.');
    }

    final dynamic decoded =
        jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true) {
      throw Exception(
        decoded is Map<String, dynamic>
            ? (decoded['error'] ?? 'هەڵەی نەناسراو').toString()
            : 'داتای API دروست نییە.',
      );
    }

    final rawShops = decoded['shops'];

    if (rawShops is! List) {
      return [];
    }

    return rawShops
        .whereType<Map<String, dynamic>>()
        .map(Shop.fromJson)
        .toList();
  }

  static Future<ShopDetail> fetchDetail(String slug) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': 'detail',
        'slug': slug,
      },
    );

    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode != 200) {
      throw Exception('وردەکاری دووکانەکە لۆد نەکرا.');
    }

    final dynamic decoded =
        jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true) {
      throw Exception(
        decoded is Map<String, dynamic>
            ? (decoded['error'] ?? 'هەڵەی نەناسراو').toString()
            : 'داتای API دروست نییە.',
      );
    }

    final rawShop = decoded['shop'];

    if (rawShop is! Map<String, dynamic>) {
      throw Exception('داتای دووکانەکە دروست نییە.');
    }

    return ShopDetail.fromJson(rawShop);
  }

  static Future<ShopCoordinates> resolveCoordinates(
    String slug,
  ) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': 'coords',
        'shop': slug,
      },
    );

    final response = await http.get(uri).timeout(
      const Duration(seconds: 12),
    );

    final dynamic decoded =
        jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode != 200 ||
        decoded is! Map<String, dynamic> ||
        decoded['success'] != true) {
      throw Exception(
        decoded is Map<String, dynamic>
            ? (decoded['error'] ??
                    'شوێنی دووکانەکە دیاری نەکرا.')
                .toString()
            : 'شوێنی دووکانەکە دیاری نەکرا.',
      );
    }

    return ShopCoordinates.fromJson(decoded);
  }

}

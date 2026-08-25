import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shop.dart';
import 'local_store_service.dart';

class ApiService {
  static const String _shopsUrl =
      'https://my-pro.click/public/index.php';

  static const String _clientApiUrl =
      'https://my-pro.click/api/client_api.php';

  final LocalStoreService _store = LocalStoreService.instance;

  String _shopsCacheKey({
    required String search,
    required int cityId,
    required int regionId,
    required String businessType,
    required int page,
    required bool meta,
  }) {
    final raw = [
      search.trim(),
      cityId,
      regionId,
      businessType,
      page,
      meta ? 1 : 0,
    ].join('|');

    return 'shops_${base64Url.encode(utf8.encode(raw))}';
  }

  Future<ShopsResponse> getShops({
    String search = '',
    int cityId = 0,
    int regionId = 0,
    String businessType = '',
    int page = 1,
    bool meta = false,
  }) async {
    final cacheKey = _shopsCacheKey(
      search: search,
      cityId: cityId,
      regionId: regionId,
      businessType: businessType,
      page: page,
      meta: meta,
    );

    final uri = Uri.parse(_shopsUrl).replace(
      queryParameters: {
        'action': 'shops',
        'page': page.toString(),
        'meta': meta ? '1' : '0',
        'search': search.trim(),
        'city_id': cityId.toString(),
        'region_id': regionId.toString(),
        'business_type': businessType,
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception(
          'API Error: ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception('وەڵامی API دروست نییە');
      }

      final data = Map<String, dynamic>.from(decoded);

      if (data['success'] != true) {
        throw Exception(
          data['error']?.toString() ??
              data['message']?.toString() ??
              'نەتوانرا دوکانەکان بهێنرێن',
        );
      }

      await _store.cacheJson(cacheKey, data);

      return ShopsResponse.fromJson(data);
    } catch (networkError) {
      final cached = await _store.readCachedJson(cacheKey);

      if (cached != null) {
        return ShopsResponse.fromJson(cached);
      }

      rethrow;
    }
  }

  Future<ShopProfileData> getPublicProfile(
    String slug,
  ) async {
    final cacheKey =
        'profile_${base64Url.encode(utf8.encode(slug.trim()))}';

    final uri = Uri.parse(_clientApiUrl).replace(
      queryParameters: {
        'action': 'get_public_profile',
        'slug': slug.trim(),
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception(
          'Profile API Error: ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception('وەڵامی پڕۆفایل دروست نییە');
      }

      final data = Map<String, dynamic>.from(decoded);

      if (data['success'] != true) {
        throw Exception(
          data['error']?.toString() ??
              data['message']?.toString() ??
              'نەتوانرا پڕۆفایلەکە بهێنرێت',
        );
      }

      await _store.cacheJson(cacheKey, data);

      return ShopProfileData.fromJson(data);
    } catch (networkError) {
      final cached = await _store.readCachedJson(cacheKey);

      if (cached != null) {
        return ShopProfileData.fromJson(cached);
      }

      rethrow;
    }
  }
}

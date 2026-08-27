import 'dart:convert';

import '../security/nizik_network.dart';

import '../models/shop.dart';
import 'local_store_service.dart';

class ApiService {
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

    final uri = NizikEndpoints.uri(
      '/public/index.php',
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
      final response = await NizikNetwork.get(
        uri,
        timeout: const Duration(seconds: 20),
      );

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

    final uri = NizikEndpoints.uri(
      '/api/client_api.php',
      queryParameters: {
        'action': 'get_public_profile',
        'slug': slug.trim(),
      },
    );

    try {
      final response = await NizikNetwork.get(
        uri,
        timeout: const Duration(seconds: 20),
      );

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

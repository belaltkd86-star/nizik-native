import 'dart:convert';

import '../security/nizik_network.dart';

import '../models/market_item.dart';

class MarketService {
  static Future<List<MarketItem>> fetchItems({
    String? query,
  }) async {
    final params = <String, String>{
      'action': 'list',
    };

    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }

    final uri = NizikEndpoints.uri(
      '/api/market_public.php',
      queryParameters: params,
    );

    final response = await NizikNetwork.get(
      uri,
      timeout: const Duration(seconds: 20),
    );

    if (response.statusCode != 200) {
      throw Exception('هەڵە لە پەیوەندی بە سێرڤەر.');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data is! Map<String, dynamic> || data['success'] != true) {
      throw Exception(
        data is Map<String, dynamic>
            ? (data['error'] ?? 'هەڵەی نەناسراو').toString()
            : 'داتای API دروست نییە.',
      );
    }

    final items = data['items'];

    if (items is! List) {
      return [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(MarketItem.fromJson)
        .toList();
  }

  static Future<MarketItemDetail> fetchDetail(int id) async {
    final uri = NizikEndpoints.uri(
      '/api/market_public.php',
      queryParameters: {
        'action': 'detail',
        'id': id.toString(),
      },
    );

    final response = await NizikNetwork.get(
      uri,
      timeout: const Duration(seconds: 20),
    );

    if (response.statusCode != 200) {
      throw Exception('وردەکاری کاڵاکە لۆد نەکرا.');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data is! Map<String, dynamic> || data['success'] != true) {
      throw Exception(
        data is Map<String, dynamic>
            ? (data['error'] ?? 'هەڵەی نەناسراو').toString()
            : 'داتای API دروست نییە.',
      );
    }

    final item = data['item'];

    if (item is! Map<String, dynamic>) {
      throw Exception('وردەکاری کاڵاکە دروست نییە.');
    }

    return MarketItemDetail.fromJson(item);
  }
}

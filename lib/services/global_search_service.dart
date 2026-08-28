import 'dart:convert';

import '../models/global_search_result.dart';
import '../security/nizik_network.dart';

class GlobalSearchService {
  GlobalSearchService._();

  static Future<List<GlobalSearchResult>> search({
    required String query,
    int? cityId,
    int? regionId,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return const <GlobalSearchResult>[];

    final params = <String, String>{'q': clean};
    if (cityId != null) params['city_id'] = cityId.toString();
    if (regionId != null) params['region_id'] = regionId.toString();

    final uri = NizikEndpoints.uri(
      '/api/global_search.php',
      queryParameters: params,
    );

    final response = await NizikNetwork.get(
      uri,
      timeout: const Duration(seconds: 20),
    );

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['success'] != true) {
      throw Exception(
        decoded is Map
            ? (decoded['error'] ?? 'گەڕان سەرکەوتوو نەبوو.').toString()
            : 'گەڕان سەرکەوتوو نەبوو.',
      );
    }

    final raw = decoded['results'];
    if (raw is! List) return const <GlobalSearchResult>[];

    return raw
        .whereType<Map>()
        .map((item) => GlobalSearchResult.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
  }
}

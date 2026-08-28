import 'dart:convert';

import '../models/module_item.dart';
import '../models/module_spec.dart';
import '../security/nizik_network.dart';
import 'local_store_service.dart';

class ModuleService {
  ModuleService._();

  static String _cacheKey(
    ModuleSpec spec, {
    required String action,
    int? id,
    String query = '',
    int? cityId,
    int? regionId,
    String? filterKey,
    String? filterValue,
  }) {
    final raw = <Object?>[
      spec.key,
      action,
      id ?? 0,
      query.trim(),
      cityId ?? 0,
      regionId ?? 0,
      filterKey ?? '',
      filterValue ?? '',
    ].join('|');

    return 'module_${base64Url.encode(utf8.encode(raw))}';
  }

  static Future<List<ModuleItem>> fetchItems(
    ModuleSpec spec, {
    String query = '',
    int? cityId,
    int? regionId,
    String? filterKey,
    String? filterValue,
  }) async {
    final params = <String, String>{
      'action': 'list',
    };

    if (query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (cityId != null) {
      params['city_id'] = cityId.toString();
    }
    if (regionId != null) {
      params['region_id'] = regionId.toString();
    }
    if (filterKey != null &&
        filterKey.isNotEmpty &&
        filterValue != null &&
        filterValue.isNotEmpty) {
      params[filterKey] = filterValue;
    }

    final cacheKey = _cacheKey(
      spec,
      action: 'list',
      query: query,
      cityId: cityId,
      regionId: regionId,
      filterKey: filterKey,
      filterValue: filterValue,
    );

    final uri = NizikEndpoints.uri(
      '/api/modules/${spec.key}.php',
      queryParameters: params,
    );

    try {
      final response = await NizikNetwork.get(
        uri,
        timeout: const Duration(seconds: 20),
      );

      final decoded = _decodeResponse(response.bodyBytes);

      if (response.statusCode != 200 || decoded['success'] != true) {
        throw Exception(
          (decoded['error'] ?? 'داتاکانی ${spec.title} لۆد نەکران.').toString(),
        );
      }

      await LocalStoreService.instance.cacheJson(cacheKey, decoded);

      final rawItems = decoded['items'];
      if (rawItems is! List) return const <ModuleItem>[];

      return rawItems
          .whereType<Map>()
          .map((item) => ModuleItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } catch (_) {
      final cached =
          await LocalStoreService.instance.readCachedJson(cacheKey);

      if (cached != null) {
        final rawItems = cached['items'];
        if (rawItems is List) {
          return rawItems
              .whereType<Map>()
              .map((item) => ModuleItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList();
        }
      }
      rethrow;
    }
  }

  static Future<ModuleItem> fetchDetail(
    ModuleSpec spec,
    int id,
  ) async {
    final cacheKey = _cacheKey(
      spec,
      action: 'detail',
      id: id,
    );

    final uri = NizikEndpoints.uri(
      '/api/modules/${spec.key}.php',
      queryParameters: <String, String>{
        'action': 'detail',
        'id': id.toString(),
      },
    );

    try {
      final response = await NizikNetwork.get(
        uri,
        timeout: const Duration(seconds: 20),
      );

      final decoded = _decodeResponse(response.bodyBytes);

      if (response.statusCode != 200 || decoded['success'] != true) {
        throw Exception(
          (decoded['error'] ?? 'وردەکاری ${spec.title} لۆد نەکرا.').toString(),
        );
      }

      final rawItem = decoded['item'];

      if (rawItem is! Map) {
        throw Exception('وردەکاری داتاکە دروست نییە.');
      }

      await LocalStoreService.instance.cacheJson(cacheKey, decoded);

      return ModuleItem.fromJson(
        Map<String, dynamic>.from(rawItem),
      );
    } catch (_) {
      final cached =
          await LocalStoreService.instance.readCachedJson(cacheKey);

      final rawItem = cached?['item'];
      if (rawItem is Map) {
        return ModuleItem.fromJson(
          Map<String, dynamic>.from(rawItem),
        );
      }
      rethrow;
    }
  }

  static Map<String, dynamic> _decodeResponse(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));

    if (decoded is! Map) {
      throw Exception('وەڵامی API دروست نییە.');
    }

    return Map<String, dynamic>.from(decoded);
  }
}

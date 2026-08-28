import 'dart:convert';

import '../models/app_feature.dart';
import '../security/nizik_network.dart';
import 'local_store_service.dart';

class AppConfigService {
  AppConfigService._();

  static const String _cacheKey = 'app_config_v1';

  static Future<AppConfig> fetch() async {
    final store = LocalStoreService.instance;
    final uri = NizikEndpoints.uri('/api/app_config.php');

    try {
      final response = await NizikNetwork.get(
        uri,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw Exception('ڕێکخستنی ئەپ لۆد نەکرا.');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map || decoded['success'] != true) {
        throw Exception(
          decoded is Map
              ? (decoded['error'] ?? 'ڕێکخستنی ئەپ دروست نییە.').toString()
              : 'ڕێکخستنی ئەپ دروست نییە.',
        );
      }

      final data = Map<String, dynamic>.from(decoded);
      await store.cacheJson(_cacheKey, data);
      return AppConfig.fromJson(data);
    } catch (_) {
      final cached = await store.readCachedJson(_cacheKey);
      if (cached != null) {
        return AppConfig.fromJson(cached);
      }
      rethrow;
    }
  }
}

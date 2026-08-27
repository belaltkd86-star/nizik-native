import 'dart:convert';

import '../security/nizik_network.dart';

import '../models/app_startup_ad.dart';

class AppStartupAdService {
  static Future<AppStartupAd?> fetchActiveAd() async {
    try {
      final response = await NizikNetwork.get(
        NizikEndpoints.uri('/api/app_ad.php'),
        timeout: const Duration(seconds: 5),
        headers: const {
          'Cache-Control': 'no-cache',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true) {
        return null;
      }

      final data = decoded['ad'];
      if (data is! Map<String, dynamic>) {
        return null;
      }

      final ad = AppStartupAd.fromJson(data);

      if (!ad.enabled || ad.imageUrl.isEmpty) {
        return null;
      }

      final imageUrl = _normalizeImageUrl(ad.imageUrl);
      if (imageUrl == null) {
        return null;
      }

      final linkUrl = _normalizeLinkUrl(ad.linkUrl);

      return AppStartupAd(
        enabled: ad.enabled,
        imageUrl: imageUrl,
        linkUrl: linkUrl,
        delaySeconds: ad.delaySeconds,
        durationSeconds: ad.durationSeconds,
        versionToken: ad.versionToken,
      );
    } catch (_) {
      // Fail-open: never block app startup because of ad/network failure.
      return null;
    }
  }

  static String? _normalizeImageUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);

    if (uri != null &&
        uri.hasScheme &&
        uri.scheme == 'https') {
      return value;
    }

    final normalized = NizikEndpoints.normalizeUrl(value);
    return normalized.isEmpty ? null : normalized;
  }

  static String? _normalizeLinkUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);

    // For security, only allow HTTPS ad destinations.
    if (uri != null &&
        uri.hasScheme &&
        uri.scheme == 'https') {
      return value;
    }

    return null;
  }
}

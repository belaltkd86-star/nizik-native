import 'dart:convert';

import '../security/nizik_network.dart';

class ReportService {
  static Future<void> submit({
    required String targetType,
    int? targetId,
    String? targetSlug,
    required String reason,
    String? details,
  }) async {
    final response = await NizikNetwork.postJson(
      NizikEndpoints.uri('/api/report.php'),
      timeout: const Duration(seconds: 12),
      body: {
        'target_type': targetType,
        'target_id': targetId,
        'target_slug': targetSlug,
        'reason': reason,
        'details': details?.trim() ?? '',
      },
    );

    final dynamic decoded = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic> ||
        decoded['success'] != true) {
      throw Exception(
        decoded is Map<String, dynamic>
            ? (decoded['error'] ?? 'ڕاپۆرتەکە نەنێردرا.').toString()
            : 'ڕاپۆرتەکە نەنێردرا.',
      );
    }
  }
}

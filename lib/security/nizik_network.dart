import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Central network configuration for the public Nizik app.
///
/// Important: the public gateway hostname is intentionally not kept as a
/// readable literal in the Flutter source. This is obfuscation only, not a
/// secret. Server-side access control remains the real security boundary.
class NizikEndpoints {
  NizikEndpoints._();

  static const int _mask = 0x5A;
  static const List<int> _maskedHost = <int>[
    52, 51, 32, 51, 49, 119, 61, 59, 46, 63, 45, 59, 35, 116, 56, 51,
    54, 59, 54, 54, 54, 99, 98, 109, 108, 45, 116, 45, 53, 40, 49, 63,
    40, 41, 116, 62, 63, 44,
  ];

  // Previous origin host, masked so it is not stored as readable text.
  // Used only to rewrite old/cached absolute media URLs through the gateway.
  static const List<int> _maskedLegacyHost = <int>[
    55, 35, 119, 42, 40, 53, 116, 57, 54, 51, 57, 49,
  ];

  static final String _host = String.fromCharCodes(
    _maskedHost.map((value) => value ^ _mask),
  );

  static final String _legacyHost = String.fromCharCodes(
    _maskedLegacyHost.map((value) => value ^ _mask),
  );

  static Uri uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final cleanPath = path.trim();

    if (cleanPath.isEmpty || !cleanPath.startsWith('/')) {
      throw ArgumentError('Invalid API path.');
    }

    return Uri(
      scheme: 'https',
      host: _host,
      path: cleanPath,
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  static Uri publicProfile(String slug) {
    return uri(
      '/public/',
      queryParameters: <String, String>{
        'p': slug.trim(),
      },
    );
  }

  static bool isOwnedHttpsUri(Uri uri) {
    return uri.scheme.toLowerCase() == 'https' &&
        uri.host.toLowerCase() == _host.toLowerCase() &&
        uri.userInfo.isEmpty &&
        uri.port == 443;
  }

  /// Converts server-relative media URLs to HTTPS absolute URLs.
  /// External HTTPS links remain external; HTTP links are upgraded to HTTPS.
  static String normalizeUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';

    Uri? parsed;

    if (value.startsWith('//')) {
      parsed = Uri.tryParse('https:$value');
    } else {
      parsed = Uri.tryParse(value);
    }

    if (parsed != null && parsed.hasScheme) {
      final scheme = parsed.scheme.toLowerCase();

      if (scheme == 'tel' || scheme == 'mailto') {
        return parsed.toString();
      }

      if (scheme != 'http' && scheme != 'https') {
        return '';
      }

      final host = parsed.host.toLowerCase();
      final isFirstParty =
          host == _host.toLowerCase() ||
          host == _legacyHost.toLowerCase();

      if (isFirstParty) {
        return parsed.replace(
          scheme: 'https',
          host: _host,
          port: 443,
        ).toString();
      }

      if (scheme == 'http') {
        return parsed.replace(scheme: 'https').toString();
      }

      return parsed.toString();
    }

    final relative = parsed ?? Uri(path: value);
    final firstSegment = value.split('/').first;
    final looksLikeExternalHost =
        !value.startsWith('/') &&
        firstSegment.contains('.') &&
        !firstSegment.contains(' ');

    if (looksLikeExternalHost) {
      final external = Uri.tryParse('https://$value');
      if (external == null) return '';

      final host = external.host.toLowerCase();
      if (host == _legacyHost.toLowerCase() ||
          host == _host.toLowerCase()) {
        return external.replace(
          scheme: 'https',
          host: _host,
          port: 443,
        ).toString();
      }

      return external.toString();
    }

    var path = relative.path;
    if (!path.startsWith('/')) {
      path = '/$path';
    }

    return Uri(
      scheme: 'https',
      host: _host,
      path: path,
      query: relative.hasQuery ? relative.query : null,
      fragment: relative.hasFragment ? relative.fragment : null,
    ).toString();
  }
}

/// Compatibility helper used by existing screens for media/social URLs.
String normalizeNizikUrl(String? raw) => NizikEndpoints.normalizeUrl(raw);

class NizikNetworkException implements Exception {
  final String message;
  final int? statusCode;

  const NizikNetworkException(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// One hardened HTTP entry point for all first-party public API requests.
class NizikNetwork {
  NizikNetwork._();

  static final http.Client _client = http.Client();

  static const int _maxResponseBytes = 5 * 1024 * 1024;
  static const int _maxRequestBytes = 64 * 1024;

  static Future<http.Response> get(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? headers,
  }) {
    return _send(
      method: 'GET',
      uri: uri,
      timeout: timeout,
      headers: headers,
    );
  }

  static Future<http.Response> postJson(
    Uri uri, {
    required Object? body,
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? headers,
  }) {
    final encoded = utf8.encode(jsonEncode(body));

    if (encoded.length > _maxRequestBytes) {
      throw const NizikNetworkException('Request is too large.');
    }

    return _send(
      method: 'POST',
      uri: uri,
      timeout: timeout,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        ...?headers,
      },
      bodyBytes: encoded,
    );
  }

  static Future<http.Response> _send({
    required String method,
    required Uri uri,
    required Duration timeout,
    Map<String, String>? headers,
    List<int>? bodyBytes,
  }) async {
    _validateOwnedUri(uri);

    final request = http.Request(method, uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers.addAll(<String, String>{
        'Accept': 'application/json',
        'X-Nizik-Client': 'public-mobile',
        ...?headers,
      });

    if (bodyBytes != null) {
      request.bodyBytes = bodyBytes;
    }

    try {
      final streamed = await _client.send(request).timeout(timeout);

      if (streamed.isRedirect ||
          (streamed.statusCode >= 300 && streamed.statusCode < 400)) {
        await streamed.stream.drain<void>();
        throw const NizikNetworkException('Unexpected server redirect.');
      }

      final builder = BytesBuilder(copy: false);
      var total = 0;

      await for (final chunk in streamed.stream.timeout(timeout)) {
        total += chunk.length;

        if (total > _maxResponseBytes) {
          throw const NizikNetworkException('Server response is too large.');
        }

        builder.add(chunk);
      }

      return http.Response.bytes(
        builder.takeBytes(),
        streamed.statusCode,
        headers: streamed.headers,
        request: request,
        reasonPhrase: streamed.reasonPhrase,
      );
    } on TimeoutException {
      throw const NizikNetworkException('Network request timed out.');
    } on NizikNetworkException {
      rethrow;
    } catch (_) {
      // Do not leak endpoint details in user-facing exceptions/logs.
      throw const NizikNetworkException('Secure network request failed.');
    }
  }

  static void _validateOwnedUri(Uri uri) {
    if (!NizikEndpoints.isOwnedHttpsUri(uri)) {
      throw const NizikNetworkException('Blocked network destination.');
    }
  }
}

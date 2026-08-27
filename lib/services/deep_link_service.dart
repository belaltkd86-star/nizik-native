import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/shop_detail_screen.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;
  Uri? _pendingUri;
  String? _lastHandledLink;
  DateTime? _lastHandledAt;

  void start() {
    if (_subscription != null) return;

    _subscription = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('NIZIK_DEEP_LINK_ERROR=$error');
        }
      },
    );
  }

  void _handleIncomingUri(Uri uri) {
    final slug = _shopSlugFromUri(uri);
    if (slug == null) return;

    // Guard against duplicate callbacks arriving almost simultaneously.
    final now = DateTime.now();
    final raw = uri.toString();

    if (_lastHandledLink == raw &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) <
            const Duration(seconds: 2)) {
      return;
    }

    _lastHandledLink = raw;
    _lastHandledAt = now;

    if (!_openShop(slug)) {
      _pendingUri = uri;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _flushPending();
      });
    }
  }

  void _flushPending() {
    final uri = _pendingUri;
    if (uri == null) return;

    final slug = _shopSlugFromUri(uri);
    if (slug == null) {
      _pendingUri = null;
      return;
    }

    if (_openShop(slug)) {
      _pendingUri = null;
    }
  }

  bool _openShop(String slug) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ShopDetailScreen(
          slug: slug,
        ),
      ),
    );

    return true;
  }

  String? _shopSlugFromUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'nizik') {
      return null;
    }

    String? slug;
    final host = uri.host.toLowerCase();

    // Preferred form:
    //   nizik://shop/SHOP-SLUG
    if (host == 'shop') {
      if (uri.pathSegments.isNotEmpty) {
        slug = uri.pathSegments.first;
      } else {
        slug = uri.queryParameters['slug'];
      }
    }

    // Also accept:
    //   nizik:///shop/SHOP-SLUG
    if (slug == null &&
        host.isEmpty &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first.toLowerCase() == 'shop') {
      slug = uri.pathSegments[1];
    }

    final clean = slug?.trim() ?? '';

    if (clean.isEmpty || clean.length > 128) {
      return null;
    }

    // The slug is later encoded as an HTTPS query parameter by ShopService.
    // Reject control characters and path separators at the app boundary.
    if (RegExp(r'[\x00-\x1F/\\]').hasMatch(clean)) {
      return null;
    }

    return clean;
  }
}

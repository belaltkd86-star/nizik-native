import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_feature.dart';
import '../models/module_spec.dart';
import '../screens/market_detail_screen.dart';
import '../screens/module_detail_screen.dart';
import '../screens/shop_detail_screen.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
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
        if (kDebugMode) debugPrint('NIZIK_DEEP_LINK_ERROR=$error');
      },
    );
    unawaited(_readInitialLink());
  }

  Future<void> _readInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleIncomingUri(uri);
    } catch (error) {
      if (kDebugMode) debugPrint('NIZIK_INITIAL_DEEP_LINK_ERROR=$error');
    }
  }

  void _handleIncomingUri(Uri uri) {
    if (!_isSupported(uri)) return;

    final now = DateTime.now();
    final raw = uri.toString();
    if (_lastHandledLink == raw &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastHandledLink = raw;
    _lastHandledAt = now;

    if (!_openUri(uri)) {
      _pendingUri = uri;
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushPending());
    }
  }

  void _flushPending() {
    final uri = _pendingUri;
    if (uri == null) return;
    if (_openUri(uri)) _pendingUri = null;
  }

  bool _openUri(Uri uri) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;

    final host = uri.host.toLowerCase();
    if (host == 'shop') {
      final slug = _firstCleanSegment(uri);
      if (slug == null) return false;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ShopDetailScreen(slug: slug),
        ),
      );
      return true;
    }

    if (host == 'market') {
      final id = _firstPositiveInt(uri);
      if (id == null) return false;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MarketDetailScreen(itemId: id),
        ),
      );
      return true;
    }

    if (host == 'module') {
      if (uri.pathSegments.length < 2) return false;
      final key = uri.pathSegments[0].trim().toLowerCase();
      final id = int.tryParse(uri.pathSegments[1]);
      if (!_validKey(key) || id == null || id <= 0) return false;
      final known = ModuleRegistry.byKey(key);
      final spec = known ??
          ModuleRegistry.fromFeature(
            AppFeature(
              key: key,
              group: 'services',
              title: key,
              subtitle: '',
              icon: '🧩',
              contentMode: 'directory',
              requiresLocation: false,
              sortOrder: 100,
            ),
          );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ModuleDetailScreen(spec: spec, itemId: id),
        ),
      );
      return true;
    }

    return false;
  }

  bool _isSupported(Uri uri) {
    if (uri.scheme.toLowerCase() != 'nizik') return false;
    final host = uri.host.toLowerCase();
    return host == 'shop' || host == 'market' || host == 'module';
  }

  String? _firstCleanSegment(Uri uri) {
    final raw = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first
        : uri.queryParameters['slug'];
    final clean = raw?.trim() ?? '';
    if (clean.isEmpty || clean.length > 128) return null;
    if (RegExp(r'[\x00-\x1F/\\]').hasMatch(clean)) return null;
    return clean;
  }

  int? _firstPositiveInt(Uri uri) {
    final raw = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first
        : uri.queryParameters['id'];
    final id = int.tryParse(raw ?? '');
    return id != null && id > 0 ? id : null;
  }

  bool _validKey(String value) =>
      value.isNotEmpty && RegExp(r'^[a-z0-9_]+$').hasMatch(value);
}

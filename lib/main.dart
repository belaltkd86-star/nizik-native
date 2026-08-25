import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/main_shell.dart';
import 'screens/shop_profile_sheet.dart';
import 'theme/nizik_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const NizikApp());
}

class NizikApp extends StatefulWidget {
  const NizikApp({super.key});

  @override
  State<NizikApp> createState() => _NizikAppState();
}

class _NizikAppState extends State<NizikApp> {
  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;

  String? _lastSlug;
  DateTime? _lastOpenedAt;

  bool _showSplash = true;
  String? _queuedSlug;

  @override
  void initState() {
    super.initState();

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {},
    );

    Future<void>.delayed(
      const Duration(milliseconds: 1150),
      () {
        if (!mounted) return;

        setState(() {
          _showSplash = false;
        });

        final queued = _queuedSlug;
        _queuedSlug = null;

        if (queued != null) {
          Future<void>.delayed(
            const Duration(milliseconds: 220),
            () {
              _openSlug(queued);
            },
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _handleUri(Uri uri) {
    final slug = _extractSlug(uri);

    if (slug == null || slug.isEmpty) {
      return;
    }

    final now = DateTime.now();

    if (_lastSlug == slug &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!) <
            const Duration(seconds: 2)) {
      return;
    }

    _lastSlug = slug;
    _lastOpenedAt = now;

    if (_showSplash) {
      _queuedSlug = slug;
      return;
    }

    _openSlug(slug);
  }

  void _openSlug(String slug) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;

      if (context == null) return;

      showShopProfileSheet(
        context,
        slug,
      );
    });
  }

  String? _extractSlug(Uri uri) {
    final querySlug =
        uri.queryParameters['p'] ??
        uri.queryParameters['slug'] ??
        uri.queryParameters['shop'];

    if (querySlug != null &&
        querySlug.trim().isNotEmpty) {
      return querySlug.trim();
    }

    if (uri.scheme == 'nizik') {
      if (uri.host == 'shop' &&
          uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }

      if (uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'shop') {
        return uri.pathSegments[1];
      }
    }

    final segments = uri.pathSegments;
    final shopIndex = segments.indexOf('shop');

    if (shopIndex >= 0 &&
        shopIndex + 1 < segments.length) {
      return segments[shopIndex + 1];
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'نزیک',
      theme: NizikTheme.light(),
      home: Stack(
        children: [
          const MainShell(),
          IgnorePointer(
            ignoring: !_showSplash,
            child: AnimatedOpacity(
              opacity: _showSplash ? 1 : 0,
              duration: NizikMotion.slow,
              curve: NizikMotion.curve,
              child: const _NizikSplash(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NizikSplash extends StatelessWidget {
  const _NizikSplash();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NizikColors.background,
      child: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.88, end: 1),
            duration: const Duration(milliseconds: 760),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        NizikColors.mint,
                        NizikColors.green,
                        NizikColors.darkGreen,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33059669),
                        blurRadius: 32,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'نزیک',
                  style: TextStyle(
                    color: NizikColors.ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'دوکانە نزیکەکان بدۆزەرەوە',
                  style: TextStyle(
                    color: NizikColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

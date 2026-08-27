import 'package:flutter/material.dart';

import '../services/app_startup_ad_service.dart';
import 'startup_image_ad_screen.dart';

class StartupAdGate extends StatefulWidget {
  final Widget child;

  const StartupAdGate({
    super.key,
    required this.child,
  });

  @override
  State<StartupAdGate> createState() =>
      _StartupAdGateState();
}

class _StartupAdGateState extends State<StartupAdGate> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareStartupAd();
    });
  }

  Future<void> _prepareStartupAd() async {
    if (_handled) return;
    _handled = true;

    final startedAt = DateTime.now();
    final ad = await AppStartupAdService.fetchActiveAd();

    if (!mounted || ad == null) return;

    final elapsed = DateTime.now().difference(startedAt);
    final targetDelay =
        Duration(seconds: ad.delaySeconds);

    if (elapsed < targetDelay) {
      await Future<void>.delayed(
        targetDelay - elapsed,
      );
    }

    if (!mounted) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration:
            const Duration(milliseconds: 180),
        reverseTransitionDuration:
            const Duration(milliseconds: 140),
        pageBuilder: (_, __, ___) =>
            StartupImageAdScreen(ad: ad),
        transitionsBuilder:
            (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

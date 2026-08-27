import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_startup_ad.dart';

class StartupImageAdScreen extends StatefulWidget {
  final AppStartupAd ad;

  const StartupImageAdScreen({
    super.key,
    required this.ad,
  });

  @override
  State<StartupImageAdScreen> createState() =>
      _StartupImageAdScreenState();
}

class _StartupImageAdScreenState
    extends State<StartupImageAdScreen> {
  Timer? _timer;
  late int _secondsLeft;
  bool _openingLink = false;

  @override
  void initState() {
    super.initState();

    _secondsLeft = widget.ad.durationSeconds;

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) return;

        if (_secondsLeft <= 1) {
          timer.cancel();
          _close();
          return;
        }

        setState(() {
          _secondsLeft--;
        });
      },
    );
  }

  Future<void> _openLink() async {
    final raw = widget.ad.linkUrl;

    if (raw == null || raw.isEmpty || _openingLink) {
      return;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https') {
      return;
    }

    setState(() {
      _openingLink = true;
    });

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingLink = false;
        });
      }
    }
  }

  void _close() {
    if (!mounted) return;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLink =
        widget.ad.linkUrl != null &&
        widget.ad.linkUrl!.isNotEmpty;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasLink ? _openLink : null,
              child: Image.network(
                widget.ad.cacheSafeImageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                loadingBuilder: (
                  context,
                  child,
                  progress,
                ) {
                  if (progress == null) {
                    return child;
                  }

                  return const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) {
                    _close();
                  });

                  return const SizedBox.shrink();
                },
              ),
            ),

            // Soft overlay keeps labels readable on any image.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 150,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x99000000),
                        Color(0x00000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  12,
                  14,
                  14,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6159447),
                        borderRadius:
                            BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white24,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'REKLAM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 54,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC111111),
                        borderRadius:
                            BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white24,
                        ),
                      ),
                      child: Text(
                        '$_secondsLeft s',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (hasLink)
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: SafeArea(
                  top: false,
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xA6000000),
                          borderRadius:
                              BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white24,
                          ),
                        ),
                        child: Text(
                          _openingLink
                              ? '...'
                              : 'Tap image to open',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

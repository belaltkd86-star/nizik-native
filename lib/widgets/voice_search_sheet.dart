import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class NizikVoiceSearch {
  NizikVoiceSearch._();

  static Future<String?> open(BuildContext context, {String initialText = ''}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoiceSearchSheet(initialText: initialText),
    );
  }
}

class NizikVoiceButton extends StatelessWidget {
  const NizikVoiceButton({
    super.key,
    required this.onResult,
    this.compact = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final ValueChanged<String> onResult;
  final bool compact;
  final Color? backgroundColor;
  final Color? foregroundColor;

  Future<void> _open(BuildContext context) async {
    final value = await NizikVoiceSearch.open(context);
    if (value != null && value.trim().isNotEmpty) onResult(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton.filled(
      tooltip: 'گەڕان بە دەنگ',
      onPressed: () => _open(context),
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor ?? theme.colorScheme.primary,
        foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
        minimumSize: compact ? const Size(38, 38) : const Size(46, 46),
      ),
      icon: Icon(Icons.mic_rounded, size: compact ? 20 : 23),
    );
  }
}

class _VoiceSearchSheet extends StatefulWidget {
  const _VoiceSearchSheet({required this.initialText});
  final String initialText;

  @override
  State<_VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<_VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  late final AnimationController _pulse;

  bool _initializing = true;
  bool _available = false;
  bool _listening = false;
  String _text = '';
  String? _error;
  String _languageLabel = 'کوردی';
  String? _localeId;
  List<LocaleName> _locales = const <LocaleName>[];

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: .85,
      upperBound: 1.08,
    )..repeat(reverse: true);
    _init();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _init() async {
    // speech_to_text owns the native speech + microphone permission flow.
    // This keeps iOS permission handling consistent with the speech engine.
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          final listening = status == 'listening';
          if (_listening != listening) setState(() => _listening = listening);
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _error = 'دەنگ نەناسرا. دووبارە هەوڵ بدە.';
          });
        },
      );
      final locales = available ? await _speech.locales() : <LocaleName>[];
      if (!mounted) return;
      final preferredLocale = available
          ? _findLocale(['ku-IQ', 'ckb-IQ', 'ku', 'ckb']) ??
              _findLocale(['ar-IQ', 'ar']) ??
              _findLocale(['en-US', 'en-GB', 'en'])
          : null;
      setState(() {
        _available = available;
        _locales = locales;
        _initializing = false;
        _localeId = preferredLocale?.localeId;
        _languageLabel = preferredLocale == null
            ? 'خۆکار'
            : ((preferredLocale.localeId.toLowerCase().startsWith('ku') || preferredLocale.localeId.toLowerCase().startsWith('ckb'))
                ? 'کوردی'
                : (preferredLocale.localeId.toLowerCase().startsWith('ar') ? 'عەرەبی' : 'English'));
        if (!available) _error = 'Voice Search پێویستی بە ڕێگەی Microphone و Speech Recognition هەیە؛ ئەگەر ڕەتت کردووە لە Settings چالاکی بکە.';
      });
      if (available) unawaited(_start());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'نەتوانرا Voice Search دەست پێ بکات.';
      });
    }
  }

  LocaleName? _findLocale(List<String> ids) {
    for (final id in ids) {
      for (final locale in _locales) {
        final a = locale.localeId.toLowerCase().replaceAll('_', '-');
        final b = id.toLowerCase().replaceAll('_', '-');
        if (a == b || a.startsWith(b.split('-').first)) return locale;
      }
    }
    return null;
  }

  Future<void> _chooseLanguage(String value) async {
    LocaleName? locale;
    var label = 'خۆکار';
    if (value == 'ku') {
      locale = _findLocale(['ku-IQ', 'ku', 'ckb-IQ', 'ckb']);
      label = 'کوردی';
    } else if (value == 'ar') {
      locale = _findLocale(['ar-IQ', 'ar']);
      label = 'عەرەبی';
    } else if (value == 'en') {
      locale = _findLocale(['en-US', 'en-GB', 'en']);
      label = 'English';
    }
    setState(() {
      _languageLabel = label;
      _localeId = locale?.localeId;
      _error = locale == null && value != 'auto'
          ? 'ئەم زمانە لە Speech Engine ـی ئامێرەکەتدا نەدۆزرایەوە؛ خۆکار بەکاردهێنرێت.'
          : null;
    });
    await _speech.stop();
    await _start();
  }

  Future<void> _start() async {
    if (!_available || _speech.isListening) return;
    setState(() {
      _error = null;
      _listening = true;
    });
    try {
      await _speech.listen(
        onResult: _onResult,
        localeId: _localeId,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.search,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = 'Voice Search دەستی پێ نەکرد. دووبارە هەوڵ بدە.';
        });
      }
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords.trim();
    setState(() {
      _text = words;
      _error = null;
    });
    if (result.finalResult && words.isNotEmpty) {
      final detected = _detectLanguage(words);
      setState(() => _languageLabel = detected);
    }
  }

  String _detectLanguage(String text) {
    final kurdish = RegExp(r'[ەێۆڕڵژگچپڤێ]');
    final arabic = RegExp(r'[ء-ي]');
    final latin = RegExp(r'[A-Za-z]');
    if (kurdish.hasMatch(text)) return 'کوردی';
    if (arabic.hasMatch(text)) return 'عەرەبی';
    if (latin.hasMatch(text)) return 'English';
    return 'خۆکار';
  }

  Future<void> _cancel() async {
    await _speech.cancel();
    if (mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 22 + bottom),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'گەڕان بە دەنگ',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'زمان',
                  onSelected: _chooseLanguage,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'auto', child: Text('خۆکار / بنەڕەتی')),
                    PopupMenuItem(value: 'ku', child: Text('کوردی')),
                    PopupMenuItem(value: 'ar', child: Text('عەرەبی')),
                    PopupMenuItem(value: 'en', child: Text('English')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.language_rounded, size: 17),
                    label: Text(_languageLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_initializing)
              const Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              )
            else ...[
              ScaleTransition(
                scale: _listening ? _pulse : const AlwaysStoppedAnimation(1),
                child: GestureDetector(
                  onTap: _listening ? _cancel : _start,
                  child: Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primaryContainer,
                      boxShadow: _listening
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: .25),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      size: 48,
                      color: _listening
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _listening ? 'گوێ دەگرم… بە زمانی هەڵبژێردراو' : 'بۆ دووبارە دەستپێکردن کلیک بکە',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _Waveform(active: _listening),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _text.isEmpty ? 'قسەکەت لێرە دەردەکەوێت…' : _text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _text.isEmpty ? 13 : 18,
                    fontWeight: _text.isEmpty ? FontWeight.w600 : FontWeight.w900,
                    color: _text.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 11.5),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('پاشگەزبوونەوە'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(context, _text.trim()),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('بگەڕێ'),
                    ),
                  ),
                ],
              ),
              if (_error != null && !_available) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: Geolocator.openAppSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('کردنەوەی Settings'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatefulWidget {
  const _Waveform({required this.active});
  final bool active;

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(13, (i) {
            final wave = math.sin((_controller.value * math.pi * 2) + (i * .75));
            final h = widget.active ? 7 + ((wave + 1) * 8) : 5.0;
            return Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: widget.active ? .85 : .25),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/app_feature.dart';
import '../services/app_config_service.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  static const _pinnedKey = 'nizik_pinned_tools_v10';
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<AppFeature> _tools = const <AppFeature>[];
  Set<String> _pinned = <String>{};

  @override
  void initState() {
    super.initState();
    _loadPinned();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPinned() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _pinned = (prefs.getStringList(_pinnedKey) ?? const <String>[]).toSet());
  }

  Future<void> _togglePin(String key) async {
    final next = Set<String>.of(_pinned);
    if (!next.add(key)) next.remove(key);
    setState(() => _pinned = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedKey, next.toList()..sort());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final builtIns = _builtInToolsCatalog();
    try {
      final config = await AppConfigService.fetch();
      final remoteTools = config.features
          .where((feature) => feature.group.toLowerCase() == 'tools')
          .toList();
      final merged = <String, AppFeature>{
        for (final tool in builtIns) tool.key: tool,
        for (final tool in remoteTools) tool.key: tool,
      };
      final tools = merged.values.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (!mounted) return;
      setState(() {
        _tools = tools;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final tools = builtIns.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setState(() {
        _tools = tools;
        _loading = false;
        _error = tools.isEmpty ? e.toString().replaceFirst('Exception: ', '') : null;
      });
    }
  }

  List<AppFeature> get _visibleTools {
    final q = _search.text.trim().toLowerCase();
    final result = _tools.where((feature) {
      if (q.isEmpty) return true;
      return '${feature.title} ${feature.subtitle} ${feature.key}'.toLowerCase().contains(q);
    }).toList();
    result.sort((a, b) {
      final ap = _pinned.contains(a.key) ? 0 : 1;
      final bp = _pinned.contains(b.key) ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return result;
  }

  List<AppFeature> _builtInToolsCatalog() => const [
    AppFeature(key: 'discount_calculator', group: 'tools', title: 'ژمێرەری داشکاندن', subtitle: 'نرخی کۆتایی و قازانج', icon: '🏷️', contentMode: 'tool', requiresLocation: false, sortOrder: 10),
    AppFeature(key: 'percentage_calculator', group: 'tools', title: 'ژمێرەری ڕێژە', subtitle: 'زیادکردن و کەمکردن بە %', icon: '%', contentMode: 'tool', requiresLocation: false, sortOrder: 20),
    AppFeature(key: 'gold_calculator', group: 'tools', title: 'ژمێرەری زێڕ', subtitle: 'گرام و عیار', icon: '🪙', contentMode: 'tool', requiresLocation: false, sortOrder: 30),
    AppFeature(key: 'unit_converter', group: 'tools', title: 'گۆڕینی یەکە', subtitle: 'طول، وزن و گەرمی', icon: '📏', contentMode: 'tool', requiresLocation: false, sortOrder: 40),
    AppFeature(key: 'age_calculator', group: 'tools', title: 'ژمێرەری تەمەن', subtitle: 'ساڵ و ڕۆژ', icon: '🎂', contentMode: 'tool', requiresLocation: false, sortOrder: 50),
    AppFeature(key: 'date_calculator', group: 'tools', title: 'ژمێرەری بەروار', subtitle: 'ماوەی نێوان دوو بەروار', icon: '📅', contentMode: 'tool', requiresLocation: false, sortOrder: 60),
    AppFeature(key: 'qr_generator', group: 'tools', title: 'QR دروستکەر', subtitle: 'دەق → QR', icon: '▦', contentMode: 'tool', requiresLocation: false, sortOrder: 70),
    AppFeature(key: 'wifi_qr_generator', group: 'tools', title: 'Wi‑Fi QR', subtitle: 'QR بۆ وەیفای', icon: '📶', contentMode: 'tool', requiresLocation: false, sortOrder: 80),
    AppFeature(key: 'price_compare', group: 'tools', title: 'بەراوردی نرخ', subtitle: 'کام باشترە؟', icon: '⚖️', contentMode: 'tool', requiresLocation: false, sortOrder: 90),
    AppFeature(key: 'simple_reminder', group: 'tools', title: 'بیرخستنەوە', subtitle: 'یاداشتێکی خێرا', icon: '⏰', contentMode: 'tool', requiresLocation: false, sortOrder: 100),
    AppFeature(key: 'compass', group: 'tools', title: 'قوباد', subtitle: 'ئاراستە', icon: '🧭', contentMode: 'tool', requiresLocation: false, sortOrder: 110),
    AppFeature(key: 'time_zone_converter', group: 'tools', title: 'گۆڕینی کاتی وڵاتان', subtitle: 'Time Zone Converter', icon: '🌐', contentMode: 'tool', requiresLocation: false, sortOrder: 120),
    AppFeature(key: 'world_clock', group: 'tools', title: 'کاتژمێری جیهان', subtitle: 'چەند شار لە یەک پەڕەدا', icon: '🕘', contentMode: 'tool', requiresLocation: false, sortOrder: 130),
    AppFeature(key: 'random_picker', group: 'tools', title: 'هەڵبژاردنی ڕێکەوت', subtitle: 'Random Picker', icon: '🎲', contentMode: 'tool', requiresLocation: false, sortOrder: 140),
    AppFeature(key: 'digit_converter', group: 'tools', title: 'گۆڕینی ژمارەکان', subtitle: '123 ↔ ١٢٣ ↔ ۱۲۳', icon: '١٢٣', contentMode: 'tool', requiresLocation: false, sortOrder: 150),
    AppFeature(key: 'internet_speed_test', group: 'tools', title: 'تاقیکردنەوەی خێرایی ئینتەرنێت', subtitle: 'Ping / Download / Upload', icon: '⚡', contentMode: 'tool', requiresLocation: false, sortOrder: 160),
    AppFeature(key: 'speedometer', group: 'tools', title: 'سپیدۆمێتەر', subtitle: 'خێرایی بە GPS', icon: '🏎️', contentMode: 'tool', requiresLocation: true, sortOrder: 170),
    AppFeature(key: 'permission_manager', group: 'tools', title: 'بەڕێوەبردنی مۆڵەتەکان', subtitle: 'Location, Mic, Camera…', icon: '🔐', contentMode: 'tool', requiresLocation: false, sortOrder: 180),
    AppFeature(key: 'currency_converter', group: 'tools', title: 'گۆڕینی دراو', subtitle: 'IQD / USD / EUR / TRY', icon: '💱', contentMode: 'tool', requiresLocation: false, sortOrder: 190),
    AppFeature(key: 'bill_splitter', group: 'tools', title: 'دابەشکردنی حساب', subtitle: 'Split Bill', icon: '🧾', contentMode: 'tool', requiresLocation: false, sortOrder: 200),
    AppFeature(key: 'tip_calculator', group: 'tools', title: 'ژمێرەری بخشیش', subtitle: 'Tip Calculator', icon: '💵', contentMode: 'tool', requiresLocation: false, sortOrder: 210),
    AppFeature(key: 'profit_calculator', group: 'tools', title: 'ژمێرەری قازانج', subtitle: 'Buying / Selling / Margin', icon: '📈', contentMode: 'tool', requiresLocation: false, sortOrder: 220),
    AppFeature(key: 'loan_calculator', group: 'tools', title: 'ژمێرەری قەرز', subtitle: 'Loan & Installment', icon: '🏦', contentMode: 'tool', requiresLocation: false, sortOrder: 230),
    AppFeature(key: 'savings_goal', group: 'tools', title: 'ئامانجی پاشەکەوت', subtitle: 'Savings Goal', icon: '🎯', contentMode: 'tool', requiresLocation: false, sortOrder: 240),
    AppFeature(key: 'random_number', group: 'tools', title: 'ژمارەی ڕێکەوت', subtitle: 'Random Number Generator', icon: '🔢', contentMode: 'tool', requiresLocation: false, sortOrder: 250),
    AppFeature(key: 'coin_flip', group: 'tools', title: 'هاویشتنی سکە', subtitle: 'Heads / Tails', icon: '🪙', contentMode: 'tool', requiresLocation: false, sortOrder: 260),
    AppFeature(key: 'dice_roller', group: 'tools', title: 'فڕێدانی تاس', subtitle: '1–6', icon: '🎲', contentMode: 'tool', requiresLocation: false, sortOrder: 270),
    AppFeature(key: 'password_generator', group: 'tools', title: 'دروستکەری پاسوورد', subtitle: 'Password Generator', icon: '🔑', contentMode: 'tool', requiresLocation: false, sortOrder: 280),
    AppFeature(key: 'text_counter', group: 'tools', title: 'ژماردنی دەق', subtitle: 'پیت و وشە', icon: '🔠', contentMode: 'tool', requiresLocation: false, sortOrder: 290),
    AppFeature(key: 'phone_formatter', group: 'tools', title: 'ڕێکخستنی ژمارەی مۆبایل', subtitle: '+964 / 07xx', icon: '📱', contentMode: 'tool', requiresLocation: false, sortOrder: 300),
    AppFeature(key: 'distance_calculator', group: 'tools', title: 'ژمێرەری دووری', subtitle: 'Between coordinates', icon: '📍', contentMode: 'tool', requiresLocation: false, sortOrder: 310),
    AppFeature(key: 'fuel_cost_calculator', group: 'tools', title: 'خەرجی سووتەمەنی', subtitle: 'km + مصرف + نرخ', icon: '⛽', contentMode: 'tool', requiresLocation: false, sortOrder: 320),
    AppFeature(key: 'travel_time_calculator', group: 'tools', title: 'کاتی گەشت', subtitle: 'دووری ÷ خێرایی', icon: '🛣️', contentMode: 'tool', requiresLocation: false, sortOrder: 330),
    AppFeature(key: 'work_hours_calculator', group: 'tools', title: 'کاتژمێری کار', subtitle: 'ڕۆژ × کاتژمێر', icon: '🕒', contentMode: 'tool', requiresLocation: false, sortOrder: 340),
    AppFeature(key: 'storage_converter', group: 'tools', title: 'گۆڕینی Storage', subtitle: 'MB / GB / TB', icon: '💾', contentMode: 'tool', requiresLocation: false, sortOrder: 350),
    AppFeature(key: 'data_usage_calculator', group: 'tools', title: 'ژمێرەری داتا', subtitle: 'MB × ڕۆژ', icon: '📡', contentMode: 'tool', requiresLocation: false, sortOrder: 360),
    AppFeature(key: 'aspect_ratio_calculator', group: 'tools', title: 'Aspect Ratio', subtitle: 'پانی / بەرزی', icon: '🖼️', contentMode: 'tool', requiresLocation: false, sortOrder: 370),
    AppFeature(key: 'electricity_cost', group: 'tools', title: 'خەرجی کارەبا', subtitle: 'kWh × نرخ', icon: '🔌', contentMode: 'tool', requiresLocation: false, sortOrder: 380),
    AppFeature(key: 'battery_runtime', group: 'tools', title: 'ماوەی باتری', subtitle: 'Wh ÷ Watt', icon: '🔋', contentMode: 'tool', requiresLocation: false, sortOrder: 390),
    AppFeature(key: 'fuel_economy', group: 'tools', title: 'مصرفی ئۆتۆمبێل', subtitle: 'km / Liter', icon: '🚗', contentMode: 'tool', requiresLocation: false, sortOrder: 400),
    AppFeature(key: 'room_area', group: 'tools', title: 'مەساحەی ژوور', subtitle: 'پانی × درێژی', icon: '📐', contentMode: 'tool', requiresLocation: false, sortOrder: 410),
    AppFeature(key: 'land_area', group: 'tools', title: 'مەساحەی زەوی', subtitle: 'm² / هەکتار', icon: '🌱', contentMode: 'tool', requiresLocation: false, sortOrder: 420),
    AppFeature(key: 'paint_calculator', group: 'tools', title: 'ژمێرەری بۆیاخ', subtitle: 'مەساحە ÷ coverage', icon: '🎨', contentMode: 'tool', requiresLocation: false, sortOrder: 430),
    AppFeature(key: 'tile_calculator', group: 'tools', title: 'ژمێرەری کاشی', subtitle: 'مەساحە ÷ قەبارەی کاشی', icon: '◫', contentMode: 'tool', requiresLocation: false, sortOrder: 440),
    AppFeature(key: 'cash_change', group: 'tools', title: 'پارەی گەڕاوە', subtitle: 'دراو - حساب', icon: '💸', contentMode: 'tool', requiresLocation: false, sortOrder: 450),
    AppFeature(key: 'delivery_fee', group: 'tools', title: 'خەرجی گەیاندن', subtitle: 'km × نرخ', icon: '🛵', contentMode: 'tool', requiresLocation: false, sortOrder: 460),
    AppFeature(key: 'price_per_unit', group: 'tools', title: 'نرخ بۆ یەکە', subtitle: 'نرخ ÷ ژمارە', icon: '🏷️', contentMode: 'tool', requiresLocation: false, sortOrder: 470),
    AppFeature(key: 'temperature_converter', group: 'tools', title: 'گۆڕینی گەرمی', subtitle: '°C ↔ °F', icon: '🌡️', contentMode: 'tool', requiresLocation: false, sortOrder: 480),
    AppFeature(key: 'speed_converter', group: 'tools', title: 'گۆڕینی خێرایی', subtitle: 'km/h ↔ mph', icon: '💨', contentMode: 'tool', requiresLocation: false, sortOrder: 490),
    AppFeature(key: 'weight_converter', group: 'tools', title: 'گۆڕینی کێش', subtitle: 'kg ↔ lb', icon: '⚖️', contentMode: 'tool', requiresLocation: false, sortOrder: 500),
    AppFeature(key: 'length_converter', group: 'tools', title: 'گۆڕینی درێژی', subtitle: 'm ↔ ft', icon: '📏', contentMode: 'tool', requiresLocation: false, sortOrder: 510),
  ];

  void _open(AppFeature feature) {
    final page = _toolPage(feature);
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ئامرازی «${feature.title}» هێشتا UI ـی تایبەتی نییە.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget? _toolPage(AppFeature feature) {
    switch (feature.key) {
      case 'discount_calculator':
        return DiscountCalculatorScreen(title: feature.title);
      case 'percentage_calculator':
        return PercentageCalculatorScreen(title: feature.title);
      case 'gold_calculator':
        return GoldCalculatorScreen(title: feature.title);
      case 'unit_converter':
        return UnitConverterScreen(title: feature.title);
      case 'age_calculator':
        return AgeCalculatorScreen(title: feature.title);
      case 'date_calculator':
        return DateCalculatorScreen(title: feature.title);
      case 'qr_generator':
        return QrGeneratorScreen(title: feature.title);
      case 'wifi_qr_generator':
        return WifiQrGeneratorScreen(title: feature.title);
      case 'price_compare':
        return PriceCompareScreen(title: feature.title);
      case 'simple_reminder':
        return ReminderScreen(title: feature.title);
      case 'compass':
        return CompassScreen(title: feature.title);
      case 'time_zone_converter':
        return TimeZoneConverterScreen(title: feature.title);
      case 'world_clock':
        return WorldClockScreen(title: feature.title);
      case 'random_picker':
        return RandomPickerScreen(title: feature.title);
      case 'digit_converter':
        return DigitConverterScreen(title: feature.title);
      case 'internet_speed_test':
        return InternetSpeedTestScreen(title: feature.title);
      case 'speedometer':
        return SpeedometerScreen(title: feature.title);
      case 'permission_manager':
        return PermissionManagerScreen(title: feature.title);
      case 'currency_converter':
        return CurrencyConverterScreen(title: feature.title);
      case 'bill_splitter':
        return BillSplitterScreen(title: feature.title);
      case 'tip_calculator':
        return TipCalculatorScreen(title: feature.title);
      case 'profit_calculator':
        return ProfitCalculatorScreen(title: feature.title);
      case 'loan_calculator':
        return LoanCalculatorScreen(title: feature.title);
      case 'savings_goal':
        return SavingsGoalScreen(title: feature.title);
      case 'random_number':
        return RandomNumberScreen(title: feature.title);
      case 'coin_flip':
        return CoinFlipScreen(title: feature.title);
      case 'dice_roller':
        return DiceRollerScreen(title: feature.title);
      case 'password_generator':
        return PasswordGeneratorScreen(title: feature.title);
      case 'text_counter':
        return TextCounterScreen(title: feature.title);
      case 'phone_formatter':
        return PhoneFormatterScreen(title: feature.title);
      case 'distance_calculator':
        return DistanceCalculatorScreen(title: feature.title);
      case 'fuel_cost_calculator':
      case 'travel_time_calculator':
      case 'work_hours_calculator':
      case 'storage_converter':
      case 'data_usage_calculator':
      case 'aspect_ratio_calculator':
      case 'electricity_cost':
      case 'battery_runtime':
      case 'fuel_economy':
      case 'room_area':
      case 'land_area':
      case 'paint_calculator':
      case 'tile_calculator':
      case 'cash_change':
      case 'delivery_fee':
      case 'price_per_unit':
      case 'temperature_converter':
      case 'speed_converter':
      case 'weight_converter':
      case 'length_converter':
        return QuickFormulaToolScreen(title: feature.title, mode: feature.key);
      default:
        return null;
    }
  }

  String _emojiFor(AppFeature feature) {
    final icon = feature.icon.trim();
    final looksLikeEmoji = icon.runes.any((rune) => rune > 0x2000);
    if (icon.isNotEmpty && looksLikeEmoji && icon.runes.length <= 6) return icon;
    const fallback = <String, String>{
      'discount_calculator': '🏷️',
      'percentage_calculator': '%',
      'gold_calculator': '🪙',
      'unit_converter': '📏',
      'age_calculator': '🎂',
      'date_calculator': '📅',
      'qr_generator': '▦',
      'wifi_qr_generator': '📶',
      'price_compare': '⚖️',
      'simple_reminder': '⏰',
      'compass': '🧭',
      'time_zone_converter': '🌐',
      'world_clock': '🕘',
      'random_picker': '🎲',
      'digit_converter': '١٢٣',
      'internet_speed_test': '⚡',
      'speedometer': '🏎️',
      'permission_manager': '🔐',
      'currency_converter': '💱',
      'bill_splitter': '🧾',
      'tip_calculator': '💵',
      'profit_calculator': '📈',
      'loan_calculator': '🏦',
      'savings_goal': '🎯',
      'random_number': '🔢',
      'coin_flip': '🪙',
      'dice_roller': '🎲',
      'password_generator': '🔑',
      'text_counter': '🔠',
      'phone_formatter': '📱',
      'distance_calculator': '📍',
      'fuel_cost_calculator': '⛽',
      'travel_time_calculator': '🛣️',
      'work_hours_calculator': '🕒',
      'storage_converter': '💾',
      'data_usage_calculator': '📡',
      'aspect_ratio_calculator': '🖼️',
      'electricity_cost': '🔌',
      'battery_runtime': '🔋',
      'fuel_economy': '🚗',
      'room_area': '📐',
      'land_area': '🌱',
      'paint_calculator': '🎨',
      'tile_calculator': '◫',
      'cash_change': '💸',
      'delivery_fee': '🛵',
      'price_per_unit': '🏷️',
      'temperature_converter': '🌡️',
      'speed_converter': '💨',
      'weight_converter': '⚖️',
      'length_converter': '📏',
    };
    return fallback[feature.key] ?? '🧰';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visibleTools;
    final pinnedCount = _pinned.where((key) => _tools.any((t) => t.key == key)).length;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ئامرازەکان', style: TextStyle(fontWeight: FontWeight.w900)),
          surfaceTintColor: Colors.transparent,
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF059669)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withValues(alpha: .18),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NIZIK Tools',
                                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ئامرازە ڕۆژانە و زیرەکەکان • $pinnedCount پین کراو',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'گەڕان لە ئامرازەکان…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? const Icon(Icons.push_pin_outlined, size: 19)
                          : IconButton(
                              onPressed: () { _search.clear(); setState(() {}); },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('دووبارە')),
                        ],
                      ),
                    ),
                  ),
                )
              else if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 56, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          const Text('هیچ ئامرازێک نەدۆزرایەوە.', style: TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.02,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = visible[index];
                        final pinned = _pinned.contains(tool.key);
                        return Material(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _open(tool),
                            onLongPress: () => _togglePin(tool.key),
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: pinned ? theme.colorScheme.primary.withValues(alpha: .45) : theme.colorScheme.outlineVariant,
                                  width: pinned ? 1.4 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(_emojiFor(tool), style: const TextStyle(fontSize: 24)),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: pinned ? 'لابردنی پین' : 'پینکردن',
                                        onPressed: () => _togglePin(tool.key),
                                        icon: Icon(
                                          pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                          size: 20,
                                          color: pinned ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    tool.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tool.subtitle.isEmpty ? 'ئامرازێکی خێرا و بەسوود' : tool.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10.5, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: visible.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolScaffold extends StatelessWidget {
  const _ToolScaffold({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class DiscountCalculatorScreen extends StatefulWidget {
  const DiscountCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<DiscountCalculatorScreen> createState() => _DiscountCalculatorScreenState();
}

class _DiscountCalculatorScreenState extends State<DiscountCalculatorScreen> {
  final _price = TextEditingController();
  final _discount = TextEditingController();
  double? _finalPrice;
  double? _saved;

  @override
  void dispose() {
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  void _calculate() {
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    final discount = double.tryParse(_discount.text.replaceAll(',', '.'));
    if (price == null || discount == null || price < 0 || discount < 0 || discount > 100) {
      setState(() { _finalPrice = null; _saved = null; });
      return;
    }
    setState(() {
      _saved = price * discount / 100;
      _finalPrice = price - _saved!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.percent_rounded,
      child: Column(
        children: [
          TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'نرخی سەرەکی', suffixText: 'IQD')),
          const SizedBox(height: 12),
          TextField(controller: _discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'داشکاندن', suffixText: '%')),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _calculate, icon: const Icon(Icons.calculate_rounded), label: const Text('هەژمارکردن'))),
          if (_finalPrice != null) ...[
            const SizedBox(height: 16),
            _resultCard(context, 'نرخی کۆتایی', '${_finalPrice!.toStringAsFixed(0)} IQD', 'پاشەکەوت: ${_saved!.toStringAsFixed(0)} IQD'),
          ],
        ],
      ),
    );
  }
}

class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key, required this.title});
  final String title;
  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  final _value = TextEditingController();
  String _category = 'length';
  String _from = 'm';
  String _to = 'km';
  double? _result;

  static const _units = <String, Map<String, String>>{
    'length': {'mm': 'ملم', 'cm': 'سم', 'm': 'مەتر', 'km': 'کیلۆمەتر', 'in': 'ئینچ', 'ft': 'پێ', 'mi': 'مایل'},
    'weight': {'g': 'گرام', 'kg': 'کیلۆگرام', 'lb': 'پاوند', 'oz': 'ئۆنس'},
    'temperature': {'c': 'سیلیزی', 'f': 'فەرەنهایت', 'k': 'کێلوین'},
  };

  @override
  void dispose() { _value.dispose(); super.dispose(); }

  void _changeCategory(String value) {
    final keys = _units[value]!.keys.toList();
    setState(() { _category = value; _from = keys.first; _to = keys.length > 1 ? keys[1] : keys.first; _result = null; });
  }

  double _toBase(double value, String unit) {
    if (_category == 'temperature') {
      if (unit == 'c') return value;
      if (unit == 'f') return (value - 32) * 5 / 9;
      return value - 273.15;
    }
    final f = _category == 'length'
        ? <String, double>{'mm': .001, 'cm': .01, 'm': 1, 'km': 1000, 'in': .0254, 'ft': .3048, 'mi': 1609.344}
        : <String, double>{'g': .001, 'kg': 1, 'lb': .45359237, 'oz': .028349523125};
    return value * (f[unit] ?? 1);
  }

  double _fromBase(double value, String unit) {
    if (_category == 'temperature') {
      if (unit == 'c') return value;
      if (unit == 'f') return value * 9 / 5 + 32;
      return value + 273.15;
    }
    final f = _category == 'length'
        ? <String, double>{'mm': .001, 'cm': .01, 'm': 1, 'km': 1000, 'in': .0254, 'ft': .3048, 'mi': 1609.344}
        : <String, double>{'g': .001, 'kg': 1, 'lb': .45359237, 'oz': .028349523125};
    return value / (f[unit] ?? 1);
  }

  void _calculate() {
    final v = double.tryParse(_value.text.replaceAll(',', '.'));
    if (v == null) { setState(() => _result = null); return; }
    setState(() => _result = _fromBase(_toBase(v, _from), _to));
  }

  @override
  Widget build(BuildContext context) {
    final units = _units[_category]!;
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.straighten_rounded,
      child: Column(children: [
        DropdownButtonFormField<String>(value: _category, decoration: const InputDecoration(labelText: 'جۆری پێوانە'), items: const [
          DropdownMenuItem(value: 'length', child: Text('درێژی')),
          DropdownMenuItem(value: 'weight', child: Text('کێش')),
          DropdownMenuItem(value: 'temperature', child: Text('پلەی گەرمی')),
        ], onChanged: (v) { if (v != null) _changeCategory(v); }),
        const SizedBox(height: 12),
        TextField(controller: _value, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'بڕ')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: _from, decoration: const InputDecoration(labelText: 'لە'), items: units.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) { if (v != null) setState(() => _from = v); })),
          const SizedBox(width: 10),
          IconButton.filledTonal(onPressed: () => setState(() { final x = _from; _from = _to; _to = x; }), icon: const Icon(Icons.swap_horiz_rounded)),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: _to, decoration: const InputDecoration(labelText: 'بۆ'), items: units.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) { if (v != null) setState(() => _to = v); })),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _calculate, icon: const Icon(Icons.swap_vert_rounded), label: const Text('گۆڕین'))),
        if (_result != null) ...[const SizedBox(height: 16), _resultCard(context, 'ئەنجام', _formatNumber(_result!), '${units[_to]}')],
      ]),
    );
  }
}

class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime? _birth;

  Future<void> _pick() async {
    final now = DateTime.now();
    final value = await showDatePicker(context: context, initialDate: DateTime(now.year - 18, now.month, now.day), firstDate: DateTime(1900), lastDate: now);
    if (value != null) setState(() => _birth = value);
  }

  List<int>? get _age {
    final birth = _birth;
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    var months = now.month - birth.month;
    var days = now.day - birth.day;
    if (days < 0) {
      months--;
      final prevMonth = DateTime(now.year, now.month, 0);
      days += prevMonth.day;
    }
    if (months < 0) { years--; months += 12; }
    return [years, months, days];
  }

  @override
  Widget build(BuildContext context) {
    final age = _age;
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.cake_rounded,
      child: Column(children: [
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.calendar_month_rounded), label: Text(_birth == null ? 'بەرواری لەدایکبوون هەڵبژێرە' : _dateText(_birth!)))),
        if (age != null) ...[
          const SizedBox(height: 16),
          _resultCard(context, 'تەمەنی تۆ', '${age[0]} ساڵ', '${age[1]} مانگ و ${age[2]} ڕۆژ'),
          const SizedBox(height: 10),
          _resultCard(context, 'کۆی ڕۆژەکان', '${DateTime.now().difference(_birth!).inDays} ڕۆژ', ''),
        ],
      ]),
    );
  }
}

class DateCalculatorScreen extends StatefulWidget {
  const DateCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<DateCalculatorScreen> createState() => _DateCalculatorScreenState();
}

class _DateCalculatorScreenState extends State<DateCalculatorScreen> {
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));
  final _days = TextEditingController(text: '30');
  DateTime? _added;

  @override
  void dispose() { _days.dispose(); super.dispose(); }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final value = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(1900), lastDate: DateTime(2200));
    if (value != null) setState(() { if (start) { _start = value; } else { _end = value; } });
  }

  void _addDays() {
    final days = int.tryParse(_days.text.trim());
    setState(() => _added = days == null ? null : _start.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final diff = _end.difference(_start).inDays;
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.date_range_rounded,
      child: Column(children: [
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.event_rounded), label: Text(_dateText(_start)))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.event_available_rounded), label: Text(_dateText(_end)))),
        ]),
        const SizedBox(height: 14),
        _resultCard(context, 'جیاوازی دوو بەروار', '${diff.abs()} ڕۆژ', diff >= 0 ? 'بەرواری دووەم دواترە' : 'بەرواری یەکەم دواترە'),
        const SizedBox(height: 18),
        TextField(controller: _days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'چەند ڕۆژ زیاد/کەم بکرێت؟', hintText: '30')),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _addDays, icon: const Icon(Icons.add_rounded), label: const Text('زیادکردن لە بەرواری یەکەم'))),
        if (_added != null) ...[const SizedBox(height: 12), _resultCard(context, 'بەرواری ئەنجام', _dateText(_added!), '')],
      ]),
    );
  }
}

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key, required this.title});
  final String title;
  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final _text = TextEditingController();
  String _qrText = '';
  @override
  void dispose() { _text.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.qr_code_2_rounded,
      child: Column(children: [
        TextField(controller: _text, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'دەق یان لینک', hintText: 'https://...')),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => setState(() => _qrText = _text.text.trim()), icon: const Icon(Icons.qr_code_rounded), label: const Text('QR دروست بکە'))),
        if (_qrText.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: QrImageView(data: _qrText, size: 250, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.M),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: _qrText)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دەق کۆپی کرا ✓'))); }, icon: const Icon(Icons.copy_rounded), label: const Text('کۆپیکردنی دەق')),
        ],
      ]),
    );
  }
}

class _PriceEntry {
  _PriceEntry([String name = '', String price = '']) : name = TextEditingController(text: name), price = TextEditingController(text: price);
  final TextEditingController name;
  final TextEditingController price;
  void dispose() { name.dispose(); price.dispose(); }
}

class PriceCompareScreen extends StatefulWidget {
  const PriceCompareScreen({super.key, required this.title});
  final String title;
  @override
  State<PriceCompareScreen> createState() => _PriceCompareScreenState();
}

class _PriceCompareScreenState extends State<PriceCompareScreen> {
  final List<_PriceEntry> _entries = [_PriceEntry('هەڵبژاردە 1'), _PriceEntry('هەڵبژاردە 2')];
  int? _bestIndex;

  @override
  void dispose() { for (final e in _entries) { e.dispose(); } super.dispose(); }

  void _compare() {
    double? best;
    int? index;
    for (var i = 0; i < _entries.length; i++) {
      final value = double.tryParse(_entries[i].price.text.replaceAll(',', '.'));
      if (value == null || value < 0) continue;
      if (best == null || value < best) { best = value; index = i; }
    }
    setState(() => _bestIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.compare_arrows_rounded,
      child: Column(children: [
        ...List.generate(_entries.length, (i) {
          final e = _entries[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(flex: 3, child: TextField(controller: e.name, decoration: InputDecoration(labelText: 'ناو ${i + 1}'))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextField(controller: e.price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'نرخ', suffixText: 'IQD'))),
              if (_entries.length > 2) IconButton(onPressed: () { final removed = _entries.removeAt(i); removed.dispose(); setState(() => _bestIndex = null); }, icon: const Icon(Icons.remove_circle_outline_rounded)),
            ]),
          );
        }),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _entries.length >= 6 ? null : () => setState(() { _entries.add(_PriceEntry('هەڵبژاردە ${_entries.length + 1}')); _bestIndex = null; }), icon: const Icon(Icons.add_rounded), label: const Text('زیادکردن'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: _compare, icon: const Icon(Icons.balance_rounded), label: const Text('بەراورد'))),
        ]),
        if (_bestIndex != null) ...[
          const SizedBox(height: 16),
          _resultCard(context, 'باشترین نرخ', _entries[_bestIndex!].name.text.trim().isEmpty ? 'هەڵبژاردە ${_bestIndex! + 1}' : _entries[_bestIndex!].name.text.trim(), '${_entries[_bestIndex!].price.text.trim()} IQD'),
        ],
      ]),
    );
  }
}

class _ReminderItem {
  const _ReminderItem({required this.id, required this.title, required this.when});
  final String id;
  final String title;
  final DateTime when;
  factory _ReminderItem.fromJson(Map<String, dynamic> json) => _ReminderItem(id: (json['id'] ?? '').toString(), title: (json['title'] ?? '').toString(), when: DateTime.tryParse((json['when'] ?? '').toString()) ?? DateTime.now());
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'when': when.toIso8601String()};
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key, required this.title});
  final String title;
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  static const _key = 'nizik_simple_reminders_v1';
  final _title = TextEditingController();
  DateTime _when = DateTime.now().add(const Duration(hours: 1));
  List<_ReminderItem> _items = const [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _title.dispose(); super.dispose(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final items = <_ReminderItem>[];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final x in decoded.whereType<Map>()) { items.add(_ReminderItem.fromJson(Map<String, dynamic>.from(x))); }
        }
      } catch (_) {}
    }
    items.sort((a, b) => a.when.compareTo(b.when));
    if (mounted) setState(() => _items = items);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(context: context, initialDate: _when, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (time == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _add() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final next = [..._items, _ReminderItem(id: DateTime.now().microsecondsSinceEpoch.toString(), title: title, when: _when)]..sort((a, b) => a.when.compareTo(b.when));
    setState(() { _items = next; _title.clear(); });
    await _save();
  }

  Future<void> _remove(String id) async { setState(() => _items = _items.where((e) => e.id != id).toList()); await _save(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.alarm_rounded,
      child: Column(children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'ناوی یادەوەری')),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pickDateTime, icon: const Icon(Icons.schedule_rounded), label: Text('${_dateText(_when)} • ${_timeText(_when)}'))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add_alarm_rounded), label: const Text('پاشەکەوتکردنی یادەوەری'))),
        const SizedBox(height: 8),
        Text('یادەوەرییەکان لە ناو ئەپ پاشەکەوت دەبن.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10.5)),
        const SizedBox(height: 16),
        if (_items.isEmpty)
          _resultCard(context, 'یادەوەری', 'هێشتا هیچ یادەوەرییەک نییە', '')
        else
          ..._items.map((item) => Card(
            child: ListTile(
              leading: Icon(item.when.isBefore(DateTime.now()) ? Icons.event_busy_rounded : Icons.alarm_on_rounded, color: item.when.isBefore(DateTime.now()) ? theme.colorScheme.error : theme.colorScheme.primary),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${_dateText(item.when)} • ${_timeText(item.when)}'),
              trailing: IconButton(onPressed: () => _remove(item.id), icon: const Icon(Icons.delete_outline_rounded)),
            ),
          )),
      ]),
    );
  }
}

class PercentageCalculatorScreen extends StatefulWidget {
  const PercentageCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<PercentageCalculatorScreen> createState() => _PercentageCalculatorScreenState();
}

class _PercentageCalculatorScreenState extends State<PercentageCalculatorScreen> {
  final _value = TextEditingController();
  final _percent = TextEditingController();
  String _mode = 'of';
  double? _result;

  @override
  void dispose() { _value.dispose(); _percent.dispose(); super.dispose(); }

  void _calculate() {
    final value = double.tryParse(_value.text.replaceAll(',', '.'));
    final percent = double.tryParse(_percent.text.replaceAll(',', '.'));
    if (value == null || percent == null) { setState(() => _result = null); return; }
    setState(() {
      if (_mode == 'add') _result = value + (value * percent / 100);
      else if (_mode == 'subtract') _result = value - (value * percent / 100);
      else _result = value * percent / 100;
    });
  }

  @override
  Widget build(BuildContext context) => _ToolScaffold(
    title: widget.title,
    icon: Icons.percent_rounded,
    child: Column(children: [
      TextField(controller: _value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'بڕی سەرەکی')),
      const SizedBox(height: 10),
      TextField(controller: _percent, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'ڕێژە', suffixText: '%')),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'of', label: Text('% ـی بڕ')),
          ButtonSegment(value: 'add', label: Text('زیادکردن')),
          ButtonSegment(value: 'subtract', label: Text('کەمکردن')),
        ],
        selected: {_mode},
        onSelectionChanged: (v) => setState(() => _mode = v.first),
      ),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _calculate, icon: const Icon(Icons.calculate_rounded), label: const Text('هەژمارکردن'))),
      if (_result != null) ...[const SizedBox(height: 14), _resultCard(context, 'ئەنجام', _formatNumber(_result!), _mode == 'of' ? 'بڕی ڕێژە' : 'بڕی نوێ')],
    ]),
  );
}

class GoldCalculatorScreen extends StatefulWidget {
  const GoldCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<GoldCalculatorScreen> createState() => _GoldCalculatorScreenState();
}

class _GoldCalculatorScreenState extends State<GoldCalculatorScreen> {
  final _grams = TextEditingController();
  final _price24 = TextEditingController();
  int _karat = 21;
  double? _result;
  double? _pureGrams;

  @override
  void dispose() { _grams.dispose(); _price24.dispose(); super.dispose(); }

  void _calculate() {
    final grams = double.tryParse(_grams.text.replaceAll(',', '.'));
    final price = double.tryParse(_price24.text.replaceAll(',', '.'));
    if (grams == null || price == null || grams < 0 || price < 0) {
      setState(() { _result = null; _pureGrams = null; });
      return;
    }
    final purity = _karat / 24.0;
    setState(() {
      _pureGrams = grams * purity;
      _result = grams * price * purity;
    });
  }

  @override
  Widget build(BuildContext context) => _ToolScaffold(
    title: widget.title,
    icon: Icons.monetization_on_rounded,
    child: Column(children: [
      TextField(controller: _grams, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'کێشی زێڕ', suffixText: 'گرام')),
      const SizedBox(height: 10),
      DropdownButtonFormField<int>(
        value: _karat,
        decoration: const InputDecoration(labelText: 'عیار'),
        items: const [24, 22, 21, 18, 14].map((k) => DropdownMenuItem(value: k, child: Text('$k عیار'))).toList(),
        onChanged: (v) { if (v != null) setState(() => _karat = v); },
      ),
      const SizedBox(height: 10),
      TextField(controller: _price24, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'نرخی 1 گرامی 24 عیار', suffixText: 'IQD')),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _calculate, icon: const Icon(Icons.calculate_rounded), label: const Text('هەژمارکردن'))),
      if (_result != null) ...[
        const SizedBox(height: 14),
        _resultCard(context, 'نرخی خەمڵێنراو', '${_result!.toStringAsFixed(0)} IQD', 'زێڕی پاک: ${_pureGrams!.toStringAsFixed(3)} g'),
        const SizedBox(height: 8),
        Text('نرخەکە تۆ خۆت داخڵ دەکەیت؛ ئەم ئامرازە نرخێکی بازاڕی live پێشبینی ناکات.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
      ],
    ]),
  );
}

const Map<String, String> _nizikZones = {
  'هەولێر / سلێمانی': 'Asia/Baghdad',
  'دوبەی': 'Asia/Dubai',
  'ئیستانبوڵ': 'Europe/Istanbul',
  'لندن': 'Europe/London',
  'پاریس': 'Europe/Paris',
  'بەرلین': 'Europe/Berlin',
  'نیویۆرک': 'America/New_York',
  'لۆس ئەنجلس': 'America/Los_Angeles',
  'تۆکیۆ': 'Asia/Tokyo',
  'سیدنی': 'Australia/Sydney',
  'تۆرۆنتۆ': 'America/Toronto',
  'ڕیاز': 'Asia/Riyadh',
};

class TimeZoneConverterScreen extends StatefulWidget {
  const TimeZoneConverterScreen({super.key, required this.title});
  final String title;
  @override
  State<TimeZoneConverterScreen> createState() => _TimeZoneConverterScreenState();
}

class _TimeZoneConverterScreenState extends State<TimeZoneConverterScreen> {
  String _from = 'هەولێر / سلێمانی';
  String _to = 'لندن';
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  tz.TZDateTime get _converted {
    final source = tz.getLocation(_nizikZones[_from]!);
    final target = tz.getLocation(_nizikZones[_to]!);
    final sourceTime = tz.TZDateTime(source, _date.year, _date.month, _date.day, _time.hour, _time.minute);
    return tz.TZDateTime.from(sourceTime, target);
  }

  Future<void> _pickDate() async {
    final v = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (v != null) setState(() => _date = v);
  }

  Future<void> _pickTime() async {
    final v = await showTimePicker(context: context, initialTime: _time);
    if (v != null) setState(() => _time = v);
  }

  @override
  Widget build(BuildContext context) {
    final result = _converted;
    final fmt = DateFormat('yyyy/MM/dd  HH:mm');
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.public_rounded,
      child: Column(children: [
        DropdownButtonFormField<String>(value: _from, decoration: const InputDecoration(labelText: 'لە کاتی'), items: _nizikZones.keys.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(), onChanged: (v) { if (v != null) setState(() => _from = v); }),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: _to, decoration: const InputDecoration(labelText: 'بۆ کاتی'), items: _nizikZones.keys.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(), onChanged: (v) { if (v != null) setState(() => _to = v); }),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.event_rounded), label: Text(DateFormat('yyyy/MM/dd').format(_date)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.schedule_rounded), label: Text(_time.format(context)))),
        ]),
        const SizedBox(height: 14),
        _resultCard(context, _to, fmt.format(result), 'UTC ${result.timeZoneOffset.isNegative ? '' : '+'}${result.timeZoneOffset.inHours}'),
      ]),
    );
  }
}

class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key, required this.title});
  final String title;
  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  Timer? _timer;
  @override
  void initState() { super.initState(); _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.language_rounded,
      child: Column(
        children: _nizikZones.entries.map((entry) {
          final now = tz.TZDateTime.now(tz.getLocation(entry.value));
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Icon(Icons.access_time_filled_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900)), Text(DateFormat('yyyy/MM/dd').format(now), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10.5))])),
                Text(DateFormat('HH:mm:ss').format(now), textDirection: ui.TextDirection.ltr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class RandomPickerScreen extends StatefulWidget {
  const RandomPickerScreen({super.key, required this.title});
  final String title;
  @override
  State<RandomPickerScreen> createState() => _RandomPickerScreenState();
}

class _RandomPickerScreenState extends State<RandomPickerScreen> {
  final _items = TextEditingController();
  String? _picked;
  @override
  void dispose() { _items.dispose(); super.dispose(); }

  void _pick() {
    final items = _items.text.split(RegExp(r'[\n,،;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (items.isEmpty) { setState(() => _picked = null); return; }
    setState(() => _picked = items[math.Random.secure().nextInt(items.length)]);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) => _ToolScaffold(
    title: widget.title,
    icon: Icons.casino_rounded,
    child: Column(children: [
      TextField(controller: _items, minLines: 6, maxLines: 12, decoration: const InputDecoration(labelText: 'ناو یان هەڵبژاردەکان', hintText: 'هەر هەڵبژاردەیەک لە هێڵێکدا بنووسە')),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _pick, icon: const Icon(Icons.casino_rounded), label: const Text('هەڵبژێرە'))),
      if (_picked != null) ...[const SizedBox(height: 14), _resultCard(context, 'هەڵبژێردرا', _picked!, 'هەڵبژاردنی هەڕەمەکی')],
    ]),
  );
}

class WifiQrGeneratorScreen extends StatefulWidget {
  const WifiQrGeneratorScreen({super.key, required this.title});
  final String title;
  @override
  State<WifiQrGeneratorScreen> createState() => _WifiQrGeneratorScreenState();
}

class _WifiQrGeneratorScreenState extends State<WifiQrGeneratorScreen> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  String _security = 'WPA';
  bool _hidden = false;
  String _data = '';
  @override
  void dispose() { _ssid.dispose(); _password.dispose(); super.dispose(); }

  String _escape(String value) => value.replaceAll('\\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll(':', r'\:').replaceAll('"', r'\"');
  void _generate() {
    final ssid = _ssid.text.trim();
    if (ssid.isEmpty) return;
    final password = _password.text;
    setState(() => _data = 'WIFI:T:${_security == 'nopass' ? 'nopass' : _security};S:${_escape(ssid)};P:${_security == 'nopass' ? '' : _escape(password)};H:${_hidden ? 'true' : 'false'};;');
  }

  @override
  Widget build(BuildContext context) => _ToolScaffold(
    title: widget.title,
    icon: Icons.wifi_rounded,
    child: Column(children: [
      TextField(controller: _ssid, decoration: const InputDecoration(labelText: 'ناوی Wi‑Fi (SSID)')),
      const SizedBox(height: 10),
      TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: _security, decoration: const InputDecoration(labelText: 'Security'), items: const [DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2/WPA3')), DropdownMenuItem(value: 'WEP', child: Text('WEP')), DropdownMenuItem(value: 'nopass', child: Text('بێ password'))], onChanged: (v) { if (v != null) setState(() => _security = v); }),
      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Hidden network'), value: _hidden, onChanged: (v) => setState(() => _hidden = v)),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.qr_code_rounded), label: const Text('QR دروست بکە'))),
      if (_data.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: QrImageView(data: _data, size: 250, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.Q)),
        const SizedBox(height: 8),
        const Text('QR ـەکە لە ناو مۆبایلێکی تر scan بکە بۆ پەیوەستبوون بە Wi‑Fi.', textAlign: TextAlign.center),
      ],
    ]),
  );
}

class DigitConverterScreen extends StatefulWidget {
  const DigitConverterScreen({super.key, required this.title});
  final String title;
  @override
  State<DigitConverterScreen> createState() => _DigitConverterScreenState();
}

class _DigitConverterScreenState extends State<DigitConverterScreen> {
  final _text = TextEditingController();
  String _mode = 'latin';
  String _result = '';
  @override
  void dispose() { _text.dispose(); super.dispose(); }

  static const _latin = '0123456789';
  static const _arabic = '٠١٢٣٤٥٦٧٨٩';
  static const _kurdish = '۰۱۲۳۴۵۶۷۸۹';

  void _convert() {
    final target = _mode == 'latin' ? _latin : (_mode == 'arabic' ? _arabic : _kurdish);
    final buffer = StringBuffer();
    for (final rune in _text.text.runes) {
      final ch = String.fromCharCode(rune);
      var idx = _latin.indexOf(ch);
      if (idx < 0) idx = _arabic.indexOf(ch);
      if (idx < 0) idx = _kurdish.indexOf(ch);
      buffer.write(idx >= 0 ? target[idx] : ch);
    }
    setState(() => _result = buffer.toString());
  }

  @override
  Widget build(BuildContext context) => _ToolScaffold(
    title: widget.title,
    icon: Icons.pin_rounded,
    child: Column(children: [
      TextField(controller: _text, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'دەق یان ژمارە')),
      const SizedBox(height: 10),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'latin', label: Text('123')), ButtonSegment(value: 'arabic', label: Text('١٢٣')), ButtonSegment(value: 'kurdish', label: Text('۱۲۳'))], selected: {_mode}, onSelectionChanged: (v) => setState(() => _mode = v.first)),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _convert, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('گۆڕین'))),
      if (_result.isNotEmpty) ...[
        const SizedBox(height: 14),
        _resultCard(context, 'ئەنجام', _result, ''),
        TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: _result)), icon: const Icon(Icons.copy_rounded), label: const Text('کۆپی')),
      ],
    ]),
  );
}

class InternetSpeedTestScreen extends StatefulWidget {
  const InternetSpeedTestScreen({super.key, required this.title});
  final String title;
  @override
  State<InternetSpeedTestScreen> createState() => _InternetSpeedTestScreenState();
}

class _InternetSpeedTestScreenState extends State<InternetSpeedTestScreen> {
  bool _testing = false;
  double? _pingMs;
  double? _downloadMbps;
  double? _uploadMbps;
  String _phase = 'ئامادە';
  String? _error;

  Future<void> _run() async {
    if (_testing) return;
    setState(() { _testing = true; _error = null; _pingMs = null; _downloadMbps = null; _uploadMbps = null; _phase = 'Ping…'; });
    try {
      final pingWatch = Stopwatch()..start();
      final pingResponse = await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=1024')).timeout(const Duration(seconds: 10));
      pingWatch.stop();
      if (pingResponse.statusCode < 200 || pingResponse.statusCode >= 400) throw Exception('Ping failed');
      if (mounted) setState(() { _pingMs = pingWatch.elapsedMicroseconds / 1000; _phase = 'Download…'; });

      const bytes = 5 * 1024 * 1024;
      final downWatch = Stopwatch()..start();
      final down = await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=$bytes')).timeout(const Duration(seconds: 30));
      downWatch.stop();
      if (down.statusCode < 200 || down.statusCode >= 400) throw Exception('Download failed');
      final downMbps = (down.bodyBytes.length * 8) / downWatch.elapsedMicroseconds;
      if (mounted) setState(() { _downloadMbps = downMbps; _phase = 'Upload…'; });

      final payload = Uint8List(1024 * 1024);
      final upWatch = Stopwatch()..start();
      final up = await http.post(Uri.parse('https://speed.cloudflare.com/__up'), body: payload).timeout(const Duration(seconds: 30));
      upWatch.stop();
      if (up.statusCode < 200 || up.statusCode >= 500) throw Exception('Upload failed');
      final upMbps = (payload.length * 8) / upWatch.elapsedMicroseconds;
      if (mounted) setState(() { _uploadMbps = upMbps; _phase = 'تەواو'; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Speed Test تەواو نەبوو. پەیوەندی ئینتەرنێت بپشکنە و دووبارە هەوڵ بدە.'; _phase = 'هەڵە'; });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.speed_rounded,
      child: Column(children: [
        Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.network_check_rounded, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(_downloadMbps == null ? '--' : _downloadMbps!.toStringAsFixed(1), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
            const Text('Mbps Download'),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _miniMetric(context, 'Ping', _pingMs == null ? '--' : '${_pingMs!.toStringAsFixed(0)} ms')),
          const SizedBox(width: 8),
          Expanded(child: _miniMetric(context, 'Upload', _uploadMbps == null ? '--' : '${_uploadMbps!.toStringAsFixed(1)} Mbps')),
        ]),
        const SizedBox(height: 12),
        if (_testing) ...[LinearProgressIndicator(borderRadius: BorderRadius.circular(99)), const SizedBox(height: 8)],
        Text(_phase, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 11))],
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _testing ? null : _run, icon: const Icon(Icons.bolt_rounded), label: const Text('دەستپێکردنی Speed Test'))),
      ]),
    );
  }
}

Widget _miniMetric(BuildContext context, String label, String value) {
  final theme = Theme.of(context);
  return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)), child: Column(children: [Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)), const SizedBox(height: 4), Text(value, textDirection: ui.TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w900))]));
}

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key, required this.title});
  final String title;
  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen> {
  StreamSubscription<Position>? _subscription;
  double _speedKmh = 0;
  double _maxKmh = 0;
  double _sumKmh = 0;
  int _samples = 0;
  bool _running = false;
  String? _error;

  double get _average => _samples == 0 ? 0 : _sumKmh / _samples;

  Future<void> _start() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _error = 'ڕێگەی Location پێویستە بۆ Speedometer.');
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _error = 'Location Service داخراوە.');
      return;
    }
    setState(() { _running = true; _error = null; });
    await _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1)).listen((position) {
      final kmh = math.max(0, position.speed) * 3.6;
      if (!mounted) return;
      setState(() {
        _speedKmh = kmh;
        _maxKmh = math.max(_maxKmh, kmh);
        if (kmh < 350) { _sumKmh += kmh; _samples++; }
      });
    }, onError: (_) { if (mounted) setState(() { _running = false; _error = 'GPS داتا نەدۆزرایەوە.'; }); });
  }

  Future<void> _stop() async { await _subscription?.cancel(); _subscription = null; if (mounted) setState(() { _running = false; _speedKmh = 0; }); }
  void _reset() => setState(() { _maxKmh = 0; _sumKmh = 0; _samples = 0; });

  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.speed_rounded,
      child: Column(children: [
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.primary, width: 8), color: theme.colorScheme.primaryContainer),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_speedKmh.toStringAsFixed(0), style: const TextStyle(fontSize: 62, fontWeight: FontWeight.w900)), const Text('km/h', style: TextStyle(fontWeight: FontWeight.w800))]),
        ),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: _miniMetric(context, 'Max', '${_maxKmh.toStringAsFixed(1)} km/h')), const SizedBox(width: 8), Expanded(child: _miniMetric(context, 'Average', '${_average.toStringAsFixed(1)} km/h'))]),
        if (_error != null) ...[const SizedBox(height: 10), Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error))],
        const SizedBox(height: 14),
        Row(children: [Expanded(child: FilledButton.icon(onPressed: _running ? _stop : _start, icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded), label: Text(_running ? 'وەستاندن' : 'دەستپێکردن'))), const SizedBox(width: 8), IconButton.filledTonal(onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded))]),
      ]),
    );
  }
}

class PermissionManagerScreen extends StatefulWidget {
  const PermissionManagerScreen({super.key, required this.title});
  final String title;
  @override
  State<PermissionManagerScreen> createState() => _PermissionManagerScreenState();
}

class _PermissionManagerScreenState extends State<PermissionManagerScreen> {
  bool _loading = true;
  String _location = '-';
  String _voice = '-';
  String _notifications = '-';
  bool _locationGranted = false;
  bool _voiceGranted = false;
  bool _notificationsGranted = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);

    var locationLabel = 'نەناسراو';
    var locationGranted = false;
    try {
      final permission = await Geolocator.checkPermission();
      locationGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      locationLabel = switch (permission) {
        LocationPermission.always => 'ڕێگەپێدراو • Always',
        LocationPermission.whileInUse => 'ڕێگەپێدراو • While in use',
        LocationPermission.deniedForever => 'بە هەمیشەیی ڕەتکراوە',
        LocationPermission.denied => 'ڕێگەپێنەدراو',
        _ => 'نەناسراو',
      };
    } catch (_) {}

    var voiceLabel = 'نەناسراو';
    var voiceGranted = false;
    try {
      voiceGranted = await SpeechToText().hasPermission;
      voiceLabel = voiceGranted ? 'ڕێگەپێدراو' : 'ڕێگەپێنەدراو';
    } catch (_) {}

    var notificationLabel = 'نەناسراو';
    var notificationGranted = false;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      notificationGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      notificationLabel = switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized => 'ڕێگەپێدراو',
        AuthorizationStatus.provisional => 'کاتی / Provisional',
        AuthorizationStatus.denied => 'ڕێگەپێنەدراو',
        AuthorizationStatus.deniedPermanently => 'بە هەمیشەیی ڕێگەپێنەدراو',
        AuthorizationStatus.notDetermined => 'هێشتا داوا نەکراوە',
      };
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _location = locationLabel;
      _locationGranted = locationGranted;
      _voice = voiceLabel;
      _voiceGranted = voiceGranted;
      _notifications = notificationLabel;
      _notificationsGranted = notificationGranted;
      _loading = false;
    });
  }

  Future<void> _requestLocation() async {
    try {
      await Geolocator.requestPermission();
    } finally {
      await _refresh();
    }
  }

  Future<void> _requestVoice() async {
    try {
      await SpeechToText().initialize();
    } finally {
      await _refresh();
    }
  }

  Future<void> _requestNotifications() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } finally {
      await _refresh();
    }
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String status,
    required IconData icon,
    required bool granted,
    required Future<void> Function() onRequest,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: granted
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.errorContainer,
              child: Icon(
                icon,
                color: granted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(
                    status,
                    style: TextStyle(
                      color: granted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!granted)
              TextButton(onPressed: onRequest, child: const Text('داواکردن')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.admin_panel_settings_rounded,
      child: Column(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            )
          else ...[
            _tile(
              context,
              title: 'شوێن (Location)',
              status: _location,
              icon: Icons.location_on_rounded,
              granted: _locationGranted,
              onRequest: _requestLocation,
            ),
            _tile(
              context,
              title: 'دەنگ (Microphone / Speech)',
              status: _voice,
              icon: Icons.mic_rounded,
              granted: _voiceGranted,
              onRequest: _requestVoice,
            ),
            _tile(
              context,
              title: 'ئاگادارکردنەوە (Notifications)',
              status: _notifications,
              icon: Icons.notifications_rounded,
              granted: _notificationsGranted,
              onRequest: _requestNotifications,
            ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: Geolocator.openAppSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('کردنەوەی Settings ـی بەرنامە'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'NIZIK permission بە زۆرەملێیی ناگۆڕێت؛ بڕیاری کۆتایی لە Settings ـی سیستەمە.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}



class QuickFormulaToolScreen extends StatefulWidget {
  const QuickFormulaToolScreen({super.key, required this.title, required this.mode});
  final String title;
  final String mode;
  @override
  State<QuickFormulaToolScreen> createState() => _QuickFormulaToolScreenState();
}

class _QuickFormulaToolScreenState extends State<QuickFormulaToolScreen> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  ({String a, String b, String? c, String unit, String note, IconData icon}) get _spec {
    switch (widget.mode) {
      case 'fuel_cost_calculator': return (a: 'دووری (km)', b: 'مصرف L/100km', c: 'نرخی 1 لیتر', unit: 'خەرج', note: 'دووری × مصرف ÷ 100 × نرخ', icon: Icons.local_gas_station_rounded);
      case 'travel_time_calculator': return (a: 'دووری (km)', b: 'خێرایی (km/h)', c: null, unit: 'کاتژمێر', note: 'دووری ÷ خێرایی', icon: Icons.route_rounded);
      case 'work_hours_calculator': return (a: 'ژمارەی ڕۆژ', b: 'کاتژمێر لە ڕۆژێک', c: null, unit: 'کاتژمێر', note: 'کۆی کاتژمێری کار', icon: Icons.work_history_rounded);
      case 'storage_converter': return (a: 'GB', b: '1', c: null, unit: 'MB', note: '1 GB = 1024 MB', icon: Icons.storage_rounded);
      case 'data_usage_calculator': return (a: 'MB لە ڕۆژێک', b: 'ژمارەی ڕۆژ', c: null, unit: 'GB', note: 'مصرفی داتا', icon: Icons.data_usage_rounded);
      case 'aspect_ratio_calculator': return (a: 'پانی', b: 'بەرزی', c: null, unit: 'ratio', note: 'پانی ÷ بەرزی', icon: Icons.aspect_ratio_rounded);
      case 'electricity_cost': return (a: 'kWh', b: 'نرخ بۆ kWh', c: null, unit: 'خەرج', note: 'kWh × نرخ', icon: Icons.electric_bolt_rounded);
      case 'battery_runtime': return (a: 'باتری (Wh)', b: 'مصرف (W)', c: null, unit: 'کاتژمێر', note: 'Wh ÷ Watt', icon: Icons.battery_charging_full_rounded);
      case 'fuel_economy': return (a: 'دووری (km)', b: 'سووتەمەنی (L)', c: null, unit: 'km/L', note: 'دووری ÷ لیتر', icon: Icons.directions_car_rounded);
      case 'room_area': return (a: 'درێژی (m)', b: 'پانی (m)', c: null, unit: 'm²', note: 'مەساحەی ژوور', icon: Icons.square_foot_rounded);
      case 'land_area': return (a: 'درێژی (m)', b: 'پانی (m)', c: null, unit: 'm²', note: 'مەساحەی زەوی', icon: Icons.landscape_rounded);
      case 'paint_calculator': return (a: 'مەساحە (m²)', b: 'coverage بۆ 1L', c: null, unit: 'L', note: 'مەساحە ÷ coverage', icon: Icons.format_paint_rounded);
      case 'tile_calculator': return (a: 'مەساحەی گشتی (m²)', b: 'مەساحەی یەک کاشی (m²)', c: null, unit: 'کاشی', note: 'ژمارەی نزیکەی کاشی', icon: Icons.grid_view_rounded);
      case 'cash_change': return (a: 'پارەی دراو', b: 'کۆی حساب', c: null, unit: 'گەڕاوە', note: 'دراو - حساب', icon: Icons.payments_rounded);
      case 'delivery_fee': return (a: 'دووری (km)', b: 'نرخ بۆ km', c: null, unit: 'خەرج', note: 'خەرجی گەیاندن', icon: Icons.delivery_dining_rounded);
      case 'price_per_unit': return (a: 'کۆی نرخ', b: 'ژمارە / کێش', c: null, unit: 'بۆ یەکە', note: 'نرخ ÷ یەکە', icon: Icons.sell_rounded);
      case 'temperature_converter': return (a: '°C', b: '1', c: null, unit: '°F', note: 'Celsius → Fahrenheit', icon: Icons.thermostat_rounded);
      case 'speed_converter': return (a: 'km/h', b: '1', c: null, unit: 'mph', note: 'km/h → mph', icon: Icons.speed_rounded);
      case 'weight_converter': return (a: 'kg', b: '1', c: null, unit: 'lb', note: 'kg → lb', icon: Icons.monitor_weight_rounded);
      case 'length_converter': return (a: 'm', b: '1', c: null, unit: 'ft', note: 'meter → feet', icon: Icons.straighten_rounded);
      default: return (a: 'A', b: 'B', c: null, unit: '', note: '', icon: Icons.calculate_rounded);
    }
  }

  double? _result() {
    final a = double.tryParse(_a.text.replaceAll(',', '.'));
    final b = double.tryParse(_b.text.replaceAll(',', '.'));
    final c = double.tryParse(_c.text.replaceAll(',', '.'));
    if (a == null) return null;
    switch (widget.mode) {
      case 'fuel_cost_calculator': return b == null || c == null ? null : a * b / 100 * c;
      case 'travel_time_calculator': return b == null || b == 0 ? null : a / b;
      case 'work_hours_calculator': return b == null ? null : a * b;
      case 'storage_converter': return a * 1024;
      case 'data_usage_calculator': return b == null ? null : a * b / 1024;
      case 'aspect_ratio_calculator': return b == null || b == 0 ? null : a / b;
      case 'electricity_cost': return b == null ? null : a * b;
      case 'battery_runtime': return b == null || b == 0 ? null : a / b;
      case 'fuel_economy': return b == null || b == 0 ? null : a / b;
      case 'room_area':
      case 'land_area': return b == null ? null : a * b;
      case 'paint_calculator': return b == null || b == 0 ? null : a / b;
      case 'tile_calculator': return b == null || b == 0 ? null : (a / b).ceilToDouble();
      case 'cash_change': return b == null ? null : a - b;
      case 'delivery_fee': return b == null ? null : a * b;
      case 'price_per_unit': return b == null || b == 0 ? null : a / b;
      case 'temperature_converter': return (a * 9 / 5) + 32;
      case 'speed_converter': return a * 0.621371;
      case 'weight_converter': return a * 2.2046226218;
      case 'length_converter': return a * 3.280839895;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    final result = _result();
    return _ToolScaffold(
      title: widget.title,
      icon: spec.icon,
      child: Column(children: [
        TextField(controller: _a, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: spec.a)),
        const SizedBox(height: 12),
        if (!['storage_converter', 'temperature_converter', 'speed_converter', 'weight_converter', 'length_converter'].contains(widget.mode))
          TextField(controller: _b, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: spec.b)),
        if (spec.c != null) ...[
          const SizedBox(height: 12),
          TextField(controller: _c, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: spec.c)),
        ],
        const SizedBox(height: 14),
        _resultCard(context, 'ئەنجام', result == null ? '—' : '${_formatNumber(result)} ${spec.unit}', spec.note),
      ]),
    );
  }
}

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key, required this.title});
  final String title;
  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _amount = TextEditingController();
  String _from = 'USD';
  String _to = 'IQD';
  final Map<String, double> _rates = {'IQD': 1, 'USD': 1300, 'EUR': 1420, 'TRY': 33};
  @override
  void dispose() { _amount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final result = amount == 0 ? 0 : amount * (_rates[_from]! / _rates[_to]!);
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.currency_exchange_rounded,
      child: Column(children: [
        TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'بڕی پارە')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: _from, items: _rates.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _from = v ?? _from), decoration: const InputDecoration(labelText: 'لە'))),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(value: _to, items: _rates.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _to = v ?? _to), decoration: const InputDecoration(labelText: 'بۆ'))),
        ]),
        const SizedBox(height: 14),
        _resultCard(context, 'ئەنجام', '${_formatNumber(result)} $_to', '١ USD ≈ ١٣٠٠ IQD و نرخەکان دەستییەن و دەتوانرێت دواتر Live بکرێن.'),
      ]),
    );
  }
}

class BillSplitterScreen extends StatefulWidget {
  const BillSplitterScreen({super.key, required this.title});
  final String title;
  @override
  State<BillSplitterScreen> createState() => _BillSplitterScreenState();
}

class _BillSplitterScreenState extends State<BillSplitterScreen> {
  final _total = TextEditingController();
  final _people = TextEditingController(text: '2');
  final _service = TextEditingController(text: '0');
  @override
  void dispose() { _total.dispose(); _people.dispose(); _service.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(_total.text.replaceAll(',', '.')) ?? 0;
    final people = int.tryParse(_people.text) ?? 1;
    final service = double.tryParse(_service.text.replaceAll(',', '.')) ?? 0;
    final grand = total + service;
    final each = people <= 0 ? 0 : grand / people;
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.receipt_long_rounded,
      child: Column(children: [
        TextField(controller: _total, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'کۆی حساب')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _people, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'ژمارەی کەسەکان'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _service, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'خزمەتگوزاری / بخشیش'))),
        ]),
        const SizedBox(height: 14),
        _resultCard(context, 'بۆ هەر کەسێک', _formatNumber(each), 'کۆی گشتی: ${_formatNumber(grand)}'),
      ]),
    );
  }
}

class TipCalculatorScreen extends StatefulWidget {
  const TipCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<TipCalculatorScreen> createState() => _TipCalculatorScreenState();
}

class _TipCalculatorScreenState extends State<TipCalculatorScreen> {
  final _bill = TextEditingController();
  double _percent = 10;
  @override
  void dispose() { _bill.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final bill = double.tryParse(_bill.text.replaceAll(',', '.')) ?? 0;
    final tip = bill * _percent / 100;
    final total = bill + tip;
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.payments_rounded,
      child: Column(children: [
        TextField(controller: _bill, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'بڕی حساب')),
        const SizedBox(height: 12),
        Slider(value: _percent, min: 0, max: 30, divisions: 30, label: '${_percent.round()}%', onChanged: (v) => setState(() => _percent = v)),
        _resultCard(context, 'بخشیش', _formatNumber(tip), 'کۆی گشتی: ${_formatNumber(total)}'),
      ]),
    );
  }
}

class ProfitCalculatorScreen extends StatefulWidget {
  const ProfitCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<ProfitCalculatorScreen> createState() => _ProfitCalculatorScreenState();
}

class _ProfitCalculatorScreenState extends State<ProfitCalculatorScreen> {
  final _buy = TextEditingController();
  final _sell = TextEditingController();
  @override
  void dispose() { _buy.dispose(); _sell.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final buy = double.tryParse(_buy.text.replaceAll(',', '.')) ?? 0;
    final sell = double.tryParse(_sell.text.replaceAll(',', '.')) ?? 0;
    final profit = sell - buy;
    final margin = buy > 0 ? (profit / buy) * 100 : 0;
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.trending_up_rounded,
      child: Column(children: [
        TextField(controller: _buy, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'نرخی کڕین')),
        const SizedBox(height: 12),
        TextField(controller: _sell, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'نرخی فرۆشتن')),
        const SizedBox(height: 14),
        _resultCard(context, 'قازانج', _formatNumber(profit), 'Margin: ${_formatNumber(margin)}%'),
      ]),
    );
  }
}

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _amount = TextEditingController();
  final _months = TextEditingController(text: '12');
  final _rate = TextEditingController(text: '0');
  @override
  void dispose() { _amount.dispose(); _months.dispose(); _rate.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final months = int.tryParse(_months.text) ?? 1;
    final rate = double.tryParse(_rate.text.replaceAll(',', '.')) ?? 0;
    final total = amount + (amount * rate / 100);
    final monthly = months <= 0 ? total : total / months;
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.account_balance_rounded,
      child: Column(children: [
        TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'بڕی قەرز')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _months, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'مانگ'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'سوود %'))),
        ]),
        const SizedBox(height: 14),
        _resultCard(context, 'قیستی مانگانە', _formatNumber(monthly), 'کۆی گشتی: ${_formatNumber(total)}'),
      ]),
    );
  }
}

class SavingsGoalScreen extends StatefulWidget {
  const SavingsGoalScreen({super.key, required this.title});
  final String title;
  @override
  State<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends State<SavingsGoalScreen> {
  final _goal = TextEditingController();
  final _monthly = TextEditingController();
  @override
  void dispose() { _goal.dispose(); _monthly.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final goal = double.tryParse(_goal.text.replaceAll(',', '.')) ?? 0;
    final monthly = double.tryParse(_monthly.text.replaceAll(',', '.')) ?? 0;
    final months = (goal > 0 && monthly > 0) ? (goal / monthly).ceil() : 0;
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.track_changes_rounded,
      child: Column(children: [
        TextField(controller: _goal, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'ئامانجی پارە')),
        const SizedBox(height: 12),
        TextField(controller: _monthly, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'پاشەکەوتی مانگانە')),
        const SizedBox(height: 14),
        _resultCard(context, 'مانگی پێویست', months.toString(), 'دەگاتە ${_formatNumber(goal)} دوای $months مانگ.'),
      ]),
    );
  }
}

class RandomNumberScreen extends StatefulWidget {
  const RandomNumberScreen({super.key, required this.title});
  final String title;
  @override
  State<RandomNumberScreen> createState() => _RandomNumberScreenState();
}

class _RandomNumberScreenState extends State<RandomNumberScreen> {
  final _min = TextEditingController(text: '1');
  final _max = TextEditingController(text: '100');
  int? _value;
  @override
  void dispose() { _min.dispose(); _max.dispose(); super.dispose(); }
  void _generate() {
    final min = int.tryParse(_min.text) ?? 1;
    final max = int.tryParse(_max.text) ?? min;
    final low = math.min(min, max);
    final high = math.max(min, max);
    setState(() => _value = low + math.Random().nextInt((high - low) + 1));
  }
  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.casino_rounded,
      child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum'))),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.casino_rounded), label: const Text('دروست بکە')),
        if (_value != null) ...[const SizedBox(height: 14), _resultCard(context, 'ئەنجام', _value.toString(), 'ژمارەی ڕێکەوت')],
      ]),
    );
  }
}

class CoinFlipScreen extends StatefulWidget {
  const CoinFlipScreen({super.key, required this.title});
  final String title;
  @override
  State<CoinFlipScreen> createState() => _CoinFlipScreenState();
}

class _CoinFlipScreenState extends State<CoinFlipScreen> {
  String _result = 'شیر / یان نووس';
  void _flip() => setState(() => _result = math.Random().nextBool() ? 'شیر' : 'نووس');
  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(title: widget.title, icon: Icons.monetization_on_rounded, child: Column(children: [
      FilledButton.icon(onPressed: _flip, icon: const Icon(Icons.refresh_rounded), label: const Text('هاوبدەرەوە')),
      const SizedBox(height: 14),
      _resultCard(context, 'ئەنجام', _result, 'Coin Flip'),
    ]));
  }
}

class DiceRollerScreen extends StatefulWidget {
  const DiceRollerScreen({super.key, required this.title});
  final String title;
  @override
  State<DiceRollerScreen> createState() => _DiceRollerScreenState();
}

class _DiceRollerScreenState extends State<DiceRollerScreen> {
  int _value = 1;
  void _roll() => setState(() => _value = 1 + math.Random().nextInt(6));
  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(title: widget.title, icon: Icons.casino_rounded, child: Column(children: [
      FilledButton.icon(onPressed: _roll, icon: const Icon(Icons.casino_rounded), label: const Text('فڕێبدە')),
      const SizedBox(height: 14),
      _resultCard(context, 'ئەنجام', _value.toString(), 'Dice Roller'),
    ]));
  }
}

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key, required this.title});
  final String title;
  @override
  State<PasswordGeneratorScreen> createState() => _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  double _length = 12;
  bool _uppercase = true;
  bool _numbers = true;
  bool _symbols = true;
  String _password = '';
  void _generate() {
    var chars = 'abcdefghijklmnopqrstuvwxyz';
    if (_uppercase) chars += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (_numbers) chars += '0123456789';
    if (_symbols) chars += '!@#\$%^&*()_+-=';
    final r = math.Random.secure();
    final value = List.generate(_length.round(), (_) => chars[r.nextInt(chars.length)]).join();
    setState(() => _password = value);
  }
  @override
  void initState() { super.initState(); _generate(); }
  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(title: widget.title, icon: Icons.key_rounded, child: Column(children: [
      Row(children: [Expanded(child: Text('درێژی: ${_length.round()}')), TextButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh_rounded), label: const Text('نوێ'))]),
      Slider(value: _length, min: 6, max: 32, divisions: 26, onChanged: (v) => setState(() => _length = v)),
      SwitchListTile(value: _uppercase, onChanged: (v) => setState(() => _uppercase = v), title: const Text('پیتە گەورەکان')),
      SwitchListTile(value: _numbers, onChanged: (v) => setState(() => _numbers = v), title: const Text('ژمارەکان')),
      SwitchListTile(value: _symbols, onChanged: (v) => setState(() => _symbols = v), title: const Text('هێماکان')),
      _resultCard(context, 'پاسوورد', _password, 'بە local دروست دەبێت و هیچ شوێنێک نەنێردرێت.'),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: _password)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کۆپی کرا'))); }, icon: const Icon(Icons.copy_rounded), label: const Text('کۆپی')),
    ]));
  }
}

class TextCounterScreen extends StatefulWidget {
  const TextCounterScreen({super.key, required this.title});
  final String title;
  @override
  State<TextCounterScreen> createState() => _TextCounterScreenState();
}

class _TextCounterScreenState extends State<TextCounterScreen> {
  final _text = TextEditingController();
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final value = _text.text;
    final words = value.trim().isEmpty ? 0 : value.trim().split(RegExp(r'\s+')).length;
    final chars = value.runes.length;
    final lines = value.isEmpty ? 0 : '\n'.allMatches(value).length + 1;
    return _ToolScaffold(title: widget.title, icon: Icons.text_fields_rounded, child: Column(children: [
      TextField(controller: _text, minLines: 5, maxLines: 8, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'دەقەکەت')),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: _resultCard(context, 'وشە', words.toString(), '')), const SizedBox(width: 12), Expanded(child: _resultCard(context, 'پیت', chars.toString(), ''))]),
      const SizedBox(height: 12),
      _resultCard(context, 'هێڵ', lines.toString(), ''),
    ]));
  }
}

class PhoneFormatterScreen extends StatefulWidget {
  const PhoneFormatterScreen({super.key, required this.title});
  final String title;
  @override
  State<PhoneFormatterScreen> createState() => _PhoneFormatterScreenState();
}

class _PhoneFormatterScreenState extends State<PhoneFormatterScreen> {
  final _text = TextEditingController();
  String _formatted = '';
  void _format() {
    var digits = _text.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('964')) digits = '0${digits.substring(3)}';
    if (digits.length == 10 && digits.startsWith('7')) digits = '0$digits';
    setState(() { _formatted = digits; });
  }
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(title: widget.title, icon: Icons.phone_android_rounded, child: Column(children: [
      TextField(controller: _text, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'ژمارەی مۆبایل'), onChanged: (_) => _format()),
      const SizedBox(height: 14),
      _resultCard(context, 'ڕێکخراو', _formatted.isEmpty ? '—' : _formatted, 'هەوڵی ڕێکخستن بۆ فۆرماتی عێراق دەدات.'),
      const SizedBox(height: 12),
      if (_formatted.isNotEmpty) FilledButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: _formatted)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ژمارەکە کۆپی کرا'))); }, icon: const Icon(Icons.copy_rounded), label: const Text('کۆپی')),
    ]));
  }
}

class DistanceCalculatorScreen extends StatefulWidget {
  const DistanceCalculatorScreen({super.key, required this.title});
  final String title;
  @override
  State<DistanceCalculatorScreen> createState() => _DistanceCalculatorScreenState();
}

class _DistanceCalculatorScreenState extends State<DistanceCalculatorScreen> {
  final _lat1 = TextEditingController();
  final _lng1 = TextEditingController();
  final _lat2 = TextEditingController();
  final _lng2 = TextEditingController();
  @override
  void dispose() { _lat1.dispose(); _lng1.dispose(); _lat2.dispose(); _lng2.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final lat1 = double.tryParse(_lat1.text.replaceAll(',', '.'));
    final lng1 = double.tryParse(_lng1.text.replaceAll(',', '.'));
    final lat2 = double.tryParse(_lat2.text.replaceAll(',', '.'));
    final lng2 = double.tryParse(_lng2.text.replaceAll(',', '.'));
    final distance = (lat1 != null && lng1 != null && lat2 != null && lng2 != null)
        ? Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000
        : null;
    return _ToolScaffold(title: widget.title, icon: Icons.place_rounded, child: Column(children: [
      Row(children: [Expanded(child: TextField(controller: _lat1, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Lat 1'))), const SizedBox(width: 12), Expanded(child: TextField(controller: _lng1, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Lng 1')))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: TextField(controller: _lat2, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Lat 2'))), const SizedBox(width: 12), Expanded(child: TextField(controller: _lng2, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Lng 2')))]),
      const SizedBox(height: 14),
      _resultCard(context, 'دووری نێوان دوو خاڵ', distance == null ? '—' : '${_formatNumber(distance)} km', 'Haversine / GPS distance'),
    ]));
  }
}

class CompassScreen extends StatelessWidget {
  const CompassScreen({super.key, required this.title});
  final String title;

  String _direction(double heading) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((heading + 22.5) ~/ 45) % 8];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), surfaceTintColor: Colors.transparent),
        body: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            final heading = snapshot.data?.heading;
            if (heading == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.explore_off_rounded, size: 58),
                    const SizedBox(height: 12),
                    const Text('سێنسەری Compass بەردەست نییە یان هێشتا داتا نەهاتووە.', textAlign: TextAlign.center),
                  ]),
                ),
              );
            }
            final normalized = heading < 0 ? heading + 360 : heading;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${normalized.toStringAsFixed(0)}° • ${_direction(normalized)}', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.surface, border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2)),
                    child: Stack(alignment: Alignment.center, children: [
                      const Positioned(top: 14, child: Text('N', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.red))),
                      const Positioned(bottom: 14, child: Text('S', style: TextStyle(fontWeight: FontWeight.w900))),
                      const Positioned(left: 18, child: Text('W', style: TextStyle(fontWeight: FontWeight.w900))),
                      const Positioned(right: 18, child: Text('E', style: TextStyle(fontWeight: FontWeight.w900))),
                      Transform.rotate(
                        angle: -normalized * math.pi / 180,
                        child: const Icon(Icons.navigation_rounded, size: 150, color: Color(0xFF0B5D3B)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Text('مۆبایلەکە بە ئاستی ڕاست بگرە بۆ خوێندنەوەی وردتر.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _resultCard(BuildContext context, String label, String value, String subtitle) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 11, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      if (subtitle.isNotEmpty) ...[const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12))],
    ]),
  );
}

String _formatNumber(num value) {
  final number = value.toDouble();
  if (number.abs() >= 1000000 || (number != 0 && number.abs() < 0.0001)) return number.toStringAsExponential(5);
  final text = number.toStringAsFixed(6);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _dateText(DateTime value) => '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
String _timeText(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

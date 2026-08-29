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
    try {
      final config = await AppConfigService.fetch();
      final tools = config.features
          .where((feature) => feature.group.toLowerCase() == 'tools')
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (!mounted) return;
      setState(() {
        _tools = tools;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
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

String _formatNumber(double value) {
  if (value.abs() >= 1000000 || (value != 0 && value.abs() < 0.0001)) return value.toStringAsExponential(5);
  final text = value.toStringAsFixed(6);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _dateText(DateTime value) => '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
String _timeText(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

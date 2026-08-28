import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_feature.dart';
import '../services/app_config_service.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _loading = true;
  String? _error;
  List<AppFeature> _tools = const <AppFeature>[];

  @override
  void initState() {
    super.initState();
    _load();
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

  void _open(AppFeature feature) {
    final page = _toolPage(feature);
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ئامرازی «${feature.title}» هێشتا لەم وەشانەدا UI ـی تایبەتی نییە.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget? _toolPage(AppFeature feature) {
    switch (feature.key) {
      case 'discount_calculator':
        return DiscountCalculatorScreen(title: feature.title);
      case 'unit_converter':
        return UnitConverterScreen(title: feature.title);
      case 'age_calculator':
        return AgeCalculatorScreen(title: feature.title);
      case 'date_calculator':
        return DateCalculatorScreen(title: feature.title);
      case 'qr_generator':
        return QrGeneratorScreen(title: feature.title);
      case 'price_compare':
        return PriceCompareScreen(title: feature.title);
      case 'simple_reminder':
        return ReminderScreen(title: feature.title);
      case 'compass':
        return CompassScreen(title: feature.title);
      default:
        return null;
    }
  }

  String _emojiFor(AppFeature feature) {
    final icon = feature.icon.trim();
    if (icon.isNotEmpty && icon.runes.length <= 4) return icon;
    const fallback = <String, String>{
      'discount_calculator': '🏷️',
      'unit_converter': '📏',
      'age_calculator': '🎂',
      'date_calculator': '📅',
      'qr_generator': '▦',
      'price_compare': '⚖️',
      'simple_reminder': '⏰',
      'compass': '🧭',
    };
    return fallback[feature.key] ?? '🧰';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
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
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF07563B), Color(0xFF2E7D32)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ئامرازەکانی نزیک',
                                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ئامرازە چالاکەکان لە داتابەیس و Admin ـەوە کۆنتڕۆڵ دەکرێن.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 11.5, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ],
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
              else if (_tools.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.handyman_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          const Text('هیچ ئامرازێکی چالاک نییە.', style: TextStyle(fontWeight: FontWeight.w900)),
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
                      childAspectRatio: 1.05,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = _tools[index];
                        return Material(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _open(tool),
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
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
                                        child: Text(_emojiFor(tool), style: const TextStyle(fontSize: 25)),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: theme.colorScheme.primary),
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
                      childCount: _tools.length,
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
      textDirection: TextDirection.rtl,
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
    final url = _qrText.isEmpty ? '' : 'https://api.qrserver.com/v1/create-qr-code/?size=360x360&margin=14&data=${Uri.encodeComponent(_qrText)}';
    return _ToolScaffold(
      title: widget.title,
      icon: Icons.qr_code_2_rounded,
      child: Column(children: [
        TextField(controller: _text, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'دەق یان لینک', hintText: 'https://...')),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => setState(() => _qrText = _text.text.trim()), icon: const Icon(Icons.qr_code_rounded), label: const Text('QR دروست بکە'))),
        if (url.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Image.network(url, width: 250, height: 250, errorBuilder: (_, __, ___) => const SizedBox(height: 180, child: Center(child: Text('QR لۆد نەکرا. ئینتەرنێت بپشکنە.')))),
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
      textDirection: TextDirection.rtl,
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

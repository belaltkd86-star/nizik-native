import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/module_item.dart';
import '../models/module_spec.dart';
import '../models/shop.dart';
import '../security/nizik_network.dart';
import '../services/module_service.dart';
import '../services/contact_service.dart';
import '../services/shop_service.dart';
import 'module_detail_screen.dart';

class ModuleListScreen extends StatefulWidget {
  final ModuleSpec spec;

  const ModuleListScreen({
    super.key,
    required this.spec,
  });

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ModuleItem> _items = const <ModuleItem>[];
  ShopMetadata? _metadata;

  bool _loading = true;
  String? _error;
  Timer? _debounce;

  int? _cityId;
  int? _regionId;
  String? _primaryFilterValue;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final metadata = await ShopService.fetchMetadata();
      if (!mounted) return;
      setState(() => _metadata = metadata);
    } catch (_) {
      // Location filters are optional. Content remains usable without them.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final primary = widget.spec.primaryFilter;
      final items = await ModuleService.fetchItems(
        widget.spec,
        query: _searchController.text,
        cityId: _cityId,
        regionId: _regionId,
        filterKey: primary?.key,
        filterValue: _primaryFilterValue,
      );

      if (!mounted) return;

      setState(() {
        _items = items;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
    setState(() {});
  }

  List<ShopRegion> get _visibleRegions {
    final metadata = _metadata;
    if (metadata == null || _cityId == null) {
      return const <ShopRegion>[];
    }

    return metadata.regions
        .where((region) => region.cityId == _cityId)
        .toList();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_cityId != null) count++;
    if (_regionId != null) count++;
    if ((_primaryFilterValue ?? '').isNotEmpty) count++;
    return count;
  }

  Future<void> _openFilters() async {
    var cityId = _cityId;
    var regionId = _regionId;
    var primaryValue = _primaryFilterValue;
    final primary = widget.spec.primaryFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final metadata = _metadata;
            final regions = metadata == null || cityId == null
                ? const <ShopRegion>[]
                : metadata.regions
                    .where((region) => region.cityId == cityId)
                    .toList();

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8DED8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'فلتەرکردن',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                cityId = null;
                                regionId = null;
                                primaryValue = null;
                              });
                            },
                            child: const Text('پاککردنەوە'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        value: cityId,
                        isExpanded: true,
                        decoration: _filterDecoration('شار'),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('هەموو شارەکان'),
                          ),
                          ...?metadata?.cities.map(
                            (city) => DropdownMenuItem<int?>(
                              value: city.id,
                              child: Text(city.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() {
                            cityId = value;
                            regionId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: regionId,
                        isExpanded: true,
                        decoration: _filterDecoration('ناوچە'),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('هەموو ناوچەکان'),
                          ),
                          ...regions.map(
                            (region) => DropdownMenuItem<int?>(
                              value: region.id,
                              child: Text(region.name),
                            ),
                          ),
                        ],
                        onChanged: cityId == null
                            ? null
                            : (value) {
                                setSheetState(() => regionId = value);
                              },
                      ),
                      if (primary != null &&
                          primary.options.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: primaryValue,
                          isExpanded: true,
                          decoration: _filterDecoration(primary.label),
                          items: <DropdownMenuItem<String?>>[
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('هەموو ${primary.label}'),
                            ),
                            ...primary.options.entries.map(
                              (entry) => DropdownMenuItem<String?>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setSheetState(() => primaryValue = value);
                          },
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _cityId = cityId;
                              _regionId = regionId;
                              _primaryFilterValue = primaryValue;
                            });
                            Navigator.of(sheetContext).pop();
                            _load();
                          },
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text(
                            'جێبەجێکردنی فلتەر',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _openRequest() async {
    await NizikContactService.request(
      context,
      section: widget.spec.title,
    );
  }

  void _openDetail(ModuleItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModuleDetailScreen(
          spec: widget.spec,
          itemId: item.id,
          initialItem: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: Text(
            spec.title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
            children: [
              _buildHero(),
              const SizedBox(height: 16),
              _buildSearchAndFilter(),
              const SizedBox(height: 16),
              _buildResultHeader(),
              const SizedBox(height: 10),
              if (_loading)
                _buildLoading()
              else if (_error != null)
                _buildError()
              else if (_items.isEmpty)
                _buildEmpty()
              else
                ..._items.map(_buildItemCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final spec = widget.spec;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B5D3B), Color(0xFF2E7D32)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180B5D3B),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(spec.emoji, style: const TextStyle(fontSize: 31)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.80), height: 1.4, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _openRequest,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                child: Row(
                  children: [
                    const Icon(Icons.add_comment_rounded, color: Colors.white, size: 21),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('داواکاری بنێرە', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('ئەگەر ئەوەی دەوێیت لێرە نییە، نامەیەک بۆ نزیک بنێرە.', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 10.5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 19),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'گەڕان لە ${widget.spec.title}...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF2E7D32),
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _load();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Badge(
          isLabelVisible: _activeFilterCount > 0,
          label: Text('$_activeFilterCount'),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(17),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultHeader() {
    return Row(
      children: [
        const Text(
          'داتاکان',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          _loading ? '...' : '${_items.length} ئەنجام',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Column(
      children: List.generate(
        4,
        (_) => Container(
          height: 126,
          margin: const EdgeInsets.only(bottom: 11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: LinearProgressIndicator(
              minHeight: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: Color(0xFFD65A5A),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'کێشەیەک ڕوویدا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('دووبارە'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            widget.spec.emoji,
            style: const TextStyle(fontSize: 42),
          ),
          const SizedBox(height: 12),
          Text(
            'هێشتا داتا نییە',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'کاتێک داتا لە Admin زیاد و پەسەند بکرێت، لێرە دەردەکەوێت.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ModuleItem item) {
    final image = item.imageUrls.isEmpty
        ? ''
        : NizikEndpoints.normalizeUrl(item.imageUrls.first);

    final badges = <Widget>[];

    for (final key in widget.spec.listFields) {
      final field = widget.spec.field(key);
      if (field == null) continue;

      final text = field.format(
        item.value(key),
        currency: item.currency,
      );

      if (text.isEmpty) continue;

      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5F0),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF36503B),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () => _openDetail(item),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: const Color(0xFFE8EDE8),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 96,
                    height: 96,
                    color: const Color(0xFFF0F5F0),
                    alignment: Alignment.center,
                    child: image.isEmpty
                        ? Text(
                            widget.spec.emoji,
                            style: const TextStyle(fontSize: 33),
                          )
                        : CachedNetworkImage(
                            imageUrl: image,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            fadeInDuration:
                                const Duration(milliseconds: 150),
                            errorWidget: (_, __, ___) => Text(
                              widget.spec.emoji,
                              style: const TextStyle(fontSize: 31),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.3,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (item.verified)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Tooltip(
                                message: 'پشتڕاستکراوە',
                                child: Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF2E9BFF),
                                  size: 19,
                                ),
                              ),
                            ),
                          if (item.featured)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF6A609),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      if (item.summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              item.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: badges.take(3).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

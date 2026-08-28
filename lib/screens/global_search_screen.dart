import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/app_feature.dart';
import '../models/global_search_result.dart';
import '../models/module_spec.dart';
import '../security/nizik_network.dart';
import '../services/app_config_service.dart';
import '../services/global_search_service.dart';
import '../services/location_preference_service.dart';
import 'market_detail_screen.dart';
import 'module_detail_screen.dart';
import 'shop_detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({
    super.key,
    this.initialQuery = '',
  });

  final String initialQuery;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  late final TextEditingController _controller;
  final _locationPrefs = LocationPreferenceService.instance;
  Timer? _debounce;
  List<GlobalSearchResult> _results = const <GlobalSearchResult>[];
  AppConfig? _config;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _loadConfig();
    if (widget.initialQuery.trim().length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await AppConfigService.fetch();
      if (mounted) setState(() => _config = config);
    } catch (_) {
      // Search remains usable for known modules even if config is offline.
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const <GlobalSearchResult>[];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 380), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final location = _locationPrefs.preference.value;
    try {
      final results = await GlobalSearchService.search(
        query: query,
        cityId: location.cityId,
        regionId: location.regionId,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
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

  ModuleSpec _specFor(GlobalSearchResult result) {
    final known = ModuleRegistry.byKey(result.featureKey);
    if (known != null) return known;

    AppFeature? feature;
    for (final item in _config?.features ?? const <AppFeature>[]) {
      if (item.key == result.featureKey) {
        feature = item;
        break;
      }
    }

    feature ??= AppFeature(
      key: result.featureKey,
      group: 'services',
      title: result.subtitle.isNotEmpty ? result.subtitle : result.featureKey,
      subtitle: '',
      icon: result.emoji,
      contentMode: 'directory',
      requiresLocation: false,
      sortOrder: 100,
    );
    return ModuleRegistry.fromFeature(feature);
  }

  void _open(GlobalSearchResult result) {
    if (result.kind == 'shop' && result.slug.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShopDetailScreen(slug: result.slug),
        ),
      );
      return;
    }
    if (result.kind == 'market' && result.id > 0) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MarketDetailScreen(itemId: result.id),
        ),
      );
      return;
    }
    if (result.kind == 'module' && result.id > 0 && result.featureKey.isNotEmpty) {
      final spec = _specFor(result);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ModuleDetailScreen(spec: spec, itemId: result.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _locationPrefs.preference.value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'گەڕانی گشتی',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    autofocus: widget.initialQuery.trim().isEmpty,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'دووکان، خزمەتگوزاری یان بازاڕ...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          location.hasArea
                              ? 'ئەنجامەکان بەپێی ${location.label}'
                              : 'ئەنجامەکان لە هەموو شوێنەکان',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.text.trim().length < 2) {
      return _emptyState(
        Icons.manage_search_rounded,
        'بۆ گەڕان لانیکەم دوو پیت بنووسە.',
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _results.isEmpty) {
      return _emptyState(Icons.cloud_off_rounded, _error!, retry: true);
    }
    if (_results.isEmpty) {
      return _emptyState(
        Icons.search_off_rounded,
        'هیچ ئەنجامێک بۆ ئەم گەڕانە نەدۆزرایەوە.',
      );
    }

    final groups = <String, List<GlobalSearchResult>>{
      'shop': <GlobalSearchResult>[],
      'module': <GlobalSearchResult>[],
      'market': <GlobalSearchResult>[],
    };
    for (final item in _results) {
      groups.putIfAbsent(item.kind, () => <GlobalSearchResult>[]).add(item);
    }

    final children = <Widget>[];
    for (final entry in <MapEntry<String, String>>[
      const MapEntry('shop', 'دووکانەکان'),
      const MapEntry('module', 'خزمەتگوزارییەکان'),
      const MapEntry('market', 'بازاڕ'),
    ]) {
      final items = groups[entry.key] ?? const <GlobalSearchResult>[];
      if (items.isEmpty) continue;
      children.add(_sectionTitle(entry.value, items.length));
      children.addAll(items.map(_resultCard));
      children.add(const SizedBox(height: 12));
    }

    return RefreshIndicator(
      onRefresh: _search,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: children,
      ),
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(GlobalSearchResult item) {
    final theme = Theme.of(context);
    final image = NizikEndpoints.normalizeUrl(item.imageUrl);
    final fallback = item.emoji.isEmpty
        ? (item.kind == 'shop' ? '🏪' : item.kind == 'market' ? '🛍️' : '🧩')
        : item.emoji;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(item),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 68,
                    height: 68,
                    color: theme.colorScheme.primaryContainer,
                    alignment: Alignment.center,
                    child: image.isEmpty
                        ? Text(fallback, style: const TextStyle(fontSize: 28))
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            width: 68,
                            height: 68,
                            errorWidget: (_, __, ___) =>
                                Text(fallback, style: const TextStyle(fontSize: 28)),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          if (item.verified)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.verified_rounded,
                                size: 18,
                                color: Color(0xFF2E9BFF),
                              ),
                            ),
                          if (item.featured)
                            const Padding(
                              padding: EdgeInsets.only(right: 3),
                              child: Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Color(0xFFF6A609),
                              ),
                            ),
                        ],
                      ),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              item.kindLabel,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (item.location.isNotEmpty) ...[
                            const SizedBox(width: 7),
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                item.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String text, {bool retry = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 100),
        Icon(
          icon,
          size: 62,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, height: 1.6),
        ),
        if (retry) ...[
          const SizedBox(height: 14),
          Center(
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('دووبارە هەوڵ بدەوە'),
            ),
          ),
        ],
      ],
    );
  }
}

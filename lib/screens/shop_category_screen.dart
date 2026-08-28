import 'dart:async';

import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/favorites_service.dart';
import '../services/location_preference_service.dart';
import '../services/shop_service.dart';
import '../services/shop_distance_service.dart';
import '../widgets/shop_card.dart';
import 'settings_screen.dart';
import 'shop_detail_screen.dart';

class ShopCategoryScreen extends StatefulWidget {
  final ShopBusinessType type;

  const ShopCategoryScreen({
    super.key,
    required this.type,
  });

  @override
  State<ShopCategoryScreen> createState() => _ShopCategoryScreenState();
}

class _ShopCategoryScreenState extends State<ShopCategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _locationPrefs = LocationPreferenceService.instance;

  Timer? _debounce;
  List<Shop> _shops = const <Shop>[];
  bool _loading = true;
  bool _openNow = false;
  bool _nearestFirst = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locationPrefs.preference.addListener(_onLocationChanged);
    _loadShops();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationPrefs.preference.removeListener(_onLocationChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLocationChanged() => _loadShops();

  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadShops);
  }

  Future<void> _loadShops() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final location = _locationPrefs.preference.value;

    try {
      final shops = await ShopService.fetchShops(
        query: _searchController.text,
        type: widget.type.key,
        cityId: location.cityId,
        regionId: location.regionId,
        openNow: _openNow,
      );
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _loading = false;
      });
      unawaited(_resolveDistances(shops, location));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resolveDistances(
    List<Shop> shops,
    NizikLocationPreference location,
  ) async {
    await ShopDistanceService.instance.resolveForShops(shops, location);
    if (mounted) setState(() {});
  }

  void _openShop(Shop shop) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShopDetailScreen(slug: shop.slug)),
    );
  }

  Future<void> _toggleFavorite(Shop shop) async {
    await FavoritesService.toggleShop(shop);
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = widget.type.icon.trim().isEmpty ? '🏪' : widget.type.icon.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 19)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.type.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    ValueListenableBuilder<NizikLocationPreference>(
                      valueListenable: _locationPrefs.preference,
                      builder: (context, location, _) => Text(
                        location.hasArea ? location.label : 'هەموو شوێنەکان',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'گۆڕینی شوێن',
              onPressed: _openSettings,
              icon: const Icon(Icons.location_on_outlined),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _loadShops,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ValueListenableBuilder<NizikLocationPreference>(
                          valueListenable: _locationPrefs.preference,
                          builder: (context, location, _) => Text(
                            location.hasArea
                                ? 'دووکانەکانی ${widget.type.name} لە ${location.label}'
                                : 'دووکانەکانی ${widget.type.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (!_loading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${_shops.length}',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _loadShops(),
                  decoration: InputDecoration(
                    hintText: 'گەڕان لە ${widget.type.name}...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              _loadShops();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: _openNow,
                      avatar: const Icon(Icons.schedule_rounded, size: 17),
                      label: const Text('تەنها کراوەکان'),
                      onSelected: (value) {
                        setState(() => _openNow = value);
                        _loadShops();
                      },
                    ),
                    FilterChip(
                      selected: _nearestFirst,
                      avatar: const Icon(Icons.near_me_rounded, size: 17),
                      label: const Text('نزیکترین'),
                      onSelected: (value) => setState(() => _nearestFirst = value),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 52),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadShops,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('دووبارە'),
            ),
          ],
        ),
      );
    }

    if (_shops.isEmpty) {
      final location = _locationPrefs.preference.value;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 22),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Icon(Icons.storefront_outlined, size: 52),
            const SizedBox(height: 10),
            Text(
              location.hasArea
                  ? 'لە ${location.label} هیچ دووکانێکی ${widget.type.name} نەدۆزرایەوە.'
                  : 'هیچ دووکانێکی ${widget.type.name} نەدۆزرایەوە.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: ShopDistanceService.instance.distances,
      builder: (context, distances, _) {
        final sorted = _nearestFirst &&
                _locationPrefs.preference.value.hasCoordinates
            ? ShopDistanceService.instance.sortNearest(_shops)
            : (List<Shop>.of(_shops)
              ..sort((a, b) {
                if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
                return a.name.compareTo(b.name);
              }));

        return ValueListenableBuilder<Set<String>>(
          valueListenable: FavoritesService.notifier,
          builder: (context, favorites, __) {
            return Column(
              children: sorted
                  .map(
                    (shop) => ShopCard(
                      shop: shop,
                      distanceText:
                          ShopDistanceService.instance.distanceTextFor(shop.slug),
                      isFavorite: favorites.contains(shop.slug),
                      onFavoriteTap: () => _toggleFavorite(shop),
                      onTap: () => _openShop(shop),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}

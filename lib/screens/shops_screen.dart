import 'dart:async';

import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/favorites_service.dart';
import '../services/location_preference_service.dart';
import '../services/shop_service.dart';
import '../widgets/shop_card.dart';
import 'settings_screen.dart';
import 'shop_category_screen.dart';
import 'shop_detail_screen.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _locationPrefs = LocationPreferenceService.instance;

  Timer? _debounce;
  ShopMetadata? _metadata;
  List<Shop> _searchResults = const <Shop>[];
  bool _loadingCategories = true;
  bool _searching = false;
  String? _categoryError;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _locationPrefs.preference.addListener(_onLocationChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationPrefs.preference.removeListener(_onLocationChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    _loadCategories();
    if (_searchController.text.trim().isNotEmpty) {
      _searchShops();
    }
  }

  Future<void> _loadAll() async {
    await _loadCategories();
    if (_searchController.text.trim().isNotEmpty) {
      await _searchShops();
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });

    final location = _locationPrefs.preference.value;

    try {
      final metadata = await ShopService.fetchMetadata(
        cityId: location.cityId,
        regionId: location.regionId,
        occupiedOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _metadata = metadata;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categoryError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = const <Shop>[];
        _searching = false;
        _searchError = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), _searchShops);
  }

  Future<void> _searchShops() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
    });

    final location = _locationPrefs.preference.value;

    try {
      final shops = await ShopService.fetchShops(
        query: query,
        cityId: location.cityId,
        regionId: location.regionId,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = shops;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openCategory(ShopBusinessType type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShopCategoryScreen(type: type)),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'دووکانەکان',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ValueListenableBuilder<NizikLocationPreference>(
                            valueListenable: _locationPrefs.preference,
                            builder: (context, location, _) {
                              return Text(
                                location.hasArea
                                    ? 'بەشە چالاکەکانی دووکان لە ${location.label}'
                                    : 'شوێن دیاری بکە بۆ نیشاندانی دووکانەکانی ناوچەکەت',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'گۆڕینی شوێن',
                      onPressed: _openSettings,
                      icon: const Icon(Icons.edit_location_alt_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildLocationCard(),
                const SizedBox(height: 16),
                _buildSearch(),
                if (_searchController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSearchResults(),
                  const SizedBox(height: 22),
                ] else
                  const SizedBox(height: 22),
                _buildSectionHeader(),
                const SizedBox(height: 12),
                _buildCategoryGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final theme = Theme.of(context);
    return ValueListenableBuilder<NizikLocationPreference>(
      valueListenable: _locationPrefs.preference,
      builder: (context, location, _) {
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  location.isAutomatic
                      ? Icons.my_location_rounded
                      : Icons.location_on_rounded,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      location.isAutomatic
                          ? 'شوێن بە GPS خۆکارە'
                          : location.isManual
                              ? 'شوێن بە دەستی هەڵبژێردراوە'
                              : 'لە سێتینگ شوێن هەڵبژێرە',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openSettings,
                child: const Text('گۆڕین'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _searchShops(),
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'گەڕان بە ناوی دووکان...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _debounce?.cancel();
                  _searchController.clear();
                  setState(() {
                    _searchResults = const <Shop>[];
                    _searching = false;
                    _searchError = null;
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    final theme = Theme.of(context);
    final types = (_metadata?.businessTypes ?? const <ShopBusinessType>[])
        .where((type) => type.shopCount > 0)
        .toList(growable: false);
    final totalShops = types.fold<int>(0, (sum, type) => sum + type.shopCount);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.grid_view_rounded,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'بەشەکانی دووکان',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 2),
              Text(
                'تەنها بەشەکانی خاوەن دووکان نیشان دەدرێن',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        if (!_loadingCategories && _categoryError == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$totalShops دووکان',
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final theme = Theme.of(context);

    if (_loadingCategories) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_categoryError != null) {
      return _messageCard(
        icon: Icons.cloud_off_rounded,
        message: _categoryError!,
        actionLabel: 'دووبارە',
        onAction: _loadCategories,
      );
    }

    final types = (_metadata?.businessTypes ?? const <ShopBusinessType>[])
        .where(
          (type) =>
              type.key.trim().isNotEmpty &&
              type.name.trim().isNotEmpty &&
              type.shopCount > 0,
        )
        .toList(growable: false);

    if (types.isEmpty) {
      final location = _locationPrefs.preference.value;
      return _messageCard(
        icon: Icons.storefront_outlined,
        message: location.hasArea
            ? 'لە ${location.label} هێشتا هیچ دووکانێک تۆمار نەکراوە.'
            : 'هێشتا هیچ دووکانێک تۆمار نەکراوە.',
        actionLabel: 'گۆڕینی شوێن',
        onAction: _openSettings,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: types.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) => _categoryCard(types[index]),
    );
  }

  Widget _categoryCard(ShopBusinessType type) {
    final theme = Theme.of(context);
    final icon = type.icon.trim().isEmpty ? '🏪' : type.icon.trim();

    return Semantics(
      button: true,
      label: '${type.name}، ${type.shopCount} دووکان',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openCategory(type),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  theme.colorScheme.primaryContainer.withOpacity(0.80),
                  theme.colorScheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.82),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 25)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${type.shopCount}',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    type.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${type.shopCount} دووکان',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final theme = Theme.of(context);

    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchError != null) {
      return _messageCard(
        icon: Icons.search_off_rounded,
        message: _searchError!,
        actionLabel: 'دووبارە',
        onAction: _searchShops,
      );
    }

    if (_searchResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off_rounded, size: 42),
            SizedBox(height: 8),
            Text('دووکانێک بەم ناوە نەدۆزرایەوە.'),
          ],
        ),
      );
    }

    final sorted = List<Shop>.of(_searchResults)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'ئەنجامی گەڕان',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${sorted.length} دووکان',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<Set<String>>(
          valueListenable: FavoritesService.notifier,
          builder: (context, favorites, _) => Column(
            children: sorted
                .map(
                  (shop) => ShopCard(
                    shop: shop,
                    isFavorite: favorites.contains(shop.slug),
                    onFavoriteTap: () => _toggleFavorite(shop),
                    onTap: () => _openShop(shop),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

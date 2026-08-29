import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_feature.dart';
import '../models/module_spec.dart';
import '../models/shop.dart';
import '../services/app_config_service.dart';
import '../services/favorites_service.dart';
import '../services/location_preference_service.dart';
import '../services/shop_service.dart';
import '../services/shop_distance_service.dart';
import '../services/theme_service.dart';
import '../widgets/shop_card.dart';
import '../widgets/voice_search_sheet.dart';
import 'favorites_screen.dart';
import 'global_search_screen.dart';
import 'module_list_screen.dart';
import 'services_screen.dart';
import 'shop_detail_screen.dart';
import 'tools_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenMarket,
    this.onOpenMap,
    this.onOpenShops,
    this.onOpenServices,
  });

  final VoidCallback? onOpenMarket;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenShops;
  final VoidCallback? onOpenServices;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationPrefs = LocationPreferenceService.instance;

  List<Shop> _shops = const <Shop>[];
  AppConfig? _appConfig;
  bool _loadingShops = true;
  bool _loadingServices = true;
  String? _shopsError;
  String? _servicesError;

  @override
  void initState() {
    super.initState();
    _locationPrefs.preference.addListener(_onLocationChanged);
    _loadServices();
    _loadShops();
  }

  @override
  void dispose() {
    _locationPrefs.preference.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    _loadShops();
  }

  Future<void> _loadServices() async {
    if (!mounted) return;
    setState(() {
      _loadingServices = true;
      _servicesError = null;
    });

    try {
      final config = await AppConfigService.fetch();
      if (!mounted) return;
      setState(() {
        _appConfig = config;
        _loadingServices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingServices = false;
        _servicesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadShops() async {
    if (!mounted) return;
    setState(() {
      _loadingShops = true;
      _shopsError = null;
    });

    final location = _locationPrefs.preference.value;

    try {
      final shops = await ShopService.fetchShops(
        cityId: location.cityId,
        regionId: location.regionId,
      );
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _loadingShops = false;
      });
      unawaited(ShopDistanceService.instance.resolveForShops(shops, location).then((_) { if (mounted) setState(() {}); }));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingShops = false;
        _shopsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait<void>([
      _loadServices(),
      _loadShops(),
    ]);
  }

  List<ModuleSpec> get _enabledModules {
    final config = _appConfig;
    if (config == null) return const <ModuleSpec>[];

    final features = config.features
        .where((feature) => feature.group.toLowerCase() == 'services')
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return features.map(ModuleRegistry.fromFeature).toList(growable: false);
  }

  bool get _marketEnabled => _appConfig?.isEnabled('market') ?? false;

  int get _enabledToolCount {
    final config = _appConfig;
    if (config == null) return 0;
    return config.features
        .where((feature) => feature.group.toLowerCase() == 'tools')
        .length;
  }

  void _openModule(ModuleSpec spec) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ModuleListScreen(spec: spec)),
    );
  }

  void _openAllServices() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServicesScreen()),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  void _openGlobalSearch([String query = '']) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GlobalSearchScreen(initialQuery: query)),
    );
  }

  void _openTools() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ToolsScreen()),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildSearch(),
                const SizedBox(height: 14),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildServicesSection(),
                const SizedBox(height: 28),
                _buildShopHeader(),
                const SizedBox(height: 12),
                _buildShops(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFF43A047),
          child: Icon(Icons.storefront_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'NIZIK',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: .6),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'نزیک',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ValueListenableBuilder<NizikLocationPreference>(
                valueListenable: _locationPrefs.preference,
                builder: (context, location, _) {
                  return Row(
                    children: [
                      Icon(
                        location.isAutomatic
                            ? Icons.my_location_rounded
                            : Icons.location_on_outlined,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: theme.brightness == Brightness.dark ? 'لایت مۆد' : 'دارک مۆد',
          onPressed: ThemeService.instance.toggle,
          icon: Icon(
            theme.brightness == Brightness.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        IconButton(
          tooltip: 'دڵخوازەکان',
          onPressed: _openFavorites,
          icon: const Icon(Icons.favorite_rounded, color: Color(0xFFE53935)),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: _openGlobalSearch,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'گەڕان لە دووکان، خزمەتگوزاری و بازاڕ...',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ),
              NizikVoiceButton(
                compact: true,
                onResult: (value) => _openGlobalSearch(value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    final actions = <({String label, IconData icon, VoidCallback onTap})>[
      (label: 'نەخشە', icon: Icons.map_rounded, onTap: widget.onOpenMap ?? () {}),
      (label: 'دووکان', icon: Icons.storefront_rounded, onTap: widget.onOpenShops ?? () {}),
      (label: 'خزمەتگوزاری', icon: Icons.grid_view_rounded, onTap: widget.onOpenServices ?? _openAllServices),
      (label: 'ئامراز', icon: Icons.handyman_rounded, onTap: _openTools),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: actions[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: i == 3
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          actions[i].icon,
                          color: i == 3
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        actions[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i != actions.length - 1)
              SizedBox(
                height: 48,
                child: VerticalDivider(color: theme.colorScheme.outlineVariant, width: 4),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    final modules = _enabledModules;
    final itemCount = modules.length + (_marketEnabled ? 1 : 0);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.grid_view_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'خزمەتگوزارییەکان',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'بازاڕ و خزمەتگوزارییەکان لێرەوە بکەرەوە',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!_loadingServices && itemCount > 0)
              TextButton(onPressed: _openAllServices, child: const Text('هەمووی')),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingServices)
          const SizedBox(
            height: 142,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_servicesError != null)
          _messageCard(
            icon: Icons.cloud_off_rounded,
            text: 'خزمەتگوزارییەکان لۆد نەکران.',
            action: TextButton(onPressed: _loadServices, child: const Text('دووبارە')),
          )
        else if (itemCount == 0)
          _messageCard(
            icon: Icons.widgets_outlined,
            text: 'هیچ خزمەتگوزارییەکی چالاک نییە.',
          )
        else
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (_marketEnabled && index == 0) {
                  return _serviceCard(
                    emoji: '🛍️',
                    title: 'بازاڕ',
                    subtitle: 'کاڵا و شتە فرۆشیارییەکان ببینە و داواکاری بکە',
                    onTap: widget.onOpenMarket,
                  );
                }

                final moduleIndex = index - (_marketEnabled ? 1 : 0);
                final spec = modules[moduleIndex];

                return _serviceCard(
                  emoji: spec.emoji,
                  title: spec.title,
                  subtitle: spec.subtitle,
                  onTap: () => _openModule(spec),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _serviceCard({
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 174,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopHeader() {
    final theme = Theme.of(context);
    final location = _locationPrefs.preference.value;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location.hasArea ? 'دووکانەکانی ${location.label}' : 'دووکانەکان',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                'فلتەری دووکان لە پەڕەی سەرەکی لادراوە؛ شوێن لە سێتینگ کۆنتڕۆڵ دەکرێت.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        if (!_loadingShops && _shopsError == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${_shops.length}',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShops() {
    if (_loadingShops) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 42),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_shopsError != null) {
      return _messageCard(
        icon: Icons.cloud_off_rounded,
        text: _shopsError!,
        action: TextButton(onPressed: _loadShops, child: const Text('دووبارە')),
      );
    }

    if (_shops.isEmpty) {
      final location = _locationPrefs.preference.value;
      return _messageCard(
        icon: Icons.storefront_outlined,
        text: location.hasArea
            ? 'لە ${location.label} هیچ دووکانێک نەدۆزرایەوە.'
            : 'هیچ دووکانێک نەدۆزرایەوە.',
      );
    }

    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: ShopDistanceService.instance.distances,
      builder: (context, distances, _) {
        final location = _locationPrefs.preference.value;
        final sorted = location.hasCoordinates
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
                  .take(8)
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

  Widget _messageCard({
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          if (action != null) action,
        ],
      ),
    );
  }
}

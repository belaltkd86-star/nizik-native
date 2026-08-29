import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_feature.dart';
import '../models/module_spec.dart';
import '../models/shop.dart';
import '../services/app_config_service.dart';
import '../services/favorites_service.dart';
import '../services/location_preference_service.dart';
import '../services/shop_distance_service.dart';
import '../services/shop_service.dart';
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

  void _onLocationChanged() => _loadShops();

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
      unawaited(
        ShopDistanceService.instance.resolveForShops(shops, location).then((_) {
          if (mounted) setState(() {});
        }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingShops = false;
        _shopsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait<void>([_loadServices(), _loadShops()]);
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
    return config.features.where((feature) => feature.group.toLowerCase() == 'tools').length;
  }

  void _openModule(ModuleSpec spec) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ModuleListScreen(spec: spec)),
      );

  void _openAllServices() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ServicesScreen()),
      );

  void _openFavorites() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FavoritesScreen()),
      );

  void _openGlobalSearch([String query = '']) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GlobalSearchScreen(initialQuery: query)),
      );

  void _openTools() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ToolsScreen()),
      );

  void _openShop(Shop shop) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShopDetailScreen(slug: shop.slug)),
      );

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
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                  sliver: SliverToBoxAdapter(child: _buildHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  sliver: SliverToBoxAdapter(child: _buildSearch()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  sliver: SliverToBoxAdapter(child: _buildHeroBanner()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  sliver: SliverToBoxAdapter(child: _buildQuickActions()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  sliver: SliverToBoxAdapter(child: _buildServicesSection()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  sliver: SliverToBoxAdapter(child: _buildShopHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                  sliver: SliverToBoxAdapter(child: _buildShops()),
                ),
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
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF047857)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 11),
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
                  Text('نزیک', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                ],
              ),
              const SizedBox(height: 2),
              ValueListenableBuilder<NizikLocationPreference>(
                valueListenable: _locationPrefs.preference,
                builder: (context, location, _) => Row(
                  children: [
                    Icon(location.isAutomatic ? Icons.my_location_rounded : Icons.location_on_outlined, size: 13, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _HeaderButton(
          icon: theme.brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          tooltip: theme.brightness == Brightness.dark ? 'لایت مۆد' : 'دارک مۆد',
          onTap: ThemeService.instance.toggle,
        ),
        const SizedBox(width: 6),
        _HeaderButton(icon: Icons.favorite_rounded, tooltip: 'دڵخوازەکان', onTap: _openFavorites, color: const Color(0xFFE53935)),
      ],
    );
  }

  Widget _buildSearch() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: _openGlobalSearch,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 58,
          padding: const EdgeInsetsDirectional.only(start: 15, end: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 16, offset: const Offset(0, 7)),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'گەڕان لە دووکان، خزمەتگوزاری و بازاڕ…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.2, fontWeight: FontWeight.w600),
                ),
              ),
              NizikVoiceButton(compact: true, onResult: _openGlobalSearch),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 176),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B6B45), Color(0xFF119D5C)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF047857).withValues(alpha: .20), blurRadius: 28, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -12,
            bottom: -20,
            child: Icon(Icons.map_rounded, color: Colors.white.withValues(alpha: .12), size: 150),
          ),
          Positioned(
            left: 76,
            top: 18,
            child: Icon(Icons.location_on_rounded, color: Colors.white.withValues(alpha: .18), size: 58),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('نزیکترین شوێنەکان', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(
                        'دووکان و خزمەتگوزارییەکانی دەورت بە نەخشە بدۆزەوە',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: .84), fontSize: 11, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: widget.onOpenMap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF047857),
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: const Icon(Icons.near_me_rounded, size: 18),
                        label: const Text('بیکەرەوە لە نەخشە'),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 82,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: .14)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.map_outlined, color: Colors.white.withValues(alpha: .55), size: 56),
                      const Icon(Icons.location_on_rounded, color: Colors.white, size: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: theme.colorScheme.surface.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
              child: const Text('NIZIK MAP', textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    final actions = <({String label, String subtitle, IconData icon, VoidCallback onTap})>[
      (label: 'دووکان', subtitle: 'بەپێی جۆر', icon: Icons.storefront_rounded, onTap: widget.onOpenShops ?? () {}),
      (label: 'خزمەتگوزاری', subtitle: 'بەشەکان', icon: Icons.widgets_rounded, onTap: widget.onOpenServices ?? _openAllServices),
      (label: 'نەخشە', subtitle: 'لە نزیکت', icon: Icons.map_rounded, onTap: widget.onOpenMap ?? () {}),
      (label: 'ئامرازەکان', subtitle: _enabledToolCount > 0 ? '$_enabledToolCount ئامراز' : 'ئامرازە ڕۆژانەکان', icon: Icons.handyman_rounded, onTap: _openTools),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        childAspectRatio: 2.15,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        final emphasized = index == 2 || index == 3;
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: emphasized
                      ? theme.colorScheme.primary.withValues(alpha: .25)
                      : theme.colorScheme.outlineVariant,
                ),
                gradient: emphasized
                    ? LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer.withValues(alpha: .72),
                          theme.colorScheme.surface,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: emphasized ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      item.icon,
                      color: emphasized ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9.5, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServicesSection() {
    final modules = _enabledModules;
    final itemCount = modules.length + (_marketEnabled ? 1 : 0);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: Icons.widgets_rounded,
          title: 'خزمەتگوزارییەکان',
          subtitle: 'ئەوەی پێویستتە بە خێرایی بدۆزەوە',
          trailing: !_loadingServices && itemCount > 0 ? TextButton(onPressed: _openAllServices, child: const Text('هەمووی')) : null,
        ),
        const SizedBox(height: 12),
        if (_loadingServices)
          const _HomeLoadingRow()
        else if (_servicesError != null)
          _messageCard(icon: Icons.cloud_off_rounded, text: 'خزمەتگوزارییەکان لۆد نەکران.', action: TextButton(onPressed: _loadServices, child: const Text('دووبارە')))
        else if (itemCount == 0)
          _messageCard(icon: Icons.widgets_outlined, text: 'هیچ خزمەتگوزارییەکی چالاک نییە.')
        else
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: itemCount,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (_marketEnabled && index == 0) {
                  return _serviceCard(emoji: '🛍️', title: 'بازاڕ', subtitle: 'کاڵا و شتە فرۆشیارییەکان', onTap: widget.onOpenMarket);
                }
                final moduleIndex = index - (_marketEnabled ? 1 : 0);
                final spec = modules[moduleIndex];
                return _serviceCard(emoji: spec.emoji, title: spec.title, subtitle: spec.subtitle, onTap: () => _openModule(spec));
              },
            ),
          ),
      ],
    );
  }

  Widget _serviceCard({required String emoji, required String title, required String subtitle, required VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 166,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
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
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const Spacer(),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(11)),
                      child: Icon(Icons.arrow_back_rounded, size: 17, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const Spacer(),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10.3, height: 1.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopHeader() {
    final location = _locationPrefs.preference.value;
    return _SectionHeader(
      icon: Icons.storefront_rounded,
      title: location.hasArea ? 'دووکانەکانی ${location.label}' : 'دووکانە نزیکەکان',
      subtitle: 'نزیکترین و گرنگترین شوێنەکان بۆ تۆ',
      trailing: !_loadingShops && _shopsError == null
          ? TextButton.icon(onPressed: widget.onOpenShops, icon: const Icon(Icons.arrow_back_rounded, size: 17), label: Text('${_shops.length} دووکان'))
          : null,
    );
  }

  Widget _buildShops() {
    if (_loadingShops) return const _HomeLoadingShops();
    if (_shopsError != null) {
      return _messageCard(icon: Icons.cloud_off_rounded, text: _shopsError!, action: TextButton(onPressed: _loadShops, child: const Text('دووبارە')));
    }
    if (_shops.isEmpty) {
      final location = _locationPrefs.preference.value;
      return _messageCard(
        icon: Icons.storefront_outlined,
        text: location.hasArea ? 'لە ${location.label} هیچ دووکانێک نەدۆزرایەوە.' : 'هیچ دووکانێک نەدۆزرایەوە.',
        action: TextButton(onPressed: widget.onOpenMap, child: const Text('نەخشە')),
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
          builder: (context, favorites, __) => Column(
            children: sorted
                .take(8)
                .map(
                  (shop) => ShopCard(
                    shop: shop,
                    distanceText: ShopDistanceService.instance.distanceTextFor(shop.slug),
                    isFavorite: favorites.contains(shop.slug),
                    onFavoriteTap: () => _toggleFavorite(shop),
                    onTap: () => _openShop(shop),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _messageCard({required IconData icon, required String text, Widget? action}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (action != null) action,
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.tooltip, required this.onTap, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: color ?? theme.colorScheme.onSurface,
        minimumSize: const Size(42, 42),
      ),
      icon: Icon(icon, size: 21),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.subtitle, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: theme.colorScheme.primary, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10.5)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HomeLoadingRow extends StatelessWidget {
  const _HomeLoadingRow();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      height: 154,
      child: Row(
        children: List.generate(
          2,
          (index) => Expanded(
            child: Container(
              margin: EdgeInsetsDirectional.only(end: index == 0 ? 10 : 0),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeLoadingShops extends StatelessWidget {
  const _HomeLoadingShops();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 106,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
        ),
      ),
    );
  }
}

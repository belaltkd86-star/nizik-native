import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import '../services/shop_service.dart';
import '../widgets/shop_card.dart';
import 'shop_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenMarket;

  const HomeScreen({
    super.key,
    this.onOpenMarket,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Shop> _shops = [];
  ShopMetadata? _metadata;

  bool _loadingShops = true;
  bool _loadingMetadata = true;
  bool _gettingLocation = false;

  String? _shopsError;
  String _locationText = 'شوێن دیاری نەکراوە';

  int? _selectedCityId;
  int? _selectedRegionId;
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _loadShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final metadata = await ShopService.fetchMetadata();

      if (!mounted) return;

      setState(() {
        _metadata = metadata;
        _loadingMetadata = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingMetadata = false;
      });
    }
  }

  Future<void> _loadShops() async {
    if (!mounted) return;

    setState(() {
      _loadingShops = true;
      _shopsError = null;
    });

    try {
      final shops = await ShopService.fetchShops(
        query: _searchController.text,
        type: _selectedType,
        cityId: _selectedCityId,
        regionId: _selectedRegionId,
      );

      if (!mounted) return;

      setState(() {
        _shops = shops;
        _loadingShops = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingShops = false;
        _shopsError =
            e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _requestLocation() async {
    if (_gettingLocation) return;

    setState(() {
      _gettingLocation = true;
      _locationText = 'شوێن دیاری دەکرێت...';
    });

    try {
      final position =
          await LocationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        if (position == null) {
          _locationText = 'ڕێگە بە Location نەدراوە';
        } else {
          _locationText =
              '${position.latitude.toStringAsFixed(5)}, '
              '${position.longitude.toStringAsFixed(5)}';
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _locationText = 'هەڵە لە Location';
      });
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  List<ShopRegion> get _visibleRegions {
    final metadata = _metadata;

    if (metadata == null || _selectedCityId == null) {
      return const [];
    }

    return metadata.regions
        .where((region) => region.cityId == _selectedCityId)
        .toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedCityId = null;
      _selectedRegionId = null;
      _selectedType = 'all';
    });

    _loadShops();
  }

  void _openShop(Shop shop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          slug: shop.slug,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(String slug) async {
    await FavoritesService.toggle(slug);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8F6),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadShops,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                _buildSearch(),
                const SizedBox(height: 14),
                _buildFilters(),
                const SizedBox(height: 18),
                _buildMarketButton(),
                const SizedBox(height: 26),
                _buildSectionTitle(),
                const SizedBox(height: 14),
                _buildShops(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFF43A047),
          child: Icon(
            Icons.storefront_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'نزیک',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _locationText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'شوێنی ئێستا',
          onPressed:
              _gettingLocation ? null : _requestLocation,
          icon: _gettingLocation
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF43A047),
                ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _loadShops(),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'گەڕان بە ناوی دووکان...',
        prefixIcon: IconButton(
          onPressed: _loadShops,
          icon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF43A047),
          ),
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                  _loadShops();
                },
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    if (_loadingMetadata) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: LinearProgressIndicator(),
        ),
      );
    }

    final metadata = _metadata;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: Color(0xFF43A047),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'فلتەری دووکانەکان',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                ),
                label: const Text('پاککردنەوە'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField<int?>(
            value: _selectedCityId,
            isExpanded: true,
            decoration: _filterDecoration('شار'),
            items: [
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
              setState(() {
                _selectedCityId = value;
                _selectedRegionId = null;
              });

              _loadShops();
            },
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<int?>(
            value: _selectedRegionId,
            isExpanded: true,
            decoration: _filterDecoration('ناوچە'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('هەموو ناوچەکان'),
              ),
              ..._visibleRegions.map(
                (region) => DropdownMenuItem<int?>(
                  value: region.id,
                  child: Text(region.name),
                ),
              ),
            ],
            onChanged: _selectedCityId == null
                ? null
                : (value) {
                    setState(() {
                      _selectedRegionId = value;
                    });

                    _loadShops();
                  },
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            value: _selectedType,
            isExpanded: true,
            decoration:
                _filterDecoration('جۆری بزنس'),
            items: [
              const DropdownMenuItem<String>(
                value: 'all',
                child: Text('هەموو بەشەکان'),
              ),
              ...?metadata?.businessTypes.map(
                (type) => DropdownMenuItem<String>(
                  value: type.key,
                  child: Text(type.name),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedType = value ?? 'all';
              });

              _loadShops();
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF5F8F5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildMarketButton() {
    return SizedBox(
      height: 88,
      child: FilledButton(
        onPressed: widget.onOpenMarket,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(17),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.shopping_bag_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'بازاڕ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'کاڵا و شتە بەردەستەکان ببینە',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'دووکانەکان',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (!_loadingShops && _shopsError == null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_shops.length}',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
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
        padding: EdgeInsets.symmetric(vertical: 45),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_shopsError != null) {
      return _ErrorBox(
        message: _shopsError!,
        onRetry: _loadShops,
      );
    }

    if (_shops.isEmpty) {
      return const _EmptyShops();
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: FavoritesService.notifier,
      builder: (context, favorites, _) {
        return Column(
          children: _shops.map(
            (shop) => ShopCard(
              shop: shop,
              isFavorite: favorites.contains(shop.slug),
              onFavoriteTap: () =>
                  _toggleFavorite(shop.slug),
              onTap: () => _openShop(shop),
            ),
          ).toList(),
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorBox({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 44,
            color: Colors.black38,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('دووبارە هەوڵ بدەوە'),
          ),
        ],
      ),
    );
  }
}

class _EmptyShops extends StatelessWidget {
  const _EmptyShops();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 34,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 50,
            color: Colors.black26,
          ),
          SizedBox(height: 10),
          Text(
            'هیچ دووکانێک نەدۆزرایەوە',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

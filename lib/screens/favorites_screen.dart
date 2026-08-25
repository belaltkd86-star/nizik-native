import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/favorites_service.dart';
import '../services/shop_service.dart';
import '../widgets/shop_card.dart';
import 'shop_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() =>
      _FavoritesScreenState();
}

class _FavoritesScreenState
    extends State<FavoritesScreen> {
  List<Shop> _allShops = [];
  bool _loading = true;
  String? _error;

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
      final shops = await ShopService.fetchShops();

      if (!mounted) return;

      setState(() {
        _allShops = shops;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            e.toString().replaceFirst('Exception: ', '');
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8F6),
        appBar: AppBar(
          title: const Text(
            'دڵخوازەکان',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: FavoritesService.notifier,
            builder: (context, favorites, _) {
              if (_loading) {
                return ListView(
                  physics:
                      AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 220),
                    Center(
                      child: CircularProgressIndicator(),
                    ),
                  ],
                );
              }

              if (_error != null) {
                return ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 100),
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 50,
                            color: Colors.black38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(
                              Icons.refresh_rounded,
                            ),
                            label: const Text(
                              'دووبارە هەوڵ بدەوە',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final favoriteShops = _allShops
                  .where(
                    (shop) =>
                        favorites.contains(shop.slug),
                  )
                  .toList();

              if (favoriteShops.isEmpty) {
                return ListView(
                  physics:
                      AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(24),
                  children: [
                    SizedBox(height: 120),
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 68,
                      color: Colors.black26,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'هێشتا هیچ دووکانێکت نەخستووەتە دڵخوازەکان',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${favoriteShops.length} دووکان',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...favoriteShops.map(
                    (shop) => ShopCard(
                      shop: shop,
                      isFavorite: true,
                      onFavoriteTap: () async {
                        await FavoritesService.remove(
                          shop.slug,
                        );
                      },
                      onTap: () => _openShop(shop),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

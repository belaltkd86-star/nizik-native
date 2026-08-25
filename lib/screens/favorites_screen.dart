import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/local_store_service.dart';
import 'shop_profile_sheet.dart';

const _green = Color(0xFF059669);
const _softGreen = Color(0xFFECFDF5);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _background = Color(0xFFF8FAFC);
const _line = Color(0xFFE2E8F0);

class FavoritesScreen extends StatefulWidget {
  final int refreshSignal;

  const FavoritesScreen({
    super.key,
    this.refreshSignal = 0,
  });

  @override
  State<FavoritesScreen> createState() =>
      _FavoritesScreenState();
}

class _FavoritesScreenState
    extends State<FavoritesScreen> {
  final LocalStoreService _store =
      LocalStoreService.instance;

  List<Shop> _shops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant FavoritesScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshSignal !=
        widget.refreshSignal) {
      _load();
    }
  }

  Future<void> _load() async {
    final shops = await _store.getFavorites();

    if (!mounted) return;

    setState(() {
      _shops = shops;
      _loading = false;
    });
  }

  Future<void> _remove(Shop shop) async {
    await _store.toggleFavorite(shop);
    await _load();
  }

  Future<void> _open(Shop shop) async {
    await showShopProfileSheet(
      context,
      shop.slug,
      sourceShop: shop,
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: RefreshIndicator(
            color: _green,
            onRefresh: _load,
            child: CustomScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      18,
                      18,
                      18,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _softGreen,
                            borderRadius:
                                BorderRadius.circular(
                              15,
                            ),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'دڵخوازەکان',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'دوکانە هەڵبژێردراوەکانت',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child:
                          CircularProgressIndicator(
                        color: _green,
                      ),
                    ),
                  )
                else if (_shops.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyFavorites(),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      100,
                    ),
                    sliver: SliverList(
                      delegate:
                          SliverChildBuilderDelegate(
                        (context, index) {
                          if (index.isOdd) {
                            return const SizedBox(
                              height: 10,
                            );
                          }

                          final shopIndex =
                              index ~/ 2;
                          final shop =
                              _shops[shopIndex];

                          return _FavoriteCard(
                            shop: shop,
                            onTap: () =>
                                _open(shop),
                            onRemove: () =>
                                _remove(shop),
                          );
                        },
                        childCount:
                            _shops.length * 2 - 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.shop,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final logo =
        normalizeNizikUrl(shop.logoUrl);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color: _line,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: logo.isEmpty
                    ? const Icon(
                        Icons
                            .storefront_rounded,
                        color: _green,
                        size: 28,
                      )
                    : Image.network(
                        logo,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) {
                          return const Icon(
                            Icons
                                .storefront_rounded,
                            color: _green,
                            size: 28,
                          );
                        },
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      shop.location,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                      ),
                    ),
                    if (shop.bio.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        shop.bio,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'لابردن لە دڵخوازەکان',
                icon: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: _softGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: _green,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'هێشتا هیچ دڵخوازێکت نییە',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'لەسەر دڵی دوکانەکان کلیک بکە تا لێرە هەڵبگیرێن.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

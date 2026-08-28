import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/app_feature.dart';
import '../models/content_reference.dart';
import '../models/module_spec.dart';
import '../security/nizik_network.dart';
import '../services/favorites_service.dart';
import '../services/shop_service.dart';
import 'market_detail_screen.dart';
import 'module_detail_screen.dart';
import 'shop_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _hydrateLegacyShopFavorites();
  }

  Future<void> _hydrateLegacyShopFavorites() async {
    if (_hydrating || FavoritesService.notifier.value.isEmpty) return;
    _hydrating = true;
    try {
      final shops = await ShopService.fetchShops();
      for (final shop in shops) {
        if (FavoritesService.isFavorite(shop.slug)) {
          await FavoritesService.hydrateShop(shop);
        }
      }
    } catch (_) {
      // Saved local favorites are still usable when the network is unavailable.
    } finally {
      _hydrating = false;
    }
  }

  ModuleSpec _specFor(ContentReference item) {
    final known = ModuleRegistry.byKey(item.featureKey);
    if (known != null) return known;
    return ModuleRegistry.fromFeature(
      AppFeature(
        key: item.featureKey,
        group: 'services',
        title: item.subtitle.isNotEmpty ? item.subtitle : item.featureKey,
        subtitle: '',
        icon: item.emoji,
        contentMode: 'directory',
        requiresLocation: false,
        sortOrder: 100,
      ),
    );
  }

  void _open(ContentReference item) {
    switch (item.kind) {
      case 'shop':
        if (item.slug.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShopDetailScreen(slug: item.slug)),
        );
        return;
      case 'market':
        if (item.id <= 0) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MarketDetailScreen(itemId: item.id)),
        );
        return;
      case 'module':
        if (item.id <= 0 || item.featureKey.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ModuleDetailScreen(
              spec: _specFor(item),
              itemId: item.id,
            ),
          ),
        );
        return;
    }
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'shop':
        return 'دووکان';
      case 'market':
        return 'بازاڕ';
      case 'module':
        return 'خزمەتگوزاری';
      default:
        return 'دڵخواز';
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'shop':
        return Icons.storefront_rounded;
      case 'market':
        return Icons.shopping_bag_rounded;
      case 'module':
        return Icons.grid_view_rounded;
      default:
        return Icons.favorite_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دڵخوازەکان', style: TextStyle(fontWeight: FontWeight.w900)),
          surfaceTintColor: Colors.transparent,
        ),
        body: ValueListenableBuilder<List<ContentReference>>(
          valueListenable: FavoritesService.contentNotifier,
          builder: (context, items, _) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border_rounded, size: 68, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 14),
                      const Text('هێشتا هیچ شتێکت نەخستووەتە دڵخوازەکان', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('دووکان، ئایتمی بازاڕ و خزمەتگوزاری دەتوانیت Save بکەیت.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11.5)),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _hydrateLegacyShopFavorites,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final image = NizikEndpoints.normalizeUrl(item.imageUrl);
                  return Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(item),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 72,
                                height: 72,
                                color: theme.colorScheme.primaryContainer,
                                alignment: Alignment.center,
                                child: image.isEmpty
                                    ? Text(item.emoji.isEmpty ? '❤' : item.emoji, style: const TextStyle(fontSize: 27))
                                    : CachedNetworkImage(
                                        imageUrl: image,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Text(item.emoji.isEmpty ? '❤' : item.emoji, style: const TextStyle(fontSize: 27)),
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
                                      Icon(_kindIcon(item.kind), size: 14, color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(_kindLabel(item.kind), style: TextStyle(color: theme.colorScheme.primary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                                  if (item.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'لابردن لە دڵخواز',
                              onPressed: () => FavoritesService.removeContent(item.key),
                              icon: const Icon(Icons.favorite_rounded, color: Color(0xFFE53935)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

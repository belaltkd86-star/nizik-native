import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_reference.dart';
import '../models/market_item.dart';
import '../models/module_item.dart';
import '../models/module_spec.dart';
import '../models/shop.dart';

class FavoritesService {
  FavoritesService._();

  static const String _shopKey = 'favorite_shop_slugs';
  static const String _contentKey = 'nizik_favorite_content_v2';

  /// Compatibility notifier used by the existing shop cards.
  static final ValueNotifier<Set<String>> notifier =
      ValueNotifier<Set<String>>(<String>{});

  /// Unified favorites for shops, market items and service modules.
  static final ValueNotifier<List<ContentReference>> contentNotifier =
      ValueNotifier<List<ContentReference>>(<ContentReference>[]);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedShops = prefs.getStringList(_shopKey) ?? const <String>[];
    notifier.value = savedShops.toSet();

    final raw = prefs.getString(_contentKey);
    final refs = <ContentReference>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded.whereType<Map>()) {
            final ref = ContentReference.fromJson(
              Map<String, dynamic>.from(entry),
            );
            if (ref.kind.isNotEmpty && ref.key.isNotEmpty) refs.add(ref);
          }
        }
      } catch (_) {
        // Corrupt local favorites must never block startup.
      }
    }

    // Keep legacy shop favorites visible in the unified store even when older
    // app versions saved only the slug. Titles are hydrated by FavoritesScreen.
    for (final slug in notifier.value) {
      final key = ContentReference.shopKey(slug);
      if (!refs.any((item) => item.key == key)) {
        refs.add(
          ContentReference(
            kind: 'shop',
            key: key,
            slug: slug,
            title: slug,
            savedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      }
    }

    refs.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    contentNotifier.value = List<ContentReference>.unmodifiable(refs);
  }

  static bool isFavorite(String slug) => notifier.value.contains(slug);

  static bool isMarketFavorite(int id) =>
      contentNotifier.value.any((item) => item.key == ContentReference.marketKey(id));

  static bool isModuleFavorite(String featureKey, int id) =>
      contentNotifier.value.any(
        (item) => item.key == ContentReference.moduleKey(featureKey, id),
      );

  /// Legacy shop toggle retained for all existing callers.
  static Future<void> toggle(String slug) async {
    final clean = slug.trim();
    if (clean.isEmpty) return;

    final next = Set<String>.from(notifier.value);
    if (next.contains(clean)) {
      next.remove(clean);
      await _removeContent(ContentReference.shopKey(clean));
    } else {
      next.add(clean);
      await _upsertContent(
        ContentReference(
          kind: 'shop',
          key: ContentReference.shopKey(clean),
          slug: clean,
          title: clean,
          savedAt: DateTime.now(),
        ),
      );
    }

    notifier.value = next;
    await _persistShopSlugs(next);
  }

  static Future<void> toggleShop(Shop shop) async {
    final next = Set<String>.from(notifier.value);
    final isRemoving = next.contains(shop.slug);

    if (isRemoving) {
      next.remove(shop.slug);
      await _removeContent(ContentReference.shopKey(shop.slug));
    } else {
      next.add(shop.slug);
      await _upsertContent(
        ContentReference(
          kind: 'shop',
          key: ContentReference.shopKey(shop.slug),
          id: shop.id,
          slug: shop.slug,
          title: shop.name,
          subtitle: shop.locationLabel,
          imageUrl: shop.logoUrl ?? '',
          emoji: shop.typeIcon,
          savedAt: DateTime.now(),
        ),
      );
    }

    notifier.value = next;
    await _persistShopSlugs(next);
  }

  static Future<void> toggleMarket(MarketItem item) async {
    final key = ContentReference.marketKey(item.id);
    if (isMarketFavorite(item.id)) {
      await _removeContent(key);
      return;
    }

    await _upsertContent(
      ContentReference(
        kind: 'market',
        key: key,
        id: item.id,
        title: item.title,
        subtitle: item.locationLabel,
        imageUrl: item.imageUrl ?? '',
        emoji: '🛍️',
        savedAt: DateTime.now(),
      ),
    );
  }

  static Future<void> toggleMarketDetail(MarketItemDetail item) async {
    final key = ContentReference.marketKey(item.id);
    if (isMarketFavorite(item.id)) {
      await _removeContent(key);
      return;
    }

    await _upsertContent(
      ContentReference(
        kind: 'market',
        key: key,
        id: item.id,
        title: item.title,
        subtitle: item.locationLabel,
        imageUrl: item.images.isEmpty ? '' : item.images.first,
        emoji: '🛍️',
        savedAt: DateTime.now(),
      ),
    );
  }

  static Future<void> toggleModule(
    ModuleSpec spec,
    ModuleItem item,
  ) async {
    final key = ContentReference.moduleKey(spec.key, item.id);
    if (isModuleFavorite(spec.key, item.id)) {
      await _removeContent(key);
      return;
    }

    await _upsertContent(
      ContentReference(
        kind: 'module',
        key: key,
        id: item.id,
        featureKey: spec.key,
        title: item.title,
        subtitle: item.locationLabel,
        imageUrl: item.imageUrls.isEmpty ? '' : item.imageUrls.first,
        emoji: spec.emoji,
        savedAt: DateTime.now(),
      ),
    );
  }

  static Future<void> remove(String slug) async {
    if (!notifier.value.contains(slug)) return;
    final next = Set<String>.from(notifier.value)..remove(slug);
    notifier.value = next;
    await _persistShopSlugs(next);
    await _removeContent(ContentReference.shopKey(slug));
  }

  static Future<void> removeContent(String key) async {
    final target = contentNotifier.value.where((item) => item.key == key).toList();
    for (final item in target) {
      if (item.kind == 'shop' && item.slug.isNotEmpty) {
        final next = Set<String>.from(notifier.value)..remove(item.slug);
        notifier.value = next;
        await _persistShopSlugs(next);
      }
    }
    await _removeContent(key);
  }

  static Future<void> hydrateShop(Shop shop) async {
    if (!notifier.value.contains(shop.slug)) return;
    await _upsertContent(
      ContentReference(
        kind: 'shop',
        key: ContentReference.shopKey(shop.slug),
        id: shop.id,
        slug: shop.slug,
        title: shop.name,
        subtitle: shop.locationLabel,
        imageUrl: shop.logoUrl ?? '',
        emoji: shop.typeIcon,
        savedAt: _existingDate(ContentReference.shopKey(shop.slug)),
      ),
    );
  }

  static DateTime _existingDate(String key) {
    for (final item in contentNotifier.value) {
      if (item.key == key) return item.savedAt;
    }
    return DateTime.now();
  }

  static Future<void> _persistShopSlugs(Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_shopKey, values.toList()..sort());
  }

  static Future<void> _upsertContent(ContentReference ref) async {
    final next = List<ContentReference>.from(contentNotifier.value)
      ..removeWhere((item) => item.key == ref.key)
      ..insert(0, ref);
    contentNotifier.value = List<ContentReference>.unmodifiable(next);
    await _persistContent();
  }

  static Future<void> _removeContent(String key) async {
    final next = List<ContentReference>.from(contentNotifier.value)
      ..removeWhere((item) => item.key == key);
    contentNotifier.value = List<ContentReference>.unmodifiable(next);
    await _persistContent();
  }

  static Future<void> _persistContent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contentKey,
      jsonEncode(contentNotifier.value.map((item) => item.toJson()).toList()),
    );
  }
}

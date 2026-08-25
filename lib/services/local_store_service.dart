import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop.dart';

class LocalStoreService {
  LocalStoreService._();

  static final LocalStoreService instance = LocalStoreService._();

  static const _favoritesKey = 'nizik_favorites_v1';
  static const _recentKey = 'nizik_recent_v1';

  Future<List<Shop>> getFavorites() async {
    return _readShopList(_favoritesKey);
  }

  Future<Set<int>> getFavoriteIds() async {
    final shops = await getFavorites();
    return shops.where((e) => e.id > 0).map((e) => e.id).toSet();
  }

  Future<bool> isFavorite(Shop shop) async {
    final shops = await getFavorites();
    return shops.any((item) => _sameShop(item, shop));
  }

  Future<bool> toggleFavorite(Shop shop) async {
    final shops = await getFavorites();
    final index = shops.indexWhere((item) => _sameShop(item, shop));

    bool nowFavorite;

    if (index >= 0) {
      shops.removeAt(index);
      nowFavorite = false;
    } else {
      shops.insert(0, shop);
      nowFavorite = true;
    }

    await _writeShopList(_favoritesKey, shops);
    return nowFavorite;
  }

  Future<List<Shop>> getRecent() async {
    return _readShopList(_recentKey);
  }

  Future<void> addRecent(Shop shop) async {
    final shops = await getRecent();

    shops.removeWhere((item) => _sameShop(item, shop));
    shops.insert(0, shop);

    if (shops.length > 12) {
      shops.removeRange(12, shops.length);
    }

    await _writeShopList(_recentKey, shops);
  }

  Future<void> cacheJson(
    String key,
    Map<String, dynamic> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cache_$key',
      jsonEncode({
        'saved_at': DateTime.now().millisecondsSinceEpoch,
        'data': value,
      }),
    );
  }

  Future<Map<String, dynamic>?> readCachedJson(
    String key,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_$key');

    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map) return null;

      final container = Map<String, dynamic>.from(decoded);
      final data = container['data'];

      if (data is! Map) return null;

      return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<Shop>> _readShopList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map(
            (item) => Shop.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeShopList(
    String key,
    List<Shop> shops,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      key,
      jsonEncode(
        shops.map((shop) => shop.toJson()).toList(),
      ),
    );
  }

  bool _sameShop(Shop a, Shop b) {
    if (a.id > 0 && b.id > 0) {
      return a.id == b.id;
    }

    return a.slug.isNotEmpty &&
        b.slug.isNotEmpty &&
        a.slug == b.slug;
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop.dart';
import 'location_preference_service.dart';
import 'shop_service.dart';

class CachedShopCoordinate {
  final double lat;
  final double lng;
  final DateTime updatedAt;

  const CachedShopCoordinate({
    required this.lat,
    required this.lng,
    required this.updatedAt,
  });

  factory CachedShopCoordinate.fromJson(Map<String, dynamic> json) {
    return CachedShopCoordinate(
      lat: double.tryParse((json['lat'] ?? '').toString()) ?? 0,
      lng: double.tryParse((json['lng'] ?? '').toString()) ?? 0,
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'updated_at': updatedAt.toIso8601String(),
      };
}

class ShopDistanceService {
  ShopDistanceService._();

  static final ShopDistanceService instance = ShopDistanceService._();
  static const String _cacheKey = 'nizik_shop_coordinate_cache_v1';
  static const Duration _cacheLifetime = Duration(days: 30);

  final ValueNotifier<Map<String, double>> distances =
      ValueNotifier<Map<String, double>>(<String, double>{});

  final Map<String, CachedShopCoordinate> _coordinates =
      <String, CachedShopCoordinate>{};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            _coordinates[entry.key.toString()] =
                CachedShopCoordinate.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      }
    } catch (_) {
      // A bad local cache should be ignored.
    }
  }

  double? distanceFor(String slug) => distances.value[slug];

  String? distanceTextFor(String slug) {
    final meters = distanceFor(slug);
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  Future<void> resolveForShops(
    List<Shop> shops,
    NizikLocationPreference location, {
    int maxNetworkResolves = 40,
  }) async {
    await init();
    if (!location.hasCoordinates) {
      distances.value = <String, double>{};
      return;
    }

    final userLat = location.latitude!;
    final userLng = location.longitude!;
    final next = Map<String, double>.from(distances.value);
    final missing = <Shop>[];
    final now = DateTime.now();

    for (final shop in shops) {
      final cached = _coordinates[shop.slug];
      if (cached != null &&
          now.difference(cached.updatedAt) <= _cacheLifetime &&
          cached.lat.abs() <= 90 &&
          cached.lng.abs() <= 180) {
        next[shop.slug] = Geolocator.distanceBetween(
          userLat,
          userLng,
          cached.lat,
          cached.lng,
        );
      } else if (shop.googleMapsUrl?.trim().isNotEmpty == true) {
        missing.add(shop);
      }
    }

    distances.value = Map<String, double>.unmodifiable(next);
    if (missing.isEmpty || maxNetworkResolves <= 0) return;

    // Resolve coordinates in small batches so the public API is not flooded.
    final queue = missing.take(maxNetworkResolves).toList(growable: false);
    const batchSize = 4;
    for (var start = 0; start < queue.length; start += batchSize) {
      final batch = queue.skip(start).take(batchSize).toList();
      await Future.wait(
        batch.map((shop) async {
          try {
            final coords = await ShopService.resolveCoordinates(shop.slug);
            _coordinates[shop.slug] = CachedShopCoordinate(
              lat: coords.lat,
              lng: coords.lng,
              updatedAt: DateTime.now(),
            );
            next[shop.slug] = Geolocator.distanceBetween(
              userLat,
              userLng,
              coords.lat,
              coords.lng,
            );
          } catch (_) {
            // Shops without a resolvable maps URL simply have no distance.
          }
        }),
      );
      distances.value = Map<String, double>.unmodifiable(
        Map<String, double>.from(next),
      );
    }

    await _persistCache();
  }

  List<Shop> sortNearest(List<Shop> shops) {
    final values = distances.value;
    final sorted = List<Shop>.from(shops);
    sorted.sort((a, b) {
      final da = values[a.slug];
      final db = values[b.slug];
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return sorted;
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(
        _coordinates.map(
          (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/shop.dart';
import 'local_store_service.dart';

class ShopLocationService {
  ShopLocationService._();

  static final ShopLocationService instance =
      ShopLocationService._();

  final LocalStoreService _store = LocalStoreService.instance;
  final Map<String, LatLng> _memoryCache = {};

  Future<LatLng?> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied &&
        requestPermission) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final last =
          await Geolocator.getLastKnownPosition();

      if (last != null) {
        return LatLng(
          last.latitude,
          last.longitude,
        );
      }
    } catch (_) {
      // Ignore and request a fresh position below.
    }

    final position =
        await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return LatLng(
      position.latitude,
      position.longitude,
    );
  }

  Future<LatLng?> resolveShop(
    Shop shop,
  ) async {
    final slug = shop.slug.trim();

    if (slug.isEmpty) return null;

    final memory = _memoryCache[slug];

    if (memory != null) {
      return memory;
    }

    final cacheKey =
        'coords_${Uri.encodeComponent(slug)}';
    final cached =
        await _store.readCachedJson(cacheKey);

    if (cached != null) {
      final lat =
          double.tryParse('${cached['lat'] ?? ''}');
      final lng =
          double.tryParse('${cached['lng'] ?? ''}');

      if (_valid(lat, lng)) {
        final point = LatLng(lat!, lng!);
        _memoryCache[slug] = point;
        return point;
      }
    }

    try {
      final uri = Uri.parse(
        'https://my-pro.click/public/location.php',
      ).replace(
        queryParameters: {
          'action': 'coords',
          'shop': slug,
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final data =
          Map<String, dynamic>.from(decoded);

      if (data['success'] != true) {
        return null;
      }

      final lat =
          double.tryParse('${data['lat'] ?? ''}');
      final lng =
          double.tryParse('${data['lng'] ?? ''}');

      if (!_valid(lat, lng)) {
        return null;
      }

      final point = LatLng(lat!, lng!);
      _memoryCache[slug] = point;

      await _store.cacheJson(
        cacheKey,
        {
          'lat': lat,
          'lng': lng,
        },
      );

      return point;
    } catch (_) {
      return null;
    }
  }

  double distanceMeters({
    required LatLng from,
    required LatLng to,
  }) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  bool _valid(
    double? lat,
    double? lng,
  ) {
    if (lat == null || lng == null) {
      return false;
    }

    if (!lat.isFinite || !lng.isFinite) {
      return false;
    }

    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }
}

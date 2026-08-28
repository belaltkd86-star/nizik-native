import 'package:geolocator/geolocator.dart';

import '../models/shop.dart';
import 'shop_service.dart';

class AutomaticAreaResult {
  const AutomaticAreaResult({
    required this.position,
    this.city,
    this.distanceMeters,
  });

  final Position position;
  final ShopCity? city;
  final double? distanceMeters;
}

class AreaDetectionService {
  AreaDetectionService._();

  static Future<AutomaticAreaResult> resolveFromPosition({
    required Position position,
    required ShopMetadata metadata,
  }) async {
    try {
      final shops = await ShopService.fetchShops();
      if (shops.isEmpty) {
        return AutomaticAreaResult(position: position);
      }

      Shop? nearestShop;
      double? nearestDistance;

      final unresolved = <Shop>[];

      for (final shop in shops) {
        if (shop.cityId == null) continue;

        final direct = _extractLatLng(shop.googleMapsUrl);
        if (direct == null) {
          if (shop.googleMapsUrl != null &&
              shop.googleMapsUrl!.trim().isNotEmpty) {
            unresolved.add(shop);
          }
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          direct.$1,
          direct.$2,
        );

        if (nearestDistance == null || distance < nearestDistance) {
          nearestDistance = distance;
          nearestShop = shop;
        }
      }

      // Resolve only a bounded number of short Google Maps links. This keeps
      // the first-run setup quick while still allowing automatic city matching
      // for shops that do not store raw coordinates in the URL.
      final candidates = unresolved.take(24).toList();
      const batchSize = 6;

      for (var i = 0; i < candidates.length; i += batchSize) {
        final end = (i + batchSize < candidates.length)
            ? i + batchSize
            : candidates.length;
        final batch = candidates.sublist(i, end);

        final results = await Future.wait(
          batch.map((shop) async {
            try {
              final coords = await ShopService.resolveCoordinates(shop.slug);
              final distance = Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                coords.lat,
                coords.lng,
              );
              return (shop: shop, distance: distance);
            } catch (_) {
              return null;
            }
          }),
        );

        for (final result in results) {
          if (result == null) continue;
          if (nearestDistance == null || result.distance < nearestDistance) {
            nearestDistance = result.distance;
            nearestShop = result.shop;
          }
        }
      }

      final cityId = nearestShop?.cityId;
      if (cityId == null) {
        return AutomaticAreaResult(
          position: position,
          distanceMeters: nearestDistance,
        );
      }

      ShopCity? city;
      for (final item in metadata.cities) {
        if (item.id == cityId) {
          city = item;
          break;
        }
      }

      if (city == null && nearestShop?.cityName?.trim().isNotEmpty == true) {
        city = ShopCity(id: cityId, name: nearestShop!.cityName!.trim());
      }

      return AutomaticAreaResult(
        position: position,
        city: city,
        distanceMeters: nearestDistance,
      );
    } catch (_) {
      return AutomaticAreaResult(position: position);
    }
  }

  static (double, double)? _extractLatLng(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;

    String decoded;
    try {
      decoded = Uri.decodeFull(rawUrl.trim());
    } catch (_) {
      decoded = rawUrl.trim();
    }

    final patterns = <RegExp>[
      RegExp(r'@(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)'),
      RegExp(r'!3d(-?\d{1,2}(?:\.\d+)?)[^!]*!4d(-?\d{1,3}(?:\.\d+)?)'),
      RegExp(
        r'(?:query|q|destination|ll|center)=(-?\d{1,2}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)',
        caseSensitive: false,
      ),
      RegExp(r'(-?\d{1,2}\.\d{4,}),\s*(-?\d{1,3}\.\d{4,})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(decoded);
      if (match == null) continue;

      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat == null || lng == null) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      return (lat, lng);
    }

    return null;
  }
}

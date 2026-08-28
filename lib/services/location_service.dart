import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<LocationPermission> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception(
        'Location Services ـی ئامێرەکەت داخراوە. تکایە چالاکی بکە.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'ڕێگەپێدانی شوێن نەدرا. تکایە ڕێگە بە نزیک بدە.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw Exception(
        'ڕێگەپێدانی شوێن داخراوە. لە Settings ـی ئامێرەکەت چالاکی بکە.',
      );
    }

    return permission;
  }

  // Lightweight foreground lookup used on the Home screen.
  // It may ask for permission once, but it never opens Settings by itself.
  // This keeps automatic location helpful without trapping the user in a
  // settings screen when GPS or permission is unavailable.
  static Future<Position?> tryGetCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      );

      return await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<Position> getCurrentPosition() async {
    await requestPermission();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    );

    return Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
  }

  // Kept for compatibility with the current Home and Map screens.
  static Future<Position> getCurrentLocation() async {
    return getCurrentPosition();
  }

  // Foreground live GPS stream. A new position is emitted after
  // roughly 3 metres of movement, so no manual refresh is needed.
  static Stream<Position> watchPosition() async* {
    await requestPermission();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    yield* Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
  }
}

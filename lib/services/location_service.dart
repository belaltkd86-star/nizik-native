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
      throw Exception(
        'ڕێگەپێدانی شوێن بە هەمیشەیی ڕەتکراوەتەوە. لە دوگمەی Settings چالاکی بکە.',
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

  // Foreground live GPS stream. High accuracy is reserved for the active
  // map/navigation screen. Other screens can use balanced accuracy to save battery.
  static Stream<Position> watchPosition({bool highAccuracy = true}) async* {
    await requestPermission();

    final locationSettings = LocationSettings(
      accuracy: highAccuracy ? LocationAccuracy.bestForNavigation : LocationAccuracy.medium,
      distanceFilter: highAccuracy ? 3 : 15,
    );

    yield* Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
  }
}

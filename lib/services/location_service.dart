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

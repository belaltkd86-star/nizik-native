import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<LocationPermission> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception(
        'Location Services ـی ئامێرەکە داخراوە. تکایە چالاکی بکە.',
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
        'ڕێگەپێدانی شوێن بە هەمیشەیی داخراوە. لە Settings چالاکی بکە.',
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

  // بۆ compatibility لەگەڵ screen ـە کۆنەکان
  static Future<Position> getCurrentLocation() async {
    return getCurrentPosition();
  }
}
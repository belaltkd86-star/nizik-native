import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop.dart';

class NizikLocationPreference {
  const NizikLocationPreference({
    required this.mode,
    this.cityId,
    this.cityName,
    this.regionId,
    this.regionName,
    this.latitude,
    this.longitude,
  });

  final String mode; // automatic | manual | none
  final int? cityId;
  final String? cityName;
  final int? regionId;
  final String? regionName;
  final double? latitude;
  final double? longitude;

  bool get isAutomatic => mode == 'automatic';
  bool get isManual => mode == 'manual';
  bool get hasArea => cityId != null || regionId != null;
  bool get hasCoordinates => latitude != null && longitude != null;

  String get label {
    final parts = <String>[
      if (cityName != null && cityName!.trim().isNotEmpty) cityName!.trim(),
      if (regionName != null && regionName!.trim().isNotEmpty)
        regionName!.trim(),
    ];

    if (parts.isNotEmpty) return parts.join(' - ');
    if (isAutomatic && hasCoordinates) return 'شوێنی ئێستا';
    return 'شوێن دیاری نەکراوە';
  }

  NizikLocationPreference copyWith({
    String? mode,
    int? cityId,
    String? cityName,
    int? regionId,
    String? regionName,
    double? latitude,
    double? longitude,
    bool clearRegion = false,
  }) {
    return NizikLocationPreference(
      mode: mode ?? this.mode,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      regionId: clearRegion ? null : (regionId ?? this.regionId),
      regionName: clearRegion ? null : (regionName ?? this.regionName),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class LocationPreferenceService {
  LocationPreferenceService._();

  static final LocationPreferenceService instance =
      LocationPreferenceService._();

  static const String _setupDoneKey = 'nizik_location_setup_done_v1';
  static const String _modeKey = 'nizik_location_mode_v1';
  static const String _cityIdKey = 'nizik_location_city_id_v1';
  static const String _cityNameKey = 'nizik_location_city_name_v1';
  static const String _regionIdKey = 'nizik_location_region_id_v1';
  static const String _regionNameKey = 'nizik_location_region_name_v1';
  static const String _latKey = 'nizik_location_lat_v1';
  static const String _lngKey = 'nizik_location_lng_v1';

  final ValueNotifier<NizikLocationPreference> preference =
      ValueNotifier<NizikLocationPreference>(
    const NizikLocationPreference(mode: 'none'),
  );

  bool _setupDone = false;

  bool get setupDone => _setupDone;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _setupDone = prefs.getBool(_setupDoneKey) ?? false;

    preference.value = NizikLocationPreference(
      mode: prefs.getString(_modeKey) ?? 'none',
      cityId: prefs.getInt(_cityIdKey),
      cityName: prefs.getString(_cityNameKey),
      regionId: prefs.getInt(_regionIdKey),
      regionName: prefs.getString(_regionNameKey),
      latitude: prefs.getDouble(_latKey),
      longitude: prefs.getDouble(_lngKey),
    );
  }

  Future<void> saveAutomatic({
    required double latitude,
    required double longitude,
    ShopCity? city,
  }) async {
    final next = NizikLocationPreference(
      mode: 'automatic',
      cityId: city?.id,
      cityName: city?.name,
      regionId: null,
      regionName: null,
      latitude: latitude,
      longitude: longitude,
    );

    await _persist(next);
  }

  Future<void> saveManual({
    required ShopCity city,
    ShopRegion? region,
  }) async {
    final next = NizikLocationPreference(
      mode: 'manual',
      cityId: city.id,
      cityName: city.name,
      regionId: region?.id,
      regionName: region?.name,
      latitude: null,
      longitude: null,
    );

    await _persist(next);
  }

  Future<void> clearArea() async {
    await _persist(const NizikLocationPreference(mode: 'none'));
  }

  Future<void> markSetupDone() async {
    _setupDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDoneKey, true);
  }

  Future<void> resetSetup() async {
    _setupDone = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDoneKey, false);
  }

  Future<void> _persist(NizikLocationPreference value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_modeKey, value.mode);

    if (value.cityId == null) {
      await prefs.remove(_cityIdKey);
    } else {
      await prefs.setInt(_cityIdKey, value.cityId!);
    }

    if (value.cityName == null || value.cityName!.trim().isEmpty) {
      await prefs.remove(_cityNameKey);
    } else {
      await prefs.setString(_cityNameKey, value.cityName!.trim());
    }

    if (value.regionId == null) {
      await prefs.remove(_regionIdKey);
    } else {
      await prefs.setInt(_regionIdKey, value.regionId!);
    }

    if (value.regionName == null || value.regionName!.trim().isEmpty) {
      await prefs.remove(_regionNameKey);
    } else {
      await prefs.setString(_regionNameKey, value.regionName!.trim());
    }

    if (value.latitude == null) {
      await prefs.remove(_latKey);
    } else {
      await prefs.setDouble(_latKey, value.latitude!);
    }

    if (value.longitude == null) {
      await prefs.remove(_lngKey);
    } else {
      await prefs.setDouble(_lngKey, value.longitude!);
    }

    preference.value = value;
  }
}

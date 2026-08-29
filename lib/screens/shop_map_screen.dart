import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';
import '../services/location_preference_service.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/shop_service.dart';
import '../widgets/report_sheet.dart';
import '../widgets/voice_search_sheet.dart';
import 'settings_screen.dart';
import 'shop_detail_screen.dart';

const _mapGreen = Color(0xFF059669);
const _mapDarkGreen = Color(0xFF047857);
const _mapInk = Color(0xFF0F172A);
const _mapMuted = Color(0xFF64748B);

class ShopMapScreen extends StatefulWidget {
  final Shop? focusShop;
  final bool autoLocate;

  const ShopMapScreen({
    super.key,
    this.focusShop,
    this.autoLocate = true,
  });

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

enum _MapBaseLayer { street, satellite }
enum _RouteChoice { fastest, shortest }

class _ShopMapScreenState extends State<ShopMapScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  static const LatLng _defaultCenter = LatLng(35.5613, 45.4309);
  static const _cameraKey = 'nizik_map_camera_v10';
  static const _coordCacheKey = 'nizik_map_coords_v10';
  static const _privacyKey = 'nizik_map_privacy_v10';
  static const _approxKey = 'nizik_map_approx_v10';
  static const _shopsCacheKey = 'nizik_map_shops_cache_v10';
  static const _trafficTemplate = '';

  final MapController _mapController = MapController();
  final TextEditingController _search = TextEditingController();
  final LocationPreferenceService _locationPrefs = LocationPreferenceService.instance;
  final RouteService _routeService = RouteService();
  final Distance _distance = const Distance();

  StreamSubscription<Position>? _locationSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _moveDebounce;
  Timer? _searchDebounce;
  Timer? _rerouteCooldown;

  List<_MappedShop> _mapped = <_MappedShop>[];
  Map<String, LatLng> _coordinateCache = <String, LatLng>{};
  List<ShopBusinessType> _businessTypes = <ShopBusinessType>[];

  Shop? _selectedShop;
  LatLng? _selectedPoint;
  LatLng? _myLocation;
  double _gpsAccuracy = 0;
  double _heading = 0;

  bool _loading = true;
  bool _gettingLocation = false;
  bool _mapReady = false;
  bool _traffic = false;
  bool _privacyMode = false;
  bool _approximateLocation = false;
  bool _followUser = false;
  bool _autoReroute = true;
  bool _routing = false;
  bool _showAutocomplete = false;
  bool _searchCollapsed = false;
  bool _destinationReached = false;
  bool _lifecycleActive = true;

  _MapBaseLayer _baseLayer = _MapBaseLayer.street;
  String _query = '';
  Set<String> _remoteShopSlugs = <String>{};
  String _selectedType = '';
  String? _error;
  String? _locationError;

  LatLngBounds? _lazyBounds;
  LatLng? _aroundPin;
  double _aroundRadiusMeters = 2500;

  List<NizikRouteAlternative> _routeAlternatives = const <NizikRouteAlternative>[];
  int _routeIndex = 0;
  NizikRouteMode _routeMode = NizikRouteMode.driving;
  _RouteChoice _routeChoice = _RouteChoice.fastest;
  double _routeProgress = 0;
  int _offRouteSamples = 0;

  int _resolvedCount = 0;
  int _shopCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedShop = widget.focusShop;
    _loadPrefs();
    _listenCompass();
    _loadMapData();
    if (widget.focusShop == null) _locationPrefs.preference.addListener(_onAreaChanged);
    if (widget.autoLocate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startLiveLocation(silent: true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant ShopMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autoLocate && widget.autoLocate) _startLiveLocation(silent: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _lifecycleActive = active;
    if (!active) {
      _stopLiveLocation();
    } else if (widget.autoLocate && !_privacyMode) {
      _startLiveLocation(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.focusShop == null) _locationPrefs.preference.removeListener(_onAreaChanged);
    _locationSub?.cancel();
    _compassSub?.cancel();
    _moveDebounce?.cancel();
    _searchDebounce?.cancel();
    _rerouteCooldown?.cancel();
    _search.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_coordCacheKey);
    final cache = <String, LatLng>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is List && value.length >= 2) {
              final lat = double.tryParse(value[0].toString());
              final lng = double.tryParse(value[1].toString());
              if (lat != null && lng != null && _validCoordinates(lat, lng)) {
                cache[entry.key.toString()] = LatLng(lat, lng);
              }
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _coordinateCache = cache;
      _privacyMode = prefs.getBool(_privacyKey) ?? false;
      _approximateLocation = prefs.getBool(_approxKey) ?? false;
    });
  }

  Future<void> _saveCoordinateCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, List<double>>{};
    for (final entry in _coordinateCache.entries) {
      data[entry.key] = [entry.value.latitude, entry.value.longitude];
    }
    await prefs.setString(_coordCacheKey, jsonEncode(data));
  }

  Future<void> _saveCamera() async {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cameraKey,
      jsonEncode({
        'lat': camera.center.latitude,
        'lng': camera.center.longitude,
        'zoom': camera.zoom,
      }),
    );
  }

  Future<void> _restoreCamera() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cameraKey);
    if (raw == null || !_mapReady) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final lat = double.tryParse(decoded['lat'].toString());
      final lng = double.tryParse(decoded['lng'].toString());
      final zoom = double.tryParse(decoded['zoom'].toString());
      if (lat != null && lng != null && zoom != null && _validCoordinates(lat, lng)) {
        _mapController.move(LatLng(lat, lng), zoom.clamp(3, 19));
      }
    } catch (_) {}
  }

  void _onAreaChanged() => _loadMapData();

  void _listenCompass() {
    final events = FlutterCompass.events;
    if (events == null) return;
    _compassSub = events.listen((event) {
      final value = event.heading;
      if (value == null || !mounted) return;
      setState(() => _heading = value < 0 ? value + 360 : value);
    });
  }

  Future<void> _saveShopCache(List<Shop> shops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(<String, dynamic>{
        'saved_at': DateTime.now().toIso8601String(),
        'shops': shops.map((shop) => shop.toJson()).toList(),
      });
      await prefs.setString(_shopsCacheKey, payload);
    } catch (_) {}
  }

  Future<List<Shop>> _loadShopCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_shopsCacheKey);
      if (raw == null || raw.isEmpty) return const <Shop>[];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <Shop>[];
      final items = decoded['shops'];
      if (items is! List) return const <Shop>[];
      return items
          .whereType<Map>()
          .map((item) => Shop.fromJson(Map<String, dynamic>.from(item)))
          .where((shop) => shop.slug.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const <Shop>[];
    }
  }

  List<ShopBusinessType> _deriveBusinessTypes(List<Shop> shops) {
    final counts = <String, int>{};
    final labels = <String, String>{};
    final icons = <String, String>{};
    for (final shop in shops) {
      final key = (shop.businessType ?? '').trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      labels[key] = shop.typeLabel;
      icons[key] = shop.typeIcon;
    }
    return counts.entries
        .map((entry) => ShopBusinessType(
              key: entry.key,
              name: labels[entry.key] ?? entry.key,
              icon: icons[entry.key] ?? '🏪',
              shopCount: entry.value,
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<_MappedShop> _mapCachedShops(List<Shop> shops) {
    final mapped = <_MappedShop>[];
    for (final shop in shops) {
      final point = _extractLatLng(shop.googleMapsUrl) ?? _coordinateCache[shop.slug];
      if (point != null && !mapped.any((item) => item.shop.slug == shop.slug)) {
        mapped.add(_MappedShop(shop: shop, point: point));
      }
    }
    return mapped;
  }

  Future<void> _loadMapData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _resolvedCount = 0;
      _clearRoute();
    });

    try {
      final location = _locationPrefs.preference.value;
      final results = await Future.wait([
        ShopService.fetchShops(
          cityId: widget.focusShop == null ? location.cityId : null,
          regionId: widget.focusShop == null ? location.regionId : null,
        ),
        ShopService.fetchMetadata(
          cityId: widget.focusShop == null ? location.cityId : null,
          regionId: widget.focusShop == null ? location.regionId : null,
          occupiedOnly: true,
        ),
      ]);
      final shops = results[0] as List<Shop>;
      final metadata = results[1] as ShopMetadata;
      unawaited(_saveShopCache(shops));
      _shopCount = shops.length;
      _businessTypes = metadata.businessTypes;

      final mapped = <_MappedShop>[];
      final unresolved = <Shop>[];

      for (final shop in shops) {
        final direct = _extractLatLng(shop.googleMapsUrl) ?? _coordinateCache[shop.slug];
        if (direct != null) {
          mapped.add(_MappedShop(shop: shop, point: direct));
        } else if ((shop.googleMapsUrl ?? '').trim().isNotEmpty) {
          unresolved.add(shop);
        }
      }

      if (widget.focusShop != null && !mapped.any((m) => m.shop.slug == widget.focusShop!.slug)) {
        final focused = await _resolveShopPoint(widget.focusShop!);
        if (focused != null) mapped.insert(0, focused);
      }

      if (mounted) setState(() { _mapped = List.of(mapped); _resolvedCount = mapped.length; });

      const batchSize = 7;
      for (var i = 0; i < unresolved.length; i += batchSize) {
        final end = math.min(i + batchSize, unresolved.length);
        final batch = unresolved.sublist(i, end);
        final resolved = await Future.wait(batch.map(_resolveShopPoint));
        for (final item in resolved) {
          if (item != null && !mapped.any((m) => m.shop.slug == item.shop.slug)) mapped.add(item);
        }
        if (!mounted) return;
        setState(() { _mapped = List.of(mapped); _resolvedCount = mapped.length; });
      }

      await _saveCoordinateCache();
      if (!mounted) return;
      setState(() {
        _mapped = mapped;
        _resolvedCount = mapped.length;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !_mapReady) return;
        final focus = widget.focusShop;
        if (focus != null) {
          final item = _mapped.where((m) => m.shop.slug == focus.slug).firstOrNull;
          if (item != null) {
            _selectShop(item, move: true);
            return;
          }
        }
        await _restoreCamera();
        _refreshLazyBounds();
      });
    } catch (e) {
      if (!mounted) return;
      final cachedShops = await _loadShopCache();
      if (!mounted) return;
      if (cachedShops.isNotEmpty) {
        final cachedMapped = _mapCachedShops(cachedShops);
        setState(() {
          _mapped = cachedMapped;
          _shopCount = cachedShops.length;
          _resolvedCount = cachedMapped.length;
          _businessTypes = _deriveBusinessTypes(cachedShops);
          _loading = false;
          _error = 'ئینتەرنێت یان سێرڤەر بەردەست نییە • داتای دوا جار نیشان دەدرێت';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mapReady) _refreshLazyBounds();
        });
      } else {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<_MappedShop?> _resolveShopPoint(Shop shop) async {
    final direct = _extractLatLng(shop.googleMapsUrl) ?? _coordinateCache[shop.slug];
    if (direct != null) return _MappedShop(shop: shop, point: direct);
    try {
      final coords = await ShopService.resolveCoordinates(shop.slug);
      if (!_validCoordinates(coords.lat, coords.lng)) return null;
      final point = LatLng(coords.lat, coords.lng);
      _coordinateCache[shop.slug] = point;
      return _MappedShop(shop: shop, point: point);
    } catch (_) {
      return null;
    }
  }

  LatLng? _extractLatLng(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final decoded = Uri.decodeFull(rawUrl.trim());
    final patterns = <RegExp>[
      RegExp(r'@(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)'),
      RegExp(r'!3d(-?\d{1,2}(?:\.\d+)?)[^!]*!4d(-?\d{1,3}(?:\.\d+)?)'),
      RegExp(r'(?:query|q|destination|ll|center)=(-?\d{1,2}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)', caseSensitive: false),
      RegExp(r'(-?\d{1,2}\.\d{4,}),\s*(-?\d{1,3}\.\d{4,})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(decoded);
      if (match == null) continue;
      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat != null && lng != null && _validCoordinates(lat, lng)) return LatLng(lat, lng);
    }
    return null;
  }

  static bool _validCoordinates(double lat, double lng) =>
      lat.isFinite && lng.isFinite && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  Future<void> _startLiveLocation({bool silent = false}) async {
    if (_privacyMode || !_lifecycleActive || _locationSub != null) return;
    setState(() => _gettingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      _applyPosition(position);
      _locationSub = LocationService.watchPosition(highAccuracy: true).listen(
        _applyPosition,
        onError: (Object error) {
          _locationSub?.cancel();
          _locationSub = null;
          if (mounted && !silent) setState(() => _locationError = 'GPS داتا وەستاندرا.');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _locationError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _stopLiveLocation() async {
    await _locationSub?.cancel();
    _locationSub = null;
  }

  void _applyPosition(Position position) {
    if (!mounted || _privacyMode) return;
    var lat = position.latitude;
    var lng = position.longitude;
    var accuracy = position.accuracy;
    if (_approximateLocation) {
      lat = (lat * 1000).round() / 1000;
      lng = (lng * 1000).round() / 1000;
      accuracy = math.max(accuracy, 120);
    }
    if (!_validCoordinates(lat, lng)) return;
    final point = LatLng(lat, lng);
    setState(() {
      _myLocation = point;
      _gpsAccuracy = accuracy.clamp(0, 5000).toDouble();
      _locationError = null;
    });

    if (_routePoints.isNotEmpty) _updateNavigation(point);
    if (_followUser && _mapReady) {
      _mapController.moveAndRotate(point, math.max(_mapController.camera.zoom, 16).toDouble(), _heading);
    }
  }

  Future<void> _goToMyLocation() async {
    if (_privacyMode) {
      _message('Location Privacy Mode چالاکە. یەکەم لە Layers/Privacy ناچالاکی بکە.');
      return;
    }
    if (_myLocation == null) await _startLiveLocation();
    if (_myLocation != null && _mapReady) _mapController.move(_myLocation!, 16);
  }

  void _selectShop(_MappedShop item, {bool move = true}) {
    setState(() {
      _selectedShop = item.shop;
      _selectedPoint = item.point;
      _showAutocomplete = false;
      _destinationReached = false;
    });
    if (move && _mapReady) _mapController.move(item.point, math.max(_mapController.camera.zoom, 15.5).toDouble());
  }

  void _clearSelection() {
    setState(() {
      _selectedShop = null;
      _selectedPoint = null;
      _clearRoute();
    });
  }

  List<LatLng> get _routePoints =>
      _routeAlternatives.isEmpty ? const <LatLng>[] : _routeAlternatives[_routeIndex.clamp(0, _routeAlternatives.length - 1).toInt()].points;

  NizikRouteAlternative? get _activeRoute =>
      _routeAlternatives.isEmpty ? null : _routeAlternatives[_routeIndex.clamp(0, _routeAlternatives.length - 1).toInt()];

  void _clearRoute() {
    _routeAlternatives = const <NizikRouteAlternative>[];
    _routeIndex = 0;
    _routeProgress = 0;
    _offRouteSamples = 0;
    _followUser = false;
    _destinationReached = false;
  }

  Future<void> _buildRoute({NizikRouteMode? mode, _RouteChoice? choice}) async {
    final target = _selectedPoint;
    if (target == null) {
      _message('یەکەم دووکانێک هەڵبژێرە.');
      return;
    }
    if (_myLocation == null) await _startLiveLocation();
    final start = _myLocation;
    if (start == null) return;
    if (_routing) return;

    final nextMode = mode ?? _routeMode;
    final nextChoice = choice ?? _routeChoice;
    setState(() {
      _routing = true;
      _routeMode = nextMode;
      _routeChoice = nextChoice;
    });
    try {
      var alternatives = await _routeService.getRoutes(start: start, end: target, mode: nextMode);
      alternatives = List<NizikRouteAlternative>.of(alternatives);
      if (nextChoice == _RouteChoice.shortest) {
        alternatives.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      } else {
        alternatives.sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
      }
      if (!mounted) return;
      setState(() {
        _routeAlternatives = alternatives;
        _routeIndex = 0;
        _routeProgress = 0;
        _offRouteSamples = 0;
        _destinationReached = false;
      });
      _fitRoute();
    } catch (_) {
      if (mounted) _message(nextMode == NizikRouteMode.walking ? 'ڕێگای پیادەڕۆ لە ئێستادا بەردەست نییە.' : 'ڕێگای ئۆتۆمبێل لە ئێستادا بەردەست نییە.');
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _fitRoute() {
    final route = _activeRoute;
    if (route == null || route.points.isEmpty || !_mapReady) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: route.points,
        padding: const EdgeInsets.fromLTRB(42, 120, 42, 260),
        maxZoom: 17,
        minZoom: 4,
      ),
    );
  }

  double _zoomForDistance(double meters) {
    if (meters < 800) return 15.5;
    if (meters < 1800) return 14.5;
    if (meters < 4500) return 13.5;
    if (meters < 12000) return 12.3;
    if (meters < 30000) return 10.8;
    if (meters < 80000) return 9.2;
    return 7.8;
  }

  void _updateNavigation(LatLng current) {
    final route = _activeRoute;
    if (route == null || route.points.isEmpty) return;

    var nearestMeters = double.infinity;
    var nearestIndex = 0;
    final step = math.max(1, route.points.length ~/ 250);
    for (var i = 0; i < route.points.length; i += step) {
      final d = _distance.as(LengthUnit.Meter, current, route.points[i]);
      if (d < nearestMeters) {
        nearestMeters = d;
        nearestIndex = i;
      }
    }
    final progress = route.points.length <= 1 ? 0.0 : nearestIndex / (route.points.length - 1);
    final destinationDistance = _distance.as(LengthUnit.Meter, current, route.points.last);

    if (nearestMeters > 100) {
      _offRouteSamples++;
    } else {
      _offRouteSamples = 0;
    }

    if (destinationDistance <= 35 && !_destinationReached) {
      _destinationReached = true;
      _followUser = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _message('گەیشتیتە مەبەست ✓');
      });
    }

    if (_offRouteSamples >= 3 && _autoReroute && !_routing && _rerouteCooldown == null) {
      _offRouteSamples = 0;
      _rerouteCooldown = Timer(const Duration(seconds: 12), () => _rerouteCooldown = null);
      unawaited(_buildRoute());
    }

    if (mounted) setState(() => _routeProgress = progress.clamp(0, 1).toDouble());
  }

  List<_MappedShop> get _routeNearbyShops {
    final route = _activeRoute;
    if (route == null) return const <_MappedShop>[];
    final sampled = <LatLng>[];
    final step = math.max(1, route.points.length ~/ 100);
    for (var i = 0; i < route.points.length; i += step) sampled.add(route.points[i]);
    return _mapped.where((shop) {
      var best = double.infinity;
      for (final p in sampled) {
        final d = _distance.as(LengthUnit.Meter, shop.point, p);
        if (d < best) best = d;
        if (best <= 450) break;
      }
      return best <= 450;
    }).toList();
  }

  void _showAlongRoute() {
    final all = _routeNearbyShops;
    if (all.isEmpty) {
      _message('دووکانی نزیک لەسەر ئەم ڕێگایە نەدۆزرایەوە.');
      return;
    }
    var filter = 'all';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          bool match(_MappedShop item) {
            if (filter == 'all') return true;
            final text = '${item.shop.name} ${item.shop.typeLabel} ${item.shop.businessType ?? ''}'.toLowerCase();
            const keys = <String, List<String>>{
              'fuel': ['fuel', 'petrol', 'gas', 'بنزین', 'نەوت'],
              'pharmacy': ['pharmacy', 'دەرمان', 'دەرمانخانە'],
              'food': ['restaurant', 'cafe', 'food', 'خواردن', 'چێشتخانە', 'کافێ'],
              'emergency': ['emergency', 'hospital', 'clinic', 'فریاکەوتن', 'نەخۆشخانە'],
            };
            return (keys[filter] ?? const <String>[]).any(text.contains);
          }
          final shown = all.where(match).toList();
          return Directionality(
            textDirection: TextDirection.rtl,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: .72,
              minChildSize: .4,
              maxChildSize: .92,
              builder: (_, controller) => Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                  children: [
                    Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(99)))),
                    const SizedBox(height: 14),
                    const Text('شوێنەکان لەسەر ڕێگا', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      _routeFilter('all', 'هەموو', filter, (v) => setSheetState(() => filter = v)),
                      _routeFilter('fuel', '⛽ سووتەمەنی', filter, (v) => setSheetState(() => filter = v)),
                      _routeFilter('pharmacy', '💊 دەرمانخانە', filter, (v) => setSheetState(() => filter = v)),
                      _routeFilter('food', '🍽️ خواردن', filter, (v) => setSheetState(() => filter = v)),
                      _routeFilter('emergency', '🚑 فریاکەوتن', filter, (v) => setSheetState(() => filter = v)),
                    ]),
                    const SizedBox(height: 12),
                    if (shown.isEmpty)
                      const Padding(padding: EdgeInsets.all(20), child: Text('هیچ ئەنجامێک نییە.', textAlign: TextAlign.center))
                    else
                      ...shown.take(30).map((item) => ListTile(
                        leading: CircleAvatar(child: Text(item.shop.typeIcon)),
                        title: Text(item.shop.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(item.shop.locationLabel),
                        trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                        onTap: () { Navigator.pop(sheetContext); _selectShop(item); },
                      )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _routeFilter(String value, String text, String selected, ValueChanged<String> onChanged) =>
      ChoiceChip(label: Text(text), selected: selected == value, onSelected: (_) => onChanged(value));

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    if (_query.isEmpty && !_searchCollapsed && mounted) {
      setState(() => _searchCollapsed = true);
    }
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() {
        _lazyBounds = _mapController.camera.visibleBounds;
        _searchCollapsed = false;
      });
      unawaited(_saveCamera());
    });
  }

  void _refreshLazyBounds() {
    if (!_mapReady) return;
    setState(() => _lazyBounds = _mapController.camera.visibleBounds);
  }

  void _setAroundPin(LatLng point) {
    setState(() {
      _aroundPin = point;
      _selectedShop = null;
      _selectedPoint = null;
      _showAutocomplete = false;
    });
    _message('گەڕان لە دەوری ئەم خاڵە چالاک کرا.');
  }

  void _clearAroundPin() => setState(() => _aroundPin = null);

  List<_MappedShop> get _filteredMapped {
    final q = _normalize(_query);
    final bounds = _lazyBounds;
    return _mapped.where((item) {
      final shop = item.shop;
      if (_selectedType.isNotEmpty && (shop.businessType ?? '').toLowerCase() != _selectedType.toLowerCase()) return false;
      if (_aroundPin != null) {
        final d = _distance.as(LengthUnit.Meter, _aroundPin!, item.point);
        if (d > _aroundRadiusMeters) return false;
      } else if (bounds != null && !_loading && !bounds.contains(item.point)) {
        return false;
      }
      if (q.isEmpty) return true;
      final haystack = _normalize([
        shop.name,
        shop.slug,
        shop.typeLabel,
        shop.businessType ?? '',
        shop.cityName ?? '',
        shop.regionName ?? '',
        shop.addressDetail ?? '',
        shop.bio ?? '',
        shop.phone ?? '',
      ].join(' '));
      return haystack.contains(q) || _remoteShopSlugs.contains(shop.slug);
    }).toList();
  }

  String _normalize(String value) {
    var s = value.toLowerCase().trim();
    const replacements = <String, String>{
      'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ة': 'ە', 'ۀ': 'ە', 'ؤ': 'ۆ',
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4', '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    };
    for (final e in replacements.entries) s = s.replaceAll(e.key, e.value);
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  List<_MapSuggestion> get _suggestions {
    final q = _normalize(_query);
    if (q.length < 2) return const <_MapSuggestion>[];
    final result = <_MapSuggestion>[];
    final seen = <String>{};
    for (final item in _mapped) {
      final shop = item.shop;
      final values = <(String, String)>[
        (shop.name, 'دووکان'),
        if ((shop.cityName ?? '').isNotEmpty) (shop.cityName!, 'شار'),
        if ((shop.regionName ?? '').isNotEmpty) (shop.regionName!, 'ناوچە'),
        (shop.typeLabel, 'جۆر'),
        if ((shop.addressDetail ?? '').isNotEmpty) (shop.addressDetail!, 'ناونیشان'),
      ];
      for (final pair in values) {
        if (_normalize(pair.$1).contains(q) && seen.add('${pair.$2}:${pair.$1}')) {
          result.add(_MapSuggestion(text: pair.$1, kind: pair.$2, mappedShop: pair.$2 == 'دووکان' ? item : null));
          if (result.length >= 7) return result;
        }
      }
    }
    return result;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _query = value;
      _showAutocomplete = value.trim().length >= 2;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _submitSearch([String? value]) async {
    final query = (value ?? _query).trim();
    if (query.isEmpty) return;

    setState(() => _remoteShopSlugs = <String>{});
    var matches = _filteredMapped;
    if (matches.isNotEmpty) {
      _showMapMatches(matches);
      return;
    }

    // Do not depend on the newer global_search endpoint for map search.
    // The existing shops_public endpoint is already used by the app and can
    // search name, city, region, address, business type, phone and description.
    try {
      final remoteShops = await ShopService.fetchShops(query: query);
      final added = <_MappedShop>[];
      for (final shop in remoteShops.take(60)) {
        var point = _extractLatLng(shop.googleMapsUrl) ?? _coordinateCache[shop.slug];
        if (point == null && (shop.googleMapsUrl ?? '').trim().isNotEmpty) {
          final resolved = await _resolveShopPoint(shop);
          point = resolved?.point;
        }
        if (point != null) added.add(_MappedShop(shop: shop, point: point));
      }
      if (!mounted) return;
      final merged = <String, _MappedShop>{for (final item in _mapped) item.shop.slug: item};
      for (final item in added) merged[item.shop.slug] = item;
      setState(() {
        _mapped = merged.values.toList(growable: false);
        _remoteShopSlugs = remoteShops.map((shop) => shop.slug).toSet();
        _showAutocomplete = false;
      });
      matches = _filteredMapped;
      if (matches.isNotEmpty) {
        _showMapMatches(matches);
        return;
      }
    } catch (_) {
      // Local/cached map search is still available even if the server is offline.
    }

    if (!mounted) return;
    setState(() => _showAutocomplete = false);
    _message('هیچ شوێنێک بۆ «$query» لە نەخشەدا نەدۆزرایەوە.');
  }

  void _showMapMatches(List<_MappedShop> matches) {
    if (matches.isEmpty || !_mapReady) return;
    setState(() {
      _selectedShop = matches.length == 1 ? matches.first.shop : null;
      _selectedPoint = matches.length == 1 ? matches.first.point : null;
      _showAutocomplete = false;
    });
    if (matches.length == 1) {
      _mapController.move(matches.first.point, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: matches.map((item) => item.point).toList(),
        padding: const EdgeInsets.fromLTRB(48, 130, 48, 150),
        maxZoom: 16,
        minZoom: 5,
      ),
    );
    _message('${matches.length} ئەنجام لەسەر نەخشە دۆزرایەوە.');
  }

  void _applyVoice(String value) {
    _search.text = value;
    _search.selection = TextSelection.collapsed(offset: value.length);
    _onSearchChanged(value);
    _submitSearch(value);
  }

  void _clearSearch() {
    _search.clear();
    setState(() {
      _query = '';
      _remoteShopSlugs = <String>{};
      _showAutocomplete = false;
    });
  }

  void _showLayersSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> update(VoidCallback fn) async {
            setState(fn);
            setSheetState(() {});
          }
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Layers و Privacy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  SegmentedButton<_MapBaseLayer>(
                    segments: const [
                      ButtonSegment(value: _MapBaseLayer.street, icon: Icon(Icons.map_rounded), label: Text('Street')),
                    ],
                    selected: const {_MapBaseLayer.street},
                    onSelectionChanged: (_) => update(() => _baseLayer = _MapBaseLayer.street),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'ئێستا نەخشەکە بە OpenStreetMap ـی بێ API key کار دەکات. Satellite و Traffic تا دانانی provider ـی تایبەتی NIZIK ناچالاکن.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Traffic layer', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_trafficTemplate.isEmpty
                        ? 'لە ئێستادا ناچالاکە؛ نەخشەی سەرەکی هیچ API key ـێک ناوێت.'
                        : 'Traffic provider ئامادەیە.'),
                    value: _trafficTemplate.isEmpty ? false : _traffic,
                    onChanged: _trafficTemplate.isEmpty ? null : (v) => update(() => _traffic = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Location Privacy Mode', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Live tracking دەوەستێنێت و شوێنی تۆ لە ماپ نیشان نادرێت.'),
                    value: _privacyMode,
                    onChanged: (v) async {
                      await update(() {
                        _privacyMode = v;
                        if (v) { _myLocation = null; _followUser = false; }
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(_privacyKey, v);
                      if (v) await _stopLiveLocation(); else await _startLiveLocation(silent: true);
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use approximate location', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('شوێن بە وردی نزیکەی 100–150m نیشان دەدرێت.'),
                    value: _approximateLocation,
                    onChanged: (v) async {
                      await update(() => _approximateLocation = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(_approxKey, v);
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () async { await Geolocator.openAppSettings(); }, icon: const Icon(Icons.settings_rounded), label: const Text('App Settings'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () async { await _locationPrefs.clearArea(); if (mounted) _message('شوێنی هەڵگیراو پاککرایەوە.'); }, icon: const Icon(Icons.location_off_rounded), label: const Text('پاککردنەوەی شوێن'))),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCategorySheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('هەموو'), selected: _selectedType.isEmpty, onSelected: (_) { setState(() => _selectedType = ''); Navigator.pop(context); }),
              ..._businessTypes.map((type) => ChoiceChip(
                label: Text('${type.icon} ${type.name} (${type.shopCount})'),
                selected: _selectedType ==
                    (type.key.trim().isNotEmpty
                        ? type.key.trim()
                        : type.name.trim().toLowerCase()),
                onSelected: (_) {
                  final value = type.key.trim().isNotEmpty
                      ? type.key.trim()
                      : type.name.trim().toLowerCase();
                  setState(() => _selectedType = value);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _resetNorth() => _mapController.rotate(0);

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text, textDirection: TextDirection.rtl)));
  }

  String _distanceText(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _durationText(double seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes خولەک';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  String? _distanceLabelTo(LatLng point) {
    final current = _myLocation;
    if (current == null) return null;
    final meters = _distance.as(LengthUnit.Meter, current, point);
    return _distanceText(meters);
  }

  Color _businessColor(Shop shop) {
    if (shop.openingStatus != null && !shop.openingStatus!.isOpen) return const Color(0xFF94A3B8);
    final value = (shop.businessType ?? shop.typeLabel).codeUnits.fold<int>(0, (a, b) => a + b);
    const colors = <Color>[
      Color(0xFF059669), Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFEA580C),
      Color(0xFF0891B2), Color(0xFFDB2777), Color(0xFF4F46E5), Color(0xFF16A34A),
    ];
    return colors[value % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: _buildMap()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _buildTopSearch(),
              ),
            ),
            _buildFloatingControls(),
            if (_showAutocomplete && _query.trim().length >= 2) _buildAutocomplete(),
            if (_loading) _buildLoadingPill(),
            if (_locationError != null) _buildLocationProblem(),
            if (_error != null) _buildDataProblem(),
            if (_aroundPin != null) _buildAroundPill(),
            if (_selectedShop == null && _routeAlternatives.isEmpty) _buildMapDock(),
            if (_selectedShop != null && _selectedPoint != null) _buildSelectedCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // HOTFIX 13: force one keyless provider during stabilization.
    // No dart-define, no ArcGIS/Esri, no CARTO, no satellite, no traffic.
    // This deliberately ignores all previous NIZIK_MAP_* environment values
    // so an old launch configuration cannot inject a provider that returns
    // branded "API KEY REQUIRED" tiles.
    const baseTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    const baseMaxNativeZoom = 19;

    return ColoredBox(
      color: isDark ? const Color(0xFF07110E) : const Color(0xFFEAF1ED),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _defaultCenter,
          initialZoom: 12,
          minZoom: 3,
          maxZoom: 19,
          keepAlive: true,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          onMapReady: () {
            _mapReady = true;
            _refreshLazyBounds();
          },
          onPositionChanged: _onMapMoved,
          onLongPress: (_, point) => _setAroundPin(point),
          onTap: (_, __) {
            if (_showAutocomplete) setState(() => _showAutocomplete = false);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: baseTemplate,
            userAgentPackageName: 'com.nizik.nizikNative',
            maxNativeZoom: baseMaxNativeZoom,
            tileProvider: NetworkTileProvider(),
          ),
          if (isDark)
            IgnorePointer(
              child: ColoredBox(
                color: const Color(0xFF06110D).withValues(alpha: .38),
              ),
            ),
          if (_myLocation != null && _gpsAccuracy > 0)
            CircleLayer(circles: [
              CircleMarker(
                point: _myLocation!,
                radius: _gpsAccuracy,
                useRadiusInMeter: true,
                color: _mapGreen.withValues(alpha: .10),
                borderColor: _mapGreen.withValues(alpha: .32),
                borderStrokeWidth: 1.5,
              ),
            ]),
          if (_aroundPin != null)
            CircleLayer(circles: [
              CircleMarker(
                point: _aroundPin!,
                radius: _aroundRadiusMeters,
                useRadiusInMeter: true,
                color: const Color(0xFF2563EB).withValues(alpha: .07),
                borderColor: const Color(0xFF2563EB).withValues(alpha: .45),
                borderStrokeWidth: 2,
              ),
            ]),
          if (_routeAlternatives.isNotEmpty)
            PolylineLayer(
              polylines: [
                for (var i = 0; i < _routeAlternatives.length; i++)
                  Polyline(
                    points: _routeAlternatives[i].points,
                    strokeWidth: i == _routeIndex ? 6 : 3,
                    color: i == _routeIndex
                        ? _mapGreen
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: .45),
                    borderStrokeWidth: i == _routeIndex ? 2.5 : 0,
                    borderColor: isDark ? const Color(0xFF0D1713) : Colors.white,
                  ),
              ],
            ),
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 48,
              maxZoom: 15,
              size: const Size(48, 48),
              padding: const EdgeInsets.all(40),
              markers: _filteredMapped.map((mapped) {
                final selected = _selectedShop?.slug == mapped.shop.slug;
                return Marker(
                  point: mapped.point,
                  width: selected ? 214 : 64,
                  height: selected ? 82 : 70,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectShop(mapped),
                    child: _BusinessTypePin(
                      shop: mapped.shop,
                      selected: selected,
                      color: _businessColor(mapped.shop),
                      distanceLabel: _distanceLabelTo(mapped.point),
                    ),
                  ),
                );
              }).toList(),
              builder: (context, cluster) => _NizikClusterPin(
                count: cluster.length,
                isDark: isDark,
              ),
            ),
          ),
          MarkerLayer(markers: [
            if (_aroundPin != null)
              Marker(
                point: _aroundPin!,
                width: 34,
                height: 42,
                child: const Icon(Icons.location_pin, color: Color(0xFF2563EB), size: 38),
              ),
            if (_myLocation != null)
              Marker(point: _myLocation!, width: 62, height: 62, child: _UserLocationPin(heading: _heading)),
          ]),
          SimpleAttributionWidget(
            source: Text(
              'OpenStreetMap contributors',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            alignment: Alignment.bottomLeft,
          ),
        ],
      ),
    );
  }

  Widget _buildTopSearch() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            _MapCircleButton(icon: Icons.arrow_forward_rounded, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 8),
          ],
          if (_searchCollapsed)
            _MapCircleButton(
              icon: Icons.search_rounded,
              onTap: () => setState(() => _searchCollapsed = false),
              tooltip: 'گەڕان',
            )
          else
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 58,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 8))],
                ),
                child: TextField(
                  controller: _search,
                  onTap: () => setState(() => _searchCollapsed = false),
                  onChanged: _onSearchChanged,
                  onSubmitted: _submitSearch,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
                  cursorColor: theme.colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: 'دووکان، شار، ناوچە، ناونیشان، ژمارە…',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                    prefixIcon: IconButton(onPressed: () => _submitSearch(), icon: const Icon(Icons.search_rounded, color: _mapGreen)),
                    suffixIconConstraints: const BoxConstraints(minWidth: 86, maxWidth: 98),
                    suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_query.isNotEmpty)
                        IconButton(onPressed: _clearSearch, icon: const Icon(Icons.close_rounded, size: 20)),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 5),
                        child: NizikVoiceButton(compact: true, onResult: _applyVoice),
                      ),
                    ]),
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 78,
      left: 12,
      child: Column(
        children: [
          Transform.rotate(
            angle: -_heading * math.pi / 180,
            child: _MapCircleButton(icon: Icons.explore_rounded, onTap: _resetNorth, tooltip: 'Compass / North'),
          ),
          const SizedBox(height: 8),
          _MapCircleButton(icon: Icons.layers_rounded, onTap: _showLayersSheet, tooltip: 'Layers'),
          const SizedBox(height: 8),
          _MapCircleButton(icon: Icons.category_rounded, onTap: _showCategorySheet, tooltip: 'جۆری دووکان'),
          const SizedBox(height: 8),
          _MapCircleButton(icon: Icons.my_location_rounded, onTap: _goToMyLocation, loading: _gettingLocation, tooltip: 'شوێنی من'),
          if (_routeAlternatives.isNotEmpty) ...[
            const SizedBox(height: 8),
            _MapCircleButton(icon: Icons.route_rounded, onTap: _fitRoute, tooltip: 'ڕێگاکە'),
          ],
        ],
      ),
    );
  }

  Widget _buildAutocomplete() {
    final suggestions = _suggestions;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 68,
      right: 12,
      left: 12,
      child: Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...suggestions.map((s) => ListTile(
            dense: true,
            leading: Icon(s.kind == 'دووکان' ? Icons.storefront_rounded : s.kind == 'شار' ? Icons.location_city_rounded : Icons.location_on_outlined, color: _mapGreen),
            title: Text(s.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(s.kind, style: const TextStyle(fontSize: 10)),
            onTap: () {
              _search.text = s.text;
              _search.selection = TextSelection.collapsed(offset: s.text.length);
              _onSearchChanged(s.text);
              if (s.mappedShop != null) _selectShop(s.mappedShop!); else _submitSearch(s.text);
            },
          )),
          ListTile(
            dense: true,
            leading: const Icon(Icons.travel_explore_rounded, color: Color(0xFF2563EB)),
            title: Text('گەڕان لە هەموو دووکانەکان بۆ «$_query»', style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('ناو، شار، ناوچە، ناونیشان، ژمارە و جۆری دووکان', style: TextStyle(fontSize: 10)),
            onTap: () => _submitSearch(_query),
          ),
        ]),
      ),
    );
  }

  Widget _buildLoadingPill() => Positioned(
    top: MediaQuery.paddingOf(context).top + 76,
    right: 76,
    left: 76,
    child: _StatusPill(icon: Icons.sync_rounded, text: '$_resolvedCount / $_shopCount شوێن'),
  );

  Widget _buildLocationProblem() => Positioned(
    top: MediaQuery.paddingOf(context).top + 76,
    right: 76,
    left: 12,
    child: Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(Icons.location_off_rounded, color: Theme.of(context).colorScheme.error, size: 18),
          const SizedBox(width: 7),
          Expanded(child: Text(_locationError!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
          TextButton(onPressed: Geolocator.openAppSettings, child: const Text('Settings')),
        ]),
      ),
    ),
  );

  Widget _buildAroundPill() => Positioned(
    top: MediaQuery.paddingOf(context).top + 76,
    right: 76,
    child: _StatusPill(
      icon: Icons.radar_rounded,
      text: 'دەوری خاڵ • ${(_aroundRadiusMeters / 1000).toStringAsFixed(1)} km',
      trailing: IconButton(onPressed: _clearAroundPin, icon: const Icon(Icons.close_rounded, size: 18)),
    ),
  );

  Widget _buildDataProblem() {
    final theme = Theme.of(context);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 76,
      right: 12,
      left: 68,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(18),
        elevation: 10,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(11, 8, 6, 8),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_mapped.isEmpty ? 'داتای دووکان لۆد نەکرا' : 'داتای ئۆفلاینی دوا جار', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                Text(_mapped.isEmpty ? 'نەخشە هەر بەردەوامە؛ GPS و جوڵان بەکاربهێنە.' : 'دووکانە هەڵگیراوەکان نیشان دەدرێن تا پەیوەندی بگەڕێتەوە.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9.5)),
              ]),
            ),
            IconButton(onPressed: _loadMapData, tooltip: 'دووبارە', icon: const Icon(Icons.refresh_rounded, size: 19)),
          ]),
        ),
      ),
    );
  }

  Widget _buildMapDock() {
    final theme = Theme.of(context);
    final count = _filteredMapped.length;
    return Positioned(
      right: 12,
      left: 12,
      bottom: MediaQuery.paddingOf(context).bottom + 10,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: .97),
        elevation: 12,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.storefront_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$count شوێن لەم ناوچەیەدا', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 11.5, fontWeight: FontWeight.w900)),
                Text(_selectedType.isEmpty ? 'هەموو جۆرەکان' : 'فلتەرکراو', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9.5)),
              ]),
            ),
            IconButton.filledTonal(onPressed: _showCategorySheet, tooltip: 'جۆرەکان', icon: const Icon(Icons.tune_rounded, size: 19)),
            const SizedBox(width: 4),
            IconButton.filled(onPressed: _goToMyLocation, tooltip: 'شوێنی من', icon: const Icon(Icons.my_location_rounded, size: 19)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSelectedCard() {
    final shop = _selectedShop!;
    final route = _activeRoute;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOpen = shop.openingStatus?.isOpen;
    final point = _selectedPoint;
    final distance = point == null ? null : _distanceLabelTo(point);

    return Positioned(
      right: 10,
      left: 10,
      bottom: MediaQuery.paddingOf(context).bottom + 8,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        elevation: 18,
        shadowColor: Colors.black38,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: .985),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: shop.isPinned
                  ? const Color(0xFFD4A017).withValues(alpha: .55)
                  : (shop.isVerified
                      ? _mapGreen.withValues(alpha: .35)
                      : theme.colorScheme.outlineVariant),
              width: shop.isPinned || shop.isVerified ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: shop.isPinned
                      ? const [Color(0xFF7A5811), Color(0xFFD4A017)]
                      : const [_mapDarkGreen, _mapGreen],
                ),
              ),
              child: Row(children: [
                const Text(
                  'NIZIK MAP',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .6),
                ),
                const Spacer(),
                if (shop.isVerified) const _MapStatusBadge(icon: Icons.verified_rounded, label: 'پشتڕاستکراوە', foreground: Colors.white),
                if (shop.isVerified && shop.isPinned) const SizedBox(width: 6),
                if (shop.isPinned) const _MapStatusBadge(icon: Icons.star_rounded, label: 'سپۆنسەر', foreground: Colors.white),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _businessColor(shop).withValues(alpha: .35), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (shop.logoUrl ?? '').isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: shop.logoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _MapLogoFallback(icon: shop.typeIcon),
                          )
                        : _MapLogoFallback(icon: shop.typeIcon),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(
                        shop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.w900),
                      )),
                      if (shop.isVerified) const Padding(
                        padding: EdgeInsetsDirectional.only(start: 5),
                        child: Icon(Icons.verified_rounded, color: _mapGreen, size: 18),
                      ),
                      if (shop.isPinned) const Padding(
                        padding: EdgeInsetsDirectional.only(start: 4),
                        child: Icon(Icons.star_rounded, color: Color(0xFFD4A017), size: 18),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${shop.typeIcon} ${shop.typeLabel} • ${shop.locationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 5, children: [
                      if (isOpen != null)
                        _MapInfoPill(
                          icon: Icons.circle,
                          label: isOpen ? 'کراوەیە' : 'داخراوە',
                          color: isOpen ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        ),
                      if (distance != null)
                        _MapInfoPill(icon: Icons.near_me_rounded, label: distance, color: const Color(0xFF2563EB)),
                    ]),
                  ])),
                  IconButton(onPressed: _clearSelection, icon: const Icon(Icons.close_rounded)),
                ]),
                if (route != null) ...[
                  const SizedBox(height: 11),
                  ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: _routeProgress, minHeight: 6)),
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(child: _RouteStat(label: 'دووری', value: _distanceText(route.distanceMeters))),
                    Expanded(child: _RouteStat(label: 'ETA', value: _durationText(route.durationSeconds))),
                    Expanded(child: _RouteStat(label: 'جۆر', value: _routeMode == NizikRouteMode.walking ? 'پیادە' : 'ئۆتۆمبێل')),
                    Expanded(child: _RouteStat(label: 'پێشکەوتن', value: '${(_routeProgress * 100).round()}%')),
                  ]),
                  if (_routeAlternatives.length > 1) ...[
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 35,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _routeAlternatives.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final r = _routeAlternatives[i];
                          return ChoiceChip(
                            label: Text('${i + 1} • ${_distanceText(r.distanceMeters)}'),
                            selected: i == _routeIndex,
                            onSelected: (_) { setState(() => _routeIndex = i); _fitRoute(); },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: FilterChip(label: const Text('Follow'), avatar: const Icon(Icons.navigation_rounded, size: 16), selected: _followUser, onSelected: (v) => setState(() => _followUser = v))),
                    const SizedBox(width: 6),
                    Expanded(child: FilterChip(label: const Text('Auto reroute'), avatar: const Icon(Icons.alt_route_rounded, size: 16), selected: _autoReroute, onSelected: (v) => setState(() => _autoReroute = v))),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(onPressed: _showAlongRoute, tooltip: 'لەسەر ڕێگا', icon: const Icon(Icons.add_road_rounded)),
                  ]),
                ],
                const SizedBox(height: 11),
                Row(children: [
                  Expanded(child: FilledButton.icon(
                    onPressed: _routing ? null : () => _openRouteModeSheet(),
                    icon: _routing
                        ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.directions_rounded),
                    label: Text(route == null ? 'ڕێگا' : 'گۆڕینی ڕێگا'),
                  )),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopDetailScreen(slug: shop.slug))),
                    icon: const Icon(Icons.storefront_rounded),
                    tooltip: 'پڕۆفایل',
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(onPressed: () async {
                    final phone = shop.phone?.trim() ?? '';
                    if (phone.isEmpty) { _message('ژمارەی پەیوەندی بەردەست نییە.'); return; }
                    await launchUrl(Uri(scheme: 'tel', path: phone));
                  }, icon: const Icon(Icons.call_rounded), tooltip: 'پەیوەندی'),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: () => ReportSheet.show(
                      context,
                      targetType: 'shop',
                      targetId: shop.id,
                      targetSlug: shop.slug,
                      reasons: const [
                        'شوێنی دووکان لە نەخشە هەڵەیە',
                        'دووکان گواستراوەتەوە',
                        'ئەم شوێنە هی ئەم دووکانە نییە',
                        'ڕێنمایی گەیشتن هەڵەیە',
                        'هۆکاری تر',
                      ],
                    ),
                    icon: const Icon(Icons.flag_outlined),
                    tooltip: 'ڕاپۆرتی شوێنی هەڵە',
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openRouteModeSheet() async {
    var mode = _routeMode;
    var choice = _routeChoice;
    final result = await showModalBottomSheet<(_RouteChoice, NizikRouteMode)>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Align(alignment: Alignment.centerRight, child: Text('جۆری ڕێگا', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              const SizedBox(height: 12),
              SegmentedButton<NizikRouteMode>(segments: const [ButtonSegment(value: NizikRouteMode.driving, icon: Icon(Icons.directions_car_rounded), label: Text('ئۆتۆمبێل')), ButtonSegment(value: NizikRouteMode.walking, icon: Icon(Icons.directions_walk_rounded), label: Text('پیادە'))], selected: {mode}, onSelectionChanged: (v) => setSheetState(() => mode = v.first)),
              const SizedBox(height: 10),
              SegmentedButton<_RouteChoice>(segments: const [ButtonSegment(value: _RouteChoice.fastest, icon: Icon(Icons.bolt_rounded), label: Text('خێراترین')), ButtonSegment(value: _RouteChoice.shortest, icon: Icon(Icons.straighten_rounded), label: Text('کورتترین'))], selected: {choice}, onSelectionChanged: (v) => setSheetState(() => choice = v.first)),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(context, (choice, mode)), icon: const Icon(Icons.route_rounded), label: const Text('دۆزینەوەی ڕێگا'))),
            ]),
          ),
        ),
      ),
    );
    if (result != null) await _buildRoute(choice: result.$1, mode: result.$2);
  }
}

class _MappedShop {
  final Shop shop;
  final LatLng point;
  const _MappedShop({required this.shop, required this.point});
}

class _MapSuggestion {
  final String text;
  final String kind;
  final _MappedShop? mappedShop;
  const _MapSuggestion({required this.text, required this.kind, this.mappedShop});
}

class _BusinessTypePin extends StatelessWidget {
  const _BusinessTypePin({
    required this.shop,
    required this.selected,
    required this.color,
    this.distanceLabel,
  });

  final Shop shop;
  final bool selected;
  final Color color;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    final open = shop.openingStatus?.isOpen;
    final closed = open == false;
    final fill = closed ? const Color(0xFF7C8798) : color;
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: selected ? 1.02 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: selected
          ? Row(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NizikDropPin(
                  shop: shop,
                  fill: fill,
                  selected: true,
                  closed: closed,
                ),
                Transform.translate(
                  offset: const Offset(-7, -2),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 142),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: shop.isPinned
                            ? const Color(0xFFD4A017).withValues(alpha: .55)
                            : fill.withValues(alpha: .38),
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5)),
                      ],
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(
                              child: Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (shop.isVerified) const Padding(
                              padding: EdgeInsetsDirectional.only(start: 4),
                              child: Icon(Icons.verified_rounded, size: 14, color: _mapGreen),
                            ),
                            if (shop.isPinned) const Padding(
                              padding: EdgeInsetsDirectional.only(start: 3),
                              child: Icon(Icons.star_rounded, size: 14, color: Color(0xFFD4A017)),
                            ),
                          ]),
                          const SizedBox(height: 3),
                          Text(
                            '${open == true ? 'کراوە' : open == false ? 'داخراوە' : shop.typeLabel}${distanceLabel == null ? '' : ' • $distanceLabel'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: open == true
                                  ? const Color(0xFF16A34A)
                                  : (open == false ? const Color(0xFF94A3B8) : theme.colorScheme.onSurfaceVariant),
                              fontSize: 9.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _NizikDropPin(
              shop: shop,
              fill: fill,
              selected: false,
              closed: closed,
            ),
    );
  }
}

class _NizikDropPin extends StatelessWidget {
  const _NizikDropPin({
    required this.shop,
    required this.fill,
    required this.selected,
    required this.closed,
  });

  final Shop shop;
  final Color fill;
  final bool selected;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: selected ? 66 : 60,
      height: selected ? 74 : 68,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          CustomPaint(
            size: Size(selected ? 58 : 54, selected ? 69 : 64),
            painter: _NizikPinPainter(
              color: fill,
              borderColor: Colors.white,
              closed: closed,
            ),
          ),
          Positioned(
            top: selected ? 10 : 9,
            child: Container(
              width: selected ? 36 : 33,
              height: selected ? 36 : 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: closed ? .84 : .98),
                shape: BoxShape.circle,
              ),
              child: Text(
                shop.typeIcon,
                style: TextStyle(fontSize: selected ? 19 : 17),
              ),
            ),
          ),
          Positioned(
            top: 1,
            right: 1,
            child: _TinyMapBadge(
              color: shop.isPinned ? const Color(0xFFD4A017) : (shop.isVerified ? _mapGreen : (closed ? const Color(0xFF94A3B8) : const Color(0xFF22C55E))),
              icon: shop.isPinned
                  ? Icons.star_rounded
                  : (shop.isVerified ? Icons.check_rounded : Icons.circle),
            ),
          ),
          if (shop.isVerified && shop.isPinned)
            const Positioned(
              top: 22,
              right: -1,
              child: _TinyMapBadge(color: _mapGreen, icon: Icons.check_rounded),
            ),
          Positioned(
            bottom: selected ? 5 : 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF053B2D),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Text(
                'N',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NizikPinPainter extends CustomPainter {
  const _NizikPinPainter({required this.color, required this.borderColor, required this.closed});
  final Color color;
  final Color borderColor;
  final bool closed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2);
    final radius = (size.width / 2) - 4;
    final tipY = size.height - 4;

    final path = Path()
      ..moveTo(center.dx, tipY)
      ..cubicTo(center.dx - 8, size.height - 16, 4, center.dy + 12, 4, center.dy)
      ..arcToPoint(
        Offset(size.width - 4, center.dy),
        radius: Radius.circular(radius),
        clockwise: true,
      )
      ..cubicTo(size.width - 4, center.dy + 12, center.dx + 8, size.height - 16, center.dx, tipY)
      ..close();

    final shadow = Paint()
      ..color = const Color(0x44000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(path, shadow);
    canvas.restore();

    final fillPaint = Paint()..color = closed ? color.withValues(alpha: .78) : color;
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(covariant _NizikPinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor || oldDelegate.closed != closed;
}

class _TinyMapBadge extends StatelessWidget {
  const _TinyMapBadge({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 5)],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: icon == Icons.circle ? 6 : 10),
      );
}

class _NizikClusterPin extends StatelessWidget {
  const _NizikClusterPin({required this.count, required this.isDark});
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0B5D3B), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: isDark ? const Color(0xFF101B17) : Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x3A000000), blurRadius: 15, offset: Offset(0, 5))],
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .35), width: 1),
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('N', textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
            Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, height: .9)),
          ]),
        ),
      );
}

class _MapStatusBadge extends StatelessWidget {
  const _MapStatusBadge({required this.icon, required this.label, required this.foreground});
  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: foreground, fontSize: 8.5, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _MapInfoPill extends StatelessWidget {
  const _MapInfoPill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: icon == Icons.circle ? 7 : 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _UserLocationPin extends StatelessWidget {
  const _UserLocationPin({required this.heading});
  final double heading;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(width: 54, height: 54, decoration: const BoxDecoration(color: Color(0x22059669), shape: BoxShape.circle)),
      Transform.rotate(angle: heading * math.pi / 180, child: const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 36, shadows: [Shadow(color: Colors.white, blurRadius: 6)])),
      Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF2563EB), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))),
    ],
  );
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({required this.icon, required this.onTap, this.loading = false, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .97),
    elevation: 7,
    shadowColor: Colors.black26,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: loading ? null : onTap,
      icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text, this.trailing});
  final IconData icon;
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .95),
    elevation: 5,
    borderRadius: BorderRadius.circular(999),
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: 11, end: 5, top: 5, bottom: 5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: _mapGreen), const SizedBox(width: 6), Flexible(child: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))), if (trailing != null) trailing!]),
    ),
  );
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9.5)), const SizedBox(height: 2), Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11))]);
}

class _MapLogoFallback extends StatelessWidget {
  const _MapLogoFallback({this.icon = '🏪'});
  final String icon;
  @override
  Widget build(BuildContext context) => ColoredBox(color: Theme.of(context).colorScheme.primaryContainer, child: Center(child: Text(icon, style: const TextStyle(fontSize: 26))));
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .94),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.map_outlined, size: 58, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('دووبارە')),
        ]),
      ),
    ),
  );
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';
import '../services/global_search_service.dart';
import '../services/location_preference_service.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/shop_service.dart';
import '../widgets/report_sheet.dart';
import '../widgets/voice_search_sheet.dart';
import 'global_search_screen.dart';
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
  static const _trafficTemplate = String.fromEnvironment(
    'NIZIK_TRAFFIC_TILE_URL',
    defaultValue: '',
  );

  final MapController _mapController = MapController();
  final TextEditingController _search = TextEditingController();
  final LocationPreferenceService _locationPrefs = LocationPreferenceService.instance;
  final RouteService _routeService = RouteService();
  final Distance _distance = const Distance();

  late final Future<CacheStore> _cacheStoreFuture = _createCacheStore();

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
  bool _darkMap = false;
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
    _darkMap = Theme.of(context).brightness == Brightness.dark && _baseLayer == _MapBaseLayer.street;
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

  static Future<CacheStore> _createCacheStore() async {
    final dir = await getTemporaryDirectory();
    return FileCacheStore('${dir.path}${Platform.pathSeparator}NizikMapTilesV10');
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
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
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

    try {
      final location = _locationPrefs.preference.value;
      final remote = await GlobalSearchService.search(
        query: query,
        cityId: location.cityId,
        regionId: location.regionId,
      );
      final slugs = remote
          .where((item) => item.kind == 'shop' && item.slug.isNotEmpty)
          .map((item) => item.slug)
          .toSet();
      if (!mounted) return;
      setState(() => _remoteShopSlugs = slugs);
      matches = _filteredMapped;
      if (matches.isNotEmpty) {
        _showMapMatches(matches);
        return;
      }
    } catch (_) {
      // Fall back to the complete search screen.
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GlobalSearchScreen(initialQuery: query)),
    );
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
                      ButtonSegment(value: _MapBaseLayer.satellite, icon: Icon(Icons.satellite_alt_rounded), label: Text('Satellite')),
                    ],
                    selected: {_baseLayer},
                    onSelectionChanged: (v) => update(() => _baseLayer = v.first),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Traffic layer', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_trafficTemplate.isEmpty ? 'پێویستی بە Traffic tile provider هەیە؛ API key لە کۆددا هاردکۆد نەکراوە.' : 'Traffic provider ئامادەیە.'),
                    value: _traffic,
                    onChanged: (v) {
                      if (v && _trafficTemplate.isEmpty) {
                        _message('NIZIK_TRAFFIC_TILE_URL لە build config دابنێ بۆ Traffic layer.');
                        return;
                      }
                      update(() => _traffic = v);
                    },
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
          children: [
            Positioned.fill(child: _buildMap()),
            SafeArea(child: _buildTopSearch()),
            _buildFloatingControls(),
            if (_showAutocomplete && _query.trim().length >= 2) _buildAutocomplete(),
            if (_loading) _buildLoadingPill(),
            if (_locationError != null) _buildLocationProblem(),
            if (_error != null) Positioned.fill(child: _MapError(message: _error!, onRetry: _loadMapData)),
            if (_aroundPin != null) _buildAroundPill(),
            if (_selectedShop != null && _selectedPoint != null && _error == null) _buildSelectedCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FutureBuilder<CacheStore>(
      future: _cacheStoreFuture,
      builder: (context, snapshot) {
        final provider = snapshot.hasData
            ? CachedTileProvider(maxStale: const Duration(days: 45), store: snapshot.data!)
            : NetworkTileProvider();
        return FlutterMap(
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
              urlTemplate: _baseLayer == _MapBaseLayer.satellite
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nizik.nizikNative',
              maxNativeZoom: _baseLayer == _MapBaseLayer.satellite ? 18 : 19,
              tileProvider: provider,
              tileBuilder: _darkMap && _baseLayer == _MapBaseLayer.street
                  ? (context, tileWidget, tile) => ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        -0.78, 0, 0, 0, 238,
                        0, -0.78, 0, 0, 238,
                        0, 0, -0.78, 0, 238,
                        0, 0, 0, 1, 0,
                      ]),
                      child: tileWidget,
                    )
                  : null,
            ),
            if (_traffic && _trafficTemplate.isNotEmpty)
              TileLayer(
                urlTemplate: _trafficTemplate,
                userAgentPackageName: 'com.nizik.nizikNative',
                maxNativeZoom: 19,
                tileProvider: provider,
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
                      color: i == _routeIndex ? _mapGreen : const Color(0xFF64748B).withValues(alpha: .45),
                      borderStrokeWidth: i == _routeIndex ? 2.5 : 0,
                      borderColor: Colors.white,
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
                    width: selected ? 68 : 58,
                    height: selected ? 74 : 64,
                    child: GestureDetector(
                      onTap: () => _selectShop(mapped),
                      child: _BusinessTypePin(
                        shop: mapped.shop,
                        selected: selected,
                        color: _businessColor(mapped.shop),
                      ),
                    ),
                  );
                }).toList(),
                builder: (context, cluster) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [_mapGreen, _mapDarkGreen]),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5))],
                  ),
                  alignment: Alignment.center,
                  child: Text('${cluster.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
            MarkerLayer(markers: [
              if (_aroundPin != null)
                Marker(point: _aroundPin!, width: 34, height: 42, child: const Icon(Icons.location_pin, color: Color(0xFF2563EB), size: 38)),
              if (_myLocation != null)
                Marker(point: _myLocation!, width: 62, height: 62, child: _UserLocationPin(heading: _heading)),
            ]),
            SimpleAttributionWidget(
              source: Text(_baseLayer == _MapBaseLayer.satellite ? 'Esri World Imagery' : '© OpenStreetMap contributors'),
              alignment: Alignment.bottomLeft,
            ),
          ],
        );
      },
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
                height: 54,
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
                  decoration: InputDecoration(
                    hintText: 'دووکان، شار، ناوچە، ناونیشان، ژمارە…',
                    hintStyle: const TextStyle(fontSize: 11),
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
            title: Text('گەڕانی فراوان بۆ «$_query»', style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('دووکان + خزمەتگوزاری + menu/catalog', style: TextStyle(fontSize: 10)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GlobalSearchScreen(initialQuery: _query))),
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

  Widget _buildSelectedCard() {
    final shop = _selectedShop!;
    final route = _activeRoute;
    final theme = Theme.of(context);
    final isOpen = shop.openingStatus?.isOpen;
    return Positioned(
      right: 10,
      left: 10,
      bottom: MediaQuery.paddingOf(context).bottom + 8,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: .98),
        borderRadius: BorderRadius.circular(28),
        elevation: 14,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: (shop.logoUrl ?? '').isNotEmpty
                      ? CachedNetworkImage(imageUrl: shop.logoUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const _MapLogoFallback())
                      : const _MapLogoFallback(),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                  if (shop.isVerified) const Padding(padding: EdgeInsetsDirectional.only(start: 5), child: Icon(Icons.verified_rounded, color: _mapGreen, size: 17)),
                  if (shop.isPinned) const Padding(padding: EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 17)),
                ]),
                const SizedBox(height: 3),
                Text('${shop.typeIcon} ${shop.typeLabel} • ${shop.locationLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10.5)),
                if (isOpen != null) Text(isOpen ? 'کراوەیە' : 'داخراوە', style: TextStyle(color: isOpen ? _mapGreen : theme.colorScheme.error, fontWeight: FontWeight.w900, fontSize: 10.5)),
              ])),
              IconButton(onPressed: _clearSelection, icon: const Icon(Icons.close_rounded)),
            ]),
            if (route != null) ...[
              const SizedBox(height: 10),
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
                SizedBox(height: 35, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _routeAlternatives.length, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (_, i) {
                  final r = _routeAlternatives[i];
                  return ChoiceChip(label: Text('${i + 1} • ${_distanceText(r.distanceMeters)}'), selected: i == _routeIndex, onSelected: (_) { setState(() => _routeIndex = i); _fitRoute(); });
                })),
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
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: _routing ? null : () => _openRouteModeSheet(),
                icon: _routing ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.directions_rounded),
                label: Text(route == null ? 'ڕێگا' : 'گۆڕینی ڕێگا'),
              )),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopDetailScreen(slug: shop.slug))), icon: const Icon(Icons.storefront_rounded), tooltip: 'پڕۆفایل'),
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
  const _BusinessTypePin({required this.shop, required this.selected, required this.color});
  final Shop shop;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final open = shop.openingStatus?.isOpen;
    final fill = open == false ? const Color(0xFF94A3B8) : color;
    return AnimatedScale(
      scale: selected ? 1.12 : 1,
      duration: const Duration(milliseconds: 180),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: Text(shop.typeIcon, style: TextStyle(fontSize: 22, color: open == false ? Colors.white70 : Colors.white)),
            ),
            Transform.translate(
              offset: const Offset(0, -5),
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(width: 12, height: 12, color: fill),
              ),
            ),
          ]),
          if (shop.isVerified)
            Positioned(left: 0, top: -2, child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.verified_rounded, color: _mapGreen, size: 18))),
          if (shop.isPinned)
            Positioned(right: 0, top: -2, child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 18))),
          Positioned(
            bottom: 1,
            right: 5,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: open == null ? const Color(0xFFCBD5E1) : (open ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
  const _MapLogoFallback();
  @override
  Widget build(BuildContext context) => ColoredBox(color: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.storefront_rounded, color: Theme.of(context).colorScheme.primary, size: 30));
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

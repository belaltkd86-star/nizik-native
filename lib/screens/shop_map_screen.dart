import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';
import '../services/location_preference_service.dart';
import '../services/location_service.dart';
import '../services/shop_service.dart';

class ShopMapScreen extends StatefulWidget {
  final Shop? focusShop;
  final bool autoLocate;

  const ShopMapScreen({
    super.key,
    this.focusShop,
    this.autoLocate = true,
  });

  @override
  State<ShopMapScreen> createState() =>
      _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen> {
  final _locationPrefs = LocationPreferenceService.instance;
  static const LatLng _defaultCenter =
      LatLng(35.5613, 45.4309);

  final MapController _mapController =
      MapController();
  final TextEditingController _mapSearchController =
      TextEditingController();

  StreamSubscription<Position>? _liveLocationSubscription;

  List<_MappedShop> _mappedShops = [];

  Shop? _selectedShop;
  LatLng? _selectedPoint;
  LatLng? _myLocation;

  List<LatLng> _routePoints = [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;

  bool _loading = true;
  bool _gettingLocation = false;
  bool _loadingRoute = false;
  bool _darkMap = false;
  Brightness? _lastAppBrightness;

  String _mapSearchQuery = '';
  String? _error;
  int _resolvedCount = 0;
  int _shopCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_lastAppBrightness != brightness) {
      _lastAppBrightness = brightness;
      _darkMap = brightness == Brightness.dark;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedShop = widget.focusShop;
    if (widget.focusShop == null) {
      _locationPrefs.preference.addListener(_onLocationChanged);
    }
    _loadMapData();

    // Start foreground live GPS after the map has rendered.
    // The marker then updates automatically without manual refresh.
    if (widget.autoLocate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startLiveLocation();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ShopMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.autoLocate && widget.autoLocate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startLiveLocation();
      });
    }
  }

  void _onLocationChanged() {
    if (!mounted || widget.focusShop != null) return;
    _loadMapData();
  }

  @override
  void dispose() {
    _locationPrefs.preference.removeListener(_onLocationChanged);
    _liveLocationSubscription?.cancel();
    _liveLocationSubscription = null;
    _mapSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    setState(() {
      _loading = true;
      _error = null;
      _resolvedCount = 0;
      _routePoints = [];
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
    });

    try {
      final location = _locationPrefs.preference.value;
      final shops = await ShopService.fetchShops(
        cityId: widget.focusShop == null ? location.cityId : null,
        regionId: widget.focusShop == null ? location.regionId : null,
      );

      if (!mounted) return;

      _shopCount = shops.length;

      final mapped = <_MappedShop>[];

      // Resolve the focused shop first so profile -> map opens quickly.
      if (widget.focusShop != null) {
        final focused = await _resolveShopPoint(
          widget.focusShop!,
          allowNetworkResolve: true,
        );

        if (focused != null) {
          mapped.add(focused);

          _selectedShop = focused.shop;
          _selectedPoint = focused.point;
        }
      }

      final remaining = shops
          .where(
            (shop) =>
                widget.focusShop == null ||
                shop.slug != widget.focusShop!.slug,
          )
          .toList();

      // Direct coordinates are instant.
      final unresolved = <Shop>[];

      for (final shop in remaining) {
        final direct = _extractLatLng(
          shop.googleMapsUrl,
        );

        if (direct != null) {
          mapped.add(
            _MappedShop(
              shop: shop,
              point: direct,
            ),
          );
        } else if (shop.googleMapsUrl != null &&
            shop.googleMapsUrl!.trim().isNotEmpty) {
          unresolved.add(shop);
        }
      }

      if (mounted) {
        setState(() {
          _mappedShops = List.of(mapped);
          _resolvedCount = mapped.length;
        });
      }

      // Short Google Maps links are resolved by the same safe
      // server-side mechanism that the old Nizik map used.
      //
      // Limit background resolution on the global map to keep it fast.
      // The focused profile shop is always resolved above.
      final candidates = unresolved.take(36).toList();

      const batchSize = 6;

      for (var i = 0;
          i < candidates.length;
          i += batchSize) {
        final end = (i + batchSize < candidates.length)
            ? i + batchSize
            : candidates.length;

        final batch =
            candidates.sublist(i, end);

        final results = await Future.wait(
          batch.map(
            (shop) => _resolveShopPoint(
              shop,
              allowNetworkResolve: true,
            ),
          ),
        );

        for (final result in results) {
          if (result != null &&
              !mapped.any(
                (entry) =>
                    entry.shop.slug ==
                    result.shop.slug,
              )) {
            mapped.add(result);
          }
        }

        if (!mounted) return;

        setState(() {
          _mappedShops = List.of(mapped);
          _resolvedCount = mapped.length;
        });
      }

      if (!mounted) return;

      setState(() {
        _mappedShops = mapped;
        _resolvedCount = mapped.length;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (_selectedPoint != null) {
          _mapController.move(
            _selectedPoint!,
            16,
          );
        } else if (_mappedShops.isNotEmpty) {
          _mapController.move(
            _mappedShops.first.point,
            13,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  Future<_MappedShop?> _resolveShopPoint(
    Shop shop, {
    required bool allowNetworkResolve,
  }) async {
    final direct =
        _extractLatLng(shop.googleMapsUrl);

    if (direct != null) {
      return _MappedShop(
        shop: shop,
        point: direct,
      );
    }

    if (!allowNetworkResolve ||
        shop.googleMapsUrl == null ||
        shop.googleMapsUrl!.trim().isEmpty) {
      return null;
    }

    try {
      final coords =
          await ShopService.resolveCoordinates(
        shop.slug,
      );

      return _MappedShop(
        shop: shop,
        point: LatLng(
          coords.lat,
          coords.lng,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  LatLng? _extractLatLng(String? rawUrl) {
    if (rawUrl == null ||
        rawUrl.trim().isEmpty) {
      return null;
    }

    final decoded =
        Uri.decodeFull(rawUrl.trim());

    final patterns = <RegExp>[
      RegExp(
        r'@(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)',
      ),
      RegExp(
        r'!3d(-?\d{1,2}(?:\.\d+)?)[^!]*!4d(-?\d{1,3}(?:\.\d+)?)',
      ),
      RegExp(
        r'(?:query|q|destination|ll|center)=(-?\d{1,2}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(-?\d{1,2}\.\d{4,}),\s*(-?\d{1,3}\.\d{4,})',
      ),
    ];

    for (final pattern in patterns) {
      final match =
          pattern.firstMatch(decoded);

      if (match == null) continue;

      final lat = double.tryParse(
        match.group(1) ?? '',
      );

      final lng = double.tryParse(
        match.group(2) ?? '',
      );

      if (lat == null || lng == null) {
        continue;
      }

      if (lat < -90 || lat > 90) {
        continue;
      }

      if (lng < -180 || lng > 180) {
        continue;
      }

      return LatLng(lat, lng);
    }

    return null;
  }

  Future<void> _startLiveLocation() async {
    if (_liveLocationSubscription != null) {
      return;
    }

    try {
      // Get one immediate fix first, then keep listening for changes.
      final position =
          await LocationService.getCurrentLocation();

      if (!mounted) return;

      _applyLivePosition(position);
      _subscribeToLiveLocation();
    } catch (_) {
      // Permission/service messages are handled when the user taps
      // the location button. Avoid showing repeated snackbars here.
    }
  }

  void _subscribeToLiveLocation() {
    if (_liveLocationSubscription != null) {
      return;
    }

    _liveLocationSubscription =
        LocationService.watchPosition().listen(
      _applyLivePosition,
      onError: (Object _) {
        _liveLocationSubscription?.cancel();
        _liveLocationSubscription = null;
      },
    );
  }

  void _applyLivePosition(Position position) {
    if (!mounted) return;

    final point = LatLng(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _myLocation = point;
    });
  }

  Future<void> _goToMyLocation({
    bool moveMap = true,
  }) async {
    if (_gettingLocation) return;

    setState(() {
      _gettingLocation = true;
    });

    try {
      final position =
          await LocationService.getCurrentLocation();

      if (!mounted) return;

      if (position == null) {
        _message(
          'ڕێگە بە Location نەدراوە.',
        );
        return;
      }

      final point = LatLng(
        position.latitude,
        position.longitude,
      );

      _applyLivePosition(position);
      _subscribeToLiveLocation();

      if (moveMap) {
        _mapController.move(
          point,
          15.5,
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          'نەتوانرا شوێنی ئێستات دیاری بکرێت.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  void _selectShop(_MappedShop mapped) {
    setState(() {
      _selectedShop = mapped.shop;
      _selectedPoint = mapped.point;
      _routePoints = [];
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
    });

    _mapController.move(
      mapped.point,
      15.5,
    );
  }

  Future<void> _buildRoute() async {
    final target = _selectedPoint;

    if (target == null) {
      _message(
        'یەکەم دووکانێک لەسەر نەخشە هەڵبژێرە.',
      );
      return;
    }

    if (_myLocation == null) {
      await _goToMyLocation(
        moveMap: false,
      );
    }

    final start = _myLocation;

    if (start == null || !mounted) {
      return;
    }

    setState(() {
      _loadingRoute = true;
    });

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/'
        'route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${target.longitude},${target.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      final response =
          await http.get(uri).timeout(
        const Duration(seconds: 12),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Route HTTP ${response.statusCode}',
        );
      }

      final dynamic decoded =
          jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid route');
      }

      final routes = decoded['routes'];

      if (routes is! List ||
          routes.isEmpty ||
          routes.first
              is! Map<String, dynamic>) {
        throw Exception('No route');
      }

      final route =
          routes.first as Map<String, dynamic>;

      final geometry = route['geometry'];

      if (geometry is! Map<String, dynamic>) {
        throw Exception('No geometry');
      }

      final coordinates =
          geometry['coordinates'];

      if (coordinates is! List) {
        throw Exception('No coordinates');
      }

      final points = <LatLng>[];

      for (final pair in coordinates) {
        if (pair is List &&
            pair.length >= 2) {
          final lng =
              double.tryParse(
            pair[0].toString(),
          );

          final lat =
              double.tryParse(
            pair[1].toString(),
          );

          if (lat != null &&
              lng != null) {
            points.add(
              LatLng(lat, lng),
            );
          }
        }
      }

      if (points.isEmpty) {
        throw Exception('Empty route');
      }

      final distance = double.tryParse(
        route['distance']?.toString() ?? '',
      );

      final duration = double.tryParse(
        route['duration']?.toString() ?? '',
      );

      if (!mounted) return;

      setState(() {
        _routePoints = points;
        _routeDistanceMeters = distance;
        _routeDurationSeconds = duration;
      });

      final mid = LatLng(
        (start.latitude +
                target.latitude) /
            2,
        (start.longitude +
                target.longitude) /
            2,
      );

      _mapController.move(
        mid,
        _zoomForDistance(
          distance ?? 5000,
        ),
      );
    } catch (_) {
      if (mounted) {
        _message(
          'ڕێگای شەقام لە ئێستادا بەردەست نییە.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRoute = false;
        });
      }
    }
  }

  double _zoomForDistance(
    double meters,
  ) {
    if (meters < 1500) return 14.5;
    if (meters < 4000) return 13.5;
    if (meters < 10000) return 12.5;
    if (meters < 25000) return 11;
    if (meters < 70000) return 9.5;
    return 8;
  }

  void _focusSelectedShop() {
    if (_selectedPoint == null) return;

    _mapController.move(
      _selectedPoint!,
      16,
    );
  }

  String _distanceText() {
    final meters =
        _routeDistanceMeters;

    if (meters == null) return '-';

    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _durationText() {
    final seconds =
        _routeDurationSeconds;

    if (seconds == null) return '-';

    final minutes =
        (seconds / 60).ceil();

    if (minutes < 60) {
      return '$minutes خولەک';
    }

    final h = minutes ~/ 60;
    final m = minutes % 60;

    return '$h:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _callSelected() async {
    final phone = _selectedShop?.phone;

    if (phone == null ||
        phone.trim().isEmpty) {
      _message(
        'ژمارەی پەیوەندی بەردەست نییە.',
      );
      return;
    }

    final ok = await launchUrl(
      Uri(
        scheme: 'tel',
        path: phone,
      ),
    );

    if (!ok && mounted) {
      _message(
        'نەتوانرا پەیوەندی بکرێت.',
      );
    }
  }

  List<_MappedShop> get _visibleMappedShops {
    final query = _mapSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return _mappedShops;

    return _mappedShops.where((mapped) {
      final shop = mapped.shop;
      final haystack = <String>[
        shop.name,
        shop.slug,
        shop.typeLabel,
        shop.businessType ?? '',
        shop.cityName ?? '',
        shop.regionName ?? '',
        shop.addressDetail ?? '',
        shop.phone ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  void _submitMapSearch([String? _]) {
    final matches = _visibleMappedShops;
    if (_mapSearchQuery.trim().isEmpty || matches.isEmpty) return;
    _selectShop(matches.first);
  }

  void _clearMapSearch() {
    _mapSearchController.clear();
    setState(() {
      _mapSearchQuery = '';
      _selectedShop = null;
      _selectedPoint = null;
      _routePoints = [];
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildMap(),
              ),

              _buildTopBar(),

              Positioned(
                top: 142,
                right: 12,
                child: _MapControls(
                  gettingLocation:
                      _gettingLocation,
                  onMyLocation:
                      _goToMyLocation,
                  onFocusShop:
                      _focusSelectedShop,
                  onZoomIn: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  onZoomOut: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
              ),

              if (_loading)
                Positioned(
                  top: 142,
                  left: 12,
                  right: 82,
                  child: _LoadingPill(
                    resolved:
                        _resolvedCount,
                    total: _shopCount,
                  ),
                ),

              if (!_loading &&
                  _error == null)
                Positioned(
                  top: 142,
                  left: 12,
                  right: 82,
                  child: _MapStatusPill(
                    resolved:
                        _visibleMappedShops.length,
                    total: _shopCount,
                  ),
                ),

              if (_error != null)
                Positioned.fill(
                  child: _MapError(
                    message: _error!,
                    onRetry:
                        _loadMapData,
                  ),
                ),

              if (_selectedShop != null &&
                  _selectedPoint != null &&
                  _error == null)
                Positioned(
                  right: 10,
                  left: 10,
                  bottom: 10,
                  child:
                      _buildSelectedShopCard(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          // Use the official OpenStreetMap standard raster tiles.
          // This avoids CARTO's new "API key required" watermark.
          //
          // IMPORTANT: OSM requires a unique app User-Agent on native apps.
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName:
              'com.nizik.nizik_native',
          maxNativeZoom: 19,

          // Keep Nizik's light/dark map toggle without using a second
          // third-party basemap provider or exposing an API key.
          tileBuilder: _darkMap
              ? (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix(
                      <double>[
                        -0.78, 0, 0, 0, 238,
                        0, -0.78, 0, 0, 238,
                        0, 0, -0.78, 0, 238,
                        0, 0, 0, 1, 0,
                      ],
                    ),
                    child: tileWidget,
                  );
                }
              : null,
        ),

        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 9,
                color: const Color(
                  0x33064E3B,
                ),
              ),
              Polyline(
                points: _routePoints,
                strokeWidth: 5,
                color: const Color(
                  0xFF10B981,
                ),
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            ..._visibleMappedShops.map(
              (mapped) {
                final selected =
                    _selectedShop?.slug ==
                        mapped.shop.slug;

                return Marker(
                  point: mapped.point,
                  width:
                      selected ? 66 : 54,
                  height:
                      selected ? 66 : 54,
                  child: GestureDetector(
                    onTap: () =>
                        _selectShop(mapped),
                    child: _ShopMapPin(
                      shop: mapped.shop,
                      selected: selected,
                    ),
                  ),
                );
              },
            ),

            if (_myLocation != null)
              Marker(
                point: _myLocation!,
                width: 48,
                height: 48,
                child:
                    const _UserLocationPin(),
              ),
          ],
        ),

        SimpleAttributionWidget(
          source: const Text(
            '© OpenStreetMap contributors',
          ),
          alignment:
              Alignment.bottomLeft,
          onTap: () {
            launchUrl(
              Uri.parse(
                'https://www.openstreetmap.org/copyright',
              ),
              mode: LaunchMode
                  .externalApplication,
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 10,
      right: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              blurRadius: 22,
              color: Colors.black12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    tooltip: 'گەڕانەوە',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  )
                else
                  const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF10B981),
                        Color(0xFF047857),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.map_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نەخشەی نزیک',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'دووکان • شوێن • ڕێگا',
                        style: TextStyle(
                          color: Colors.black45,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'گۆڕینی ڕووکار',
                  onPressed: () {
                    setState(() {
                      _darkMap = !_darkMap;
                    });
                  },
                  icon: Icon(
                    _darkMap
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'نوێکردنەوە',
                  onPressed: _loadMapData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: TextField(
                controller: _mapSearchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _mapSearchQuery = value;
                    if (_selectedShop != null) {
                      final selectedVisible = _visibleMappedShops.any(
                        (entry) => entry.shop.slug == _selectedShop!.slug,
                      );
                      if (!selectedVisible) {
                        _selectedShop = null;
                        _selectedPoint = null;
                        _routePoints = [];
                        _routeDistanceMeters = null;
                        _routeDurationSeconds = null;
                      }
                    }
                  });
                },
                onSubmitted: _submitMapSearch,
                decoration: InputDecoration(
                  hintText: 'لە نەخشەدا بە ناوی دووکان، شار یان ناوچە بگەڕێ...',
                  hintStyle: const TextStyle(fontSize: 11.5),
                  prefixIcon: IconButton(
                    tooltip: 'گەڕان',
                    onPressed: () => _submitMapSearch(),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF047857),
                    ),
                  ),
                  suffixIcon: _mapSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'پاککردنەوە',
                          onPressed: _clearMapSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF3F7F4),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedShopCard() {
    final shop = _selectedShop!;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.98),
        borderRadius:
            BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            blurRadius: 30,
            color: Colors.black26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(17),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child:
                      shop.logoUrl != null
                          ? CachedNetworkImage(
                              imageUrl:
                                  shop.logoUrl!,
                              fit: BoxFit.cover,
                              errorWidget:
                                  (_, __, ___) =>
                                      const _MapLogoFallback(),
                            )
                          : const _MapLogoFallback(),
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      shop.locationLabel,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'داخستن',
                onPressed: () {
                  setState(() {
                    _selectedShop =
                        null;
                    _selectedPoint =
                        null;
                    _routePoints = [];
                    _routeDistanceMeters =
                        null;
                    _routeDurationSeconds =
                        null;
                  });
                },
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
            ],
          ),

          if (_routePoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFF2F8F4,
                ),
                borderRadius:
                    BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RouteStat(
                      label: 'دووری',
                      value:
                          _distanceText(),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color:
                        Colors.black12,
                  ),
                  Expanded(
                    child: _RouteStat(
                      label: 'کات',
                      value:
                          _durationText(),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color:
                        Colors.black12,
                  ),
                  const Expanded(
                    child: _RouteStat(
                      label: 'دۆخ',
                      value: 'ڕێگا',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _loadingRoute
                          ? null
                          : _buildRoute,
                  icon: _loadingRoute
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons
                              .directions_rounded,
                        ),
                  label: Text(
                    _routePoints.isEmpty
                        ? 'ڕێگا'
                        : 'نوێکردنەوەی ڕێگا',
                  ),
                  style:
                      FilledButton.styleFrom(
                    minimumSize:
                        const Size(
                      0,
                      48,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              SizedBox(
                width: 52,
                height: 48,
                child:
                    OutlinedButton(
                  onPressed:
                      _callSelected,
                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        EdgeInsets.zero,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.phone_rounded,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              SizedBox(
                width: 52,
                height: 48,
                child:
                    OutlinedButton(
                  onPressed:
                      _focusSelectedShop,
                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        EdgeInsets.zero,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .storefront_rounded,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MappedShop {
  final Shop shop;
  final LatLng point;

  const _MappedShop({
    required this.shop,
    required this.point,
  });
}

class _ShopMapPin extends StatelessWidget {
  final Shop shop;
  final bool selected;

  const _ShopMapPin({
    required this.shop,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF064E3B)
            : const Color(0xFF10B981),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: selected ? 4 : 3,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: selected ? 15 : 9,
            color:
                const Color(0x55000000),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color:
              const Color(0xFFE6F6EA),
          child: shop.logoUrl != null
              ? CachedNetworkImage(
                  imageUrl:
                      shop.logoUrl!,
                  fit: BoxFit.cover,
                  errorWidget:
                      (_, __, ___) =>
                          const Icon(
                    Icons
                        .storefront_rounded,
                    color:
                        Color(0xFF15803D),
                  ),
                )
              : const Icon(
                  Icons.storefront_rounded,
                  color:
                      Color(0xFF15803D),
                ),
        ),
      ),
    );
  }
}

class _UserLocationPin
    extends StatelessWidget {
  const _UserLocationPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 4,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black26,
          ),
        ],
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 22,
        color: Colors.white,
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  final bool gettingLocation;
  final Future<void> Function({
    bool moveMap,
  }) onMyLocation;
  final VoidCallback onFocusShop;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _MapControls({
    required this.gettingLocation,
    required this.onMyLocation,
    required this.onFocusShop,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MapControlButton(
          tooltip: 'دووکان',
          icon:
              Icons.storefront_rounded,
          onTap: onFocusShop,
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          tooltip: 'شوێنی من',
          icon:
              Icons.my_location_rounded,
          loading: gettingLocation,
          onTap: () =>
              onMyLocation(
            moveMap: true,
          ),
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          tooltip: 'گەورەکردن',
          icon: Icons.add_rounded,
          onTap: onZoomIn,
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          tooltip: 'بچووککردن',
          icon: Icons.remove_rounded,
          onTap: onZoomOut,
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          Colors.white.withValues(
        alpha: 0.96,
      ),
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        tooltip: tooltip,
        onPressed:
            loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : Icon(icon),
      ),
    );
  }
}

class _MapStatusPill extends StatelessWidget {
  final int resolved;
  final int total;

  const _MapStatusPill({
    required this.resolved,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: 0.95,
        ),
        borderRadius:
            BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 18,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$resolved دووکان لەسەر نەخشە',
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '$resolved/$total',
            style:
                const TextStyle(
              color: Colors.black45,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  final int resolved;
  final int total;

  const _LoadingPill({
    required this.resolved,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: 0.95,
        ),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 17,
            height: 17,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              total > 0
                  ? 'شوێنی دووکانەکان دیاری دەکرێت... $resolved/$total'
                  : 'نەخشە بار دەکرێت...',
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStat extends StatelessWidget {
  final String label;
  final String value;

  const _RouteStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MapLogoFallback
    extends StatelessWidget {
  const _MapLogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE6F6EA),
      child: const Icon(
        Icons.storefront_rounded,
        color: Color(0xFF15803D),
        size: 30,
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _MapError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F7F4),
      alignment: Alignment.center,
      padding:
          const EdgeInsets.all(24),
      child: Container(
        padding:
            const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 58,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'دووبارە هەوڵ بدەوە',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../models/shop.dart';
import '../security/nizik_network.dart';
import '../services/api_service.dart';
import '../services/local_store_service.dart';
import '../services/route_service.dart';
import '../services/shop_location_service.dart';
import 'shop_profile_sheet.dart';

const _green = Color(0xFF059669);
const _darkGreen = Color(0xFF047857);
const _softGreen = Color(0xFFECFDF5);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _background = Color(0xFFF8FAFC);
const _line = Color(0xFFE2E8F0);

class MapScreen extends StatefulWidget {
  final bool embedded;

  const MapScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<MapScreen> createState() =>
      _MapScreenState();
}

class _MapScreenState
    extends State<MapScreen>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController =
      MapController();
  final ApiService _api = ApiService();
  final RouteService _routeService =
      RouteService();
  final ShopLocationService _locationService =
      ShopLocationService.instance;
  final LocalStoreService _store =
      LocalStoreService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  static const LatLng _fallbackCenter =
      LatLng(
    35.5570,
    45.4350,
  );

  LatLng? _myLocation;

  final List<_MapShop> _mapShops = [];
  List<BusinessTypeOption> _businessTypes = [];

  _MapShop? _selectedShop;

  bool _mapReady = false;
  bool _loading = true;
  bool _gettingLocation = false;
  bool _routing = false;
  bool _showSearchArea = false;

  String _searchText = '';
  String _selectedBusinessType = '';

  LatLngBounds? _areaBounds;

  String? _error;
  String? _locationMessage;

  int _coordsDone = 0;
  int _coordsTotal = 0;

  List<LatLng> _routePoints = [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  _MapShop? _routeDestination;

  Set<int> _favoriteIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadMap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final ids =
        await _store.getFavoriteIds();

    if (!mounted) return;

    setState(() {
      _favoriteIds = ids;
    });
  }

  Future<void> _loadMap() async {
    setState(() {
      _loading = true;
      _error = null;
      _mapShops.clear();
      _selectedShop = null;
      _coordsDone = 0;
      _coordsTotal = 0;
      _clearRouteState();
    });

    try {
      await _getMyLocation(silent: true);

      final shops = await _loadAllShops();

      if (!mounted) return;

      setState(() {
        _coordsTotal = shops.length;
      });

      const batchSize = 5;

      for (int i = 0;
          i < shops.length;
          i += batchSize) {
        final end =
            (i + batchSize < shops.length)
                ? i + batchSize
                : shops.length;

        final batch =
            shops.sublist(i, end);

        final results =
            await Future.wait(
          batch.map(_resolveShop),
        );

        if (!mounted) return;

        for (final item in results) {
          if (item != null) {
            _mapShops.add(item);
          }
        }

        setState(() {
          _coordsDone = end;
        });
      }

      _sortByDistance();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        _fitAll();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<Shop>> _loadAllShops()
      async {
    final result = <Shop>[];
    var page = 1;

    while (page <= 50) {
      final response =
          await _api.getShops(
        page: page,
        meta: page == 1,
      );

      if (page == 1 &&
          response
              .businessTypes.isNotEmpty) {
        _businessTypes =
            response.businessTypes;
      }

      result.addAll(response.shops);

      if (!response.hasMore) {
        break;
      }

      page++;
    }

    return result;
  }

  Future<_MapShop?> _resolveShop(
    Shop shop,
  ) async {
    final point =
        await _locationService
            .resolveShop(shop);

    if (point == null) {
      return null;
    }

    double? distance;

    if (_myLocation != null) {
      distance =
          _locationService.distanceMeters(
        from: _myLocation!,
        to: point,
      );
    }

    return _MapShop(
      shop: shop,
      point: point,
      distanceMeters: distance,
    );
  }

  Future<void> _getMyLocation({
    bool silent = false,
  }) async {
    if (!silent) {
      setState(() {
        _gettingLocation = true;
        _locationMessage = null;
      });
    }

    try {
      final point =
          await _locationService
              .getCurrentLocation(
        requestPermission: true,
      );

      if (!mounted) return;

      setState(() {
        _myLocation = point;
        _gettingLocation = false;

        if (point == null) {
          _locationMessage =
              'Location چالاک نییە یان مۆڵەت نەدراوە';
        } else {
          _locationMessage = null;
        }
      });

      if (point != null) {
        _recalculateDistances();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _gettingLocation = false;
        _locationMessage =
            'نەتوانرا شوێنەکەت بدۆزرێتەوە';
      });
    }
  }

  List<_MapShop> get _filteredShops {
    Iterable<_MapShop> items = _mapShops;

    final search =
        _searchText.trim().toLowerCase();

    if (search.isNotEmpty) {
      items = items.where((item) {
        return item.shop.name
                .toLowerCase()
                .contains(search) ||
            (item.shop.bio ?? '')
                .toLowerCase()
                .contains(search) ||
            item.shop.location
                .toLowerCase()
                .contains(search);
      });
    }

    if (_selectedBusinessType.isNotEmpty) {
      BusinessTypeOption? selected;

      for (final type in _businessTypes) {
        if (type.filterValue ==
            _selectedBusinessType) {
          selected = type;
          break;
        }
      }

      if (selected != null) {
        items = items.where(
          (item) => selected!.matches(
            item.shop.businessType,
          ),
        );
      }
    }

    final bounds = _areaBounds;

    if (bounds != null) {
      items = items.where(
        (item) =>
            bounds.contains(item.point),
      );
    }

    return items.toList();
  }

  void _recalculateDistances() {
    final location = _myLocation;

    if (location == null) return;

    for (final item in _mapShops) {
      item.distanceMeters =
          _locationService.distanceMeters(
        from: location,
        to: item.point,
      );
    }

    _sortByDistance();
  }

  void _sortByDistance() {
    _mapShops.sort((a, b) {
      final da = a.distanceMeters;
      final db = b.distanceMeters;

      if (da == null && db == null) {
        return 0;
      }

      if (da == null) return 1;
      if (db == null) return -1;

      return da.compareTo(db);
    });
  }

  void _fitAll() {
    if (!_mapReady) return;

    final visible =
        _filteredShops;

    final points = <LatLng>[
      if (_myLocation != null)
        _myLocation!,
      ...visible.map((e) => e.point),
    ];

    if (points.isEmpty) {
      _mapController.move(
        _fallbackCenter,
        12,
      );
      return;
    }

    if (points.length == 1) {
      _mapController.move(
        points.first,
        15,
      );
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding:
            const EdgeInsets.fromLTRB(
          45,
          190,
          45,
          220,
        ),
        maxZoom: 15,
      ),
    );
  }

  void _goToMe() {
    if (_myLocation == null) {
      _getMyLocation().then((_) {
        if (_myLocation != null &&
            mounted) {
          _mapController.move(
            _myLocation!,
            16,
          );
        }
      });

      return;
    }

    _mapController.move(
      _myLocation!,
      16,
    );
  }

  void _selectNearest() {
    if (_myLocation == null) {
      _goToMe();
      return;
    }

    final candidates =
        _filteredShops.where(
      (item) =>
          item.distanceMeters != null,
    );

    if (candidates.isEmpty) return;

    final nearest =
        candidates.reduce((a, b) {
      return a.distanceMeters! <=
              b.distanceMeters!
          ? a
          : b;
    });

    _selectShop(nearest);
  }

  void _selectShop(_MapShop shop) {
    setState(() {
      _selectedShop = shop;
    });

    _mapController.move(
      shop.point,
      16,
    );
  }

  void _searchThisArea() {
    if (!_mapReady) return;

    setState(() {
      _areaBounds =
          _mapController.camera.visibleBounds;
      _showSearchArea = false;
      _selectedShop = null;
    });
  }

  void _clearAreaFilter() {
    setState(() {
      _areaBounds = null;
      _showSearchArea = false;
    });

    _fitAll();
  }

  String _distanceText(
    double? meters,
  ) {
    if (meters == null) return '';

    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _openProfile(
    _MapShop shop,
  ) async {
    await showShopProfileSheet(
      context,
      shop.shop.slug,
      sourceShop: shop.shop,
    );

    await _loadFavorites();
  }

  Future<void> _toggleFavorite(
    Shop shop,
  ) async {
    final result =
        await _store.toggleFavorite(shop);

    if (!mounted) return;

    setState(() {
      if (result) {
        _favoriteIds.add(shop.id);
      } else {
        _favoriteIds.remove(shop.id);
      }
    });
  }

  Future<void> _drawRoute(
    _MapShop destination,
  ) async {
    if (_routing) return;

    if (_myLocation == null) {
      await _getMyLocation();

      if (_myLocation == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'بۆ دیاریکردنی ڕێگا پێویستە Location چالاک بێت',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _routing = true;
      _routeDestination = destination;
      _routePoints = [];
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
    });

    try {
      final result =
          await _routeService.getDrivingRoute(
        start: _myLocation!,
        end: destination.point,
      );

      if (!mounted) return;

      setState(() {
        _routePoints = result.points;
        _routeDistanceMeters =
            result.distanceMeters;
        _routeDurationSeconds =
            result.durationSeconds;
        _routing = false;
      });

      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        _fitRoute();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _clearRouteState();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  void _fitRoute() {
    if (!_mapReady ||
        _routePoints.length < 2) {
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _routePoints,
        padding:
            const EdgeInsets.fromLTRB(
          45,
          190,
          45,
          270,
        ),
        maxZoom: 17,
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _clearRouteState();
    });
  }

  void _clearRouteState() {
    _routePoints = [];
    _routeDistanceMeters = null;
    _routeDurationSeconds = null;
    _routeDestination = null;
    _routing = false;
  }

  String _routeDistanceText() {
    final meters =
        _routeDistanceMeters;

    if (meters == null) return '';

    if (meters < 1000) {
      return '${meters.round()} مەتر';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _routeDurationText() {
    final seconds =
        _routeDurationSeconds;

    if (seconds == null) return '';

    final minutes =
        (seconds / 60).ceil();

    if (minutes < 60) {
      return '$minutes خولەک';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (remaining == 0) {
      return '$hours کاتژمێر';
    }

    return '$hours کاتژمێر و $remaining خولەک';
  }

  List<Marker> _buildShopMarkers() {
    return _filteredShops.map((item) {
      return Marker(
        point: item.point,
        width: 66,
        height: 74,
        alignment:
            Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {
            _selectShop(item);
          },
          child: _ShopMarker(
            shop: item.shop,
            selected:
                _selectedShop == item ||
                    _routeDestination == item,
          ),
        ),
      );
    }).toList();
  }

  double get _bottomBase {
    return widget.embedded ? 92 : 34;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final center =
        _myLocation ?? _fallbackCenter;
    final markers =
        _buildShopMarkers();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
                minZoom: 3,
                maxZoom: 19,
                onMapReady: () {
                  _mapReady = true;

                  if (_routePoints
                      .isNotEmpty) {
                    _fitRoute();
                  } else {
                    _fitAll();
                  }
                },
                onPositionChanged:
                    (camera, hasGesture) {
                  if (hasGesture &&
                      !_loading) {
                    setState(() {
                      _showSearchArea =
                          true;
                    });
                  }
                },
                onTap: (_, __) {
                  if (_selectedShop !=
                      null) {
                    setState(() {
                      _selectedShop = null;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.nizik.nizik_native',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points:
                            _routePoints,
                        color: _green,
                        strokeWidth: 7,
                        borderStrokeWidth: 3,
                        borderColor:
                            Colors.white,
                      ),
                    ],
                  ),
                MarkerClusterLayerWidget(
                  options:
                      MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size:
                        const Size(46, 46),
                    alignment:
                        Alignment.center,
                    padding:
                        const EdgeInsets.all(
                      40,
                    ),
                    maxZoom: 15,
                    markers: markers,
                    builder:
                        (context, cluster) {
                      return Container(
                        decoration:
                            BoxDecoration(
                          color: _green,
                          shape:
                              BoxShape.circle,
                          border: Border.all(
                            color:
                                Colors.white,
                            width: 3,
                          ),
                          boxShadow:
                              const [
                            BoxShadow(
                              color: Color(
                                0x44000000,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            cluster.length
                                .toString(),
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                MarkerLayer(
                  markers: [
                    if (_myLocation != null)
                      Marker(
                        point:
                            _myLocation!,
                        width: 58,
                        height: 58,
                        child:
                            const _UserLocationMarker(),
                      ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text(
                    'OpenStreetMap contributors',
                  ),
                  alignment:
                      Alignment.bottomRight,
                ),
              ],
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  0,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (!widget.embedded) ...[
                          _RoundButton(
                            icon: Icons
                                .arrow_forward_rounded,
                            onTap: () {
                              Navigator.pop(
                                context,
                              );
                            },
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                        ],
                        Expanded(
                          child: Container(
                            height: 50,
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 12,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                17,
                              ),
                              boxShadow:
                                  const [
                                BoxShadow(
                                  color: Color(
                                    0x220F172A,
                                  ),
                                  blurRadius:
                                      22,
                                  offset:
                                      Offset(
                                    0,
                                    7,
                                  ),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller:
                                  _searchController,
                              onChanged:
                                  (value) {
                                setState(() {
                                  _searchText =
                                      value;
                                  _selectedShop =
                                      null;
                                });
                              },
                              decoration:
                                  const InputDecoration(
                                hintText:
                                    'لەسەر ماپ بگەڕێ...',
                                border:
                                    InputBorder
                                        .none,
                                prefixIcon:
                                    Icon(
                                  Icons
                                      .search_rounded,
                                  color:
                                      _green,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_businessTypes
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child:
                            ListView.separated(
                          scrollDirection:
                              Axis.horizontal,
                          itemCount:
                              _businessTypes
                                      .length +
                                  1,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(
                            width: 6,
                          ),
                          itemBuilder:
                              (context, index) {
                            if (index == 0) {
                              return _MapChip(
                                text: 'هەموو',
                                active:
                                    _selectedBusinessType
                                        .isEmpty,
                                onTap: () {
                                  setState(() {
                                    _selectedBusinessType =
                                        '';
                                    _selectedShop =
                                        null;
                                  });
                                },
                              );
                            }

                            final type =
                                _businessTypes[
                                    index -
                                        1];

                            return _MapChip(
                              text:
                                  '${type.icon} ${type.name}',
                              active:
                                  _selectedBusinessType ==
                                      type.filterValue,
                              onTap: () {
                                setState(() {
                                  _selectedBusinessType =
                                      type.filterValue;
                                  _selectedShop =
                                      null;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    if (_areaBounds != null) ...[
                      const SizedBox(height: 7),
                      Align(
                        alignment:
                            Alignment.centerRight,
                        child: _MapChip(
                          text:
                              '✕ فلتەری ئەم ناوچەیە',
                          active: true,
                          onTap:
                              _clearAreaFilter,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_showSearchArea)
              Positioned(
                top: _businessTypes.isEmpty
                    ? 78
                    : 125,
                left: 0,
                right: 0,
                child: Center(
                  child: SafeArea(
                    child: FilledButton.icon(
                      onPressed:
                          _searchThisArea,
                      icon: const Icon(
                        Icons
                            .manage_search_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'لەم ناوچەیە بگەڕێ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            _darkGreen,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              top: _businessTypes.isEmpty
                  ? 80
                  : 132,
              child: SafeArea(
                child: Column(
                  children: [
                    _RoundButton(
                      icon: Icons
                          .my_location_rounded,
                      loading:
                          _gettingLocation,
                      onTap: _goToMe,
                    ),
                    const SizedBox(height: 8),
                    _RoundButton(
                      icon: Icons
                          .near_me_rounded,
                      onTap:
                          _selectNearest,
                    ),
                    const SizedBox(height: 8),
                    _RoundButton(
                      icon:
                          _routePoints.isNotEmpty
                              ? Icons
                                  .route_rounded
                              : Icons
                                  .fit_screen_rounded,
                      onTap: _routePoints
                              .isNotEmpty
                          ? _fitRoute
                          : _fitAll,
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              Positioned(
                top: 170,
                right: 24,
                left: 24,
                child: _LoadingPanel(
                  done: _coordsDone,
                  total: _coordsTotal,
                ),
              ),
            if (_error != null)
              Positioned(
                top: 170,
                left: 18,
                right: 18,
                child: _ErrorPanel(
                  onRetry: _loadMap,
                ),
              ),
            if (_locationMessage != null)
              Positioned(
                top: 170,
                left: 18,
                right: 18,
                child: Container(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .location_off_rounded,
                        color: Colors.orange,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationMessage!,
                          style:
                              const TextStyle(
                            color: _ink,
                            fontSize: 10,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_routeDestination != null)
              Positioned(
                left: 12,
                right: 12,
                bottom:
                    _selectedShop != null
                        ? _bottomBase + 165
                        : _bottomBase,
                child: _RouteInfoCard(
                  shopName:
                      _routeDestination!
                          .shop.name,
                  distance:
                      _routeDistanceText(),
                  duration:
                      _routeDurationText(),
                  loading: _routing,
                  onFit: _fitRoute,
                  onClose: _clearRoute,
                ),
              ),
            if (_selectedShop != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: _bottomBase,
                child: _SelectedShopCard(
                  item: _selectedShop!,
                  distanceText:
                      _distanceText(
                    _selectedShop!
                        .distanceMeters,
                  ),
                  favorite:
                      _favoriteIds.contains(
                    _selectedShop!.shop.id,
                  ),
                  onFavorite: () {
                    _toggleFavorite(
                      _selectedShop!.shop,
                    );
                  },
                  onRoute: () {
                    _drawRoute(
                      _selectedShop!,
                    );
                  },
                  onProfile: () {
                    _openProfile(
                      _selectedShop!,
                    );
                  },
                  onClose: () {
                    setState(() {
                      _selectedShop = null;
                    });
                  },
                ),
              ),
            if (!_loading &&
                _error == null &&
                _filteredShops.isEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: _bottomBase + 30,
                child: Container(
                  padding:
                      const EdgeInsets.all(
                    18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: const Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons
                            .location_off_outlined,
                        color: _muted,
                        size: 34,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'هیچ دوکانێک لەم فلتەرەدا نەدۆزرایەوە',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapShop {
  final Shop shop;
  final LatLng point;
  double? distanceMeters;

  _MapShop({
    required this.shop,
    required this.point,
    this.distanceMeters,
  });
}

class _MapChip extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _MapChip({
    required this.text,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          active ? _green : Colors.white,
      borderRadius:
          BorderRadius.circular(999),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(999),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : _ink,
              fontSize: 9,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopMarker extends StatelessWidget {
  final Shop shop;
  final bool selected;

  const _ShopMarker({
    required this.shop,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final logo =
        normalizeNizikUrl(shop.logoUrl);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: selected
                  ? _darkGreen
                  : _green,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: selected ? 58 : 52,
          height: selected ? 58 : 52,
          margin:
              const EdgeInsets.only(
            bottom: 12,
          ),
          padding:
              const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected
                ? _darkGreen
                : _green,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color:
                    Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: logo.isEmpty
                ? const ColoredBox(
                    color: _softGreen,
                    child: Icon(
                      Icons
                          .storefront_rounded,
                      color: _green,
                      size: 25,
                    ),
                  )
                : Image.network(
                    logo,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return const ColoredBox(
                        color:
                            _softGreen,
                        child: Icon(
                          Icons
                              .storefront_rounded,
                          color: _green,
                          size: 25,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserLocationMarker
    extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                const BoxDecoration(
              color:
                  Color(0x33059669),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(
                    0x55000000,
                  ),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedShopCard
    extends StatelessWidget {
  final _MapShop item;
  final String distanceText;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onRoute;
  final VoidCallback onProfile;
  final VoidCallback onClose;

  const _SelectedShopCard({
    required this.item,
    required this.distanceText,
    required this.favorite,
    required this.onFavorite,
    required this.onRoute,
    required this.onProfile,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final logo =
        normalizeNizikUrl(
      item.shop.logoUrl,
    );

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color:
              const Color(0x110F172A),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            clipBehavior:
                Clip.antiAlias,
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),
            child: logo.isEmpty
                ? const Icon(
                    Icons
                        .storefront_rounded,
                    color: _green,
                    size: 27,
                  )
                : Image.network(
                    logo,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return const Icon(
                        Icons
                            .storefront_rounded,
                        color: _green,
                        size: 27,
                      );
                    },
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  item.shop.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.shop.location,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                  ),
                ),
                if (distanceText
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'دووری: $distanceText',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onFavorite,
            visualDensity:
                VisualDensity.compact,
            icon: Icon(
              favorite
                  ? Icons
                      .favorite_rounded
                  : Icons
                      .favorite_border_rounded,
              color: favorite
                  ? Colors.red
                  : _green,
              size: 20,
            ),
          ),
          Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: onRoute,
                style:
                    FilledButton.styleFrom(
                  backgroundColor: _green,
                  minimumSize:
                      const Size(66, 34),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                  ),
                ),
                child: const Text(
                  'ڕێگا',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              OutlinedButton(
                onPressed: onProfile,
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  minimumSize:
                      const Size(66, 34),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                  ),
                ),
                child: const Text(
                  'پڕۆفایل',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w900,
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

class _RouteInfoCard
    extends StatelessWidget {
  final String shopName;
  final String distance;
  final String duration;
  final bool loading;
  final VoidCallback onFit;
  final VoidCallback onClose;

  const _RouteInfoCard({
    required this.shopName,
    required this.distance,
    required this.duration,
    required this.loading,
    required this.onFit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              const Color(0x110F172A),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: loading
          ? const Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 3,
                    color: _green,
                  ),
                ),
                SizedBox(width: 11),
                Text(
                  'ڕێگاکە دیاری دەکرێت...',
                  style: TextStyle(
                    color: _ink,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _softGreen,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: _green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        shopName,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        '$distance  •  $duration',
                        style:
                            const TextStyle(
                          color: _green,
                          fontSize: 9,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onFit,
                  icon: const Icon(
                    Icons
                        .fit_screen_rounded,
                    color: _green,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _muted,
                  ),
                ),
              ],
            ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius:
            BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child:
                        CircularProgressIndicator(
                      color: _green,
                      strokeWidth: 2.5,
                    ),
                  )
                : Icon(
                    icon,
                    color: _ink,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final int done;
  final int total;

  const _LoadingPanel({
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    var text =
        'دوکانەکان بار دەکرێن...';

    if (total > 0) {
      text =
          'شوێنی دوکانەکان: $done / $total';
    }

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 21,
            height: 21,
            child:
                CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _green,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _ink,
                fontSize: 10,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorPanel({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'نەتوانرا ماپەکە بار بکرێت',
              style: TextStyle(
                color: _ink,
                fontSize: 10,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'دووبارە',
              style:
                  TextStyle(color: _green),
            ),
          ),
        ],
      ),
    );
  }
}

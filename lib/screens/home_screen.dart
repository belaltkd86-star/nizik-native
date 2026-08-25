import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/local_store_service.dart';
import '../services/shop_location_service.dart';
import 'shop_profile_sheet.dart';

const green = Color(0xFF059669);
const darkGreen = Color(0xFF047857);
const softGreen = Color(0xFFECFDF5);
const ink = Color(0xFF0F172A);
const muted = Color(0xFF64748B);
const lineColor = Color(0xFFE2E8F0);
const background = Color(0xFFF8FAFC);

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenMap;

  const HomeScreen({
    super.key,
    required this.onOpenMap,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final LocalStoreService _store =
      LocalStoreService.instance;
  final ShopLocationService _locationService =
      ShopLocationService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  Timer? _debounce;

  List<Shop> _shops = [];
  List<Shop> _recent = [];
  List<CityOption> _cities = [];
  List<RegionOption> _regions = [];
  List<BusinessTypeOption> _businessTypes = [];

  final Map<int, double> _distanceById = {};
  Set<int> _favoriteIds = {};

  LatLng? _myLocation;

  int _selectedCityId = 0;
  int _selectedRegionId = 0;
  String _selectedBusinessType = '';

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _findingLocation = false;

  int _page = 1;
  int _total = 0;
  int _requestId = 0;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadLocalData();
    _loadShops(
      reset: true,
      meta: true,
    );
    _prepareLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalData() async {
    final favorites =
        await _store.getFavoriteIds();
    final recent = await _store.getRecent();

    if (!mounted) return;

    setState(() {
      _favoriteIds = favorites;
      _recent = recent;
    });
  }

  Future<void> _prepareLocation() async {
    if (_findingLocation) return;

    setState(() {
      _findingLocation = true;
    });

    try {
      final point =
          await _locationService.getCurrentLocation(
        requestPermission: true,
      );

      if (!mounted) return;

      setState(() {
        _myLocation = point;
        _findingLocation = false;
      });

      if (point != null) {
        await _resolveDistances(_shops);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _findingLocation = false;
      });
    }
  }

  Future<void> _loadShops({
    required bool reset,
    bool meta = false,
  }) async {
    final requestId = ++_requestId;

    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      if (_loadingMore || !_hasMore) return;

      setState(() {
        _loadingMore = true;
      });
    }

    final requestedPage =
        reset ? 1 : _page + 1;

    try {
      final response =
          await _api.getShops(
        search: _searchController.text,
        cityId: _selectedCityId,
        regionId: _selectedRegionId,
        businessType:
            _selectedBusinessType,
        page: requestedPage,
        meta: meta,
      );

      if (!mounted ||
          requestId != _requestId) {
        return;
      }

      final newShops = response.shops;

      setState(() {
        if (reset) {
          _shops = [...newShops];
          _distanceById.clear();
        } else {
          _shops.addAll(newShops);
        }

        _page = response.page;
        _hasMore = response.hasMore;

        if (reset) {
          _total =
              response.total ??
                  response.shops.length;
        }

        if (response.cities.isNotEmpty) {
          _cities = response.cities;
        }

        if (response.regions.isNotEmpty) {
          _regions = response.regions;
        }

        if (response
            .businessTypes.isNotEmpty) {
          _businessTypes =
              response.businessTypes;
        }

        _loading = false;
        _loadingMore = false;
        _error = null;
      });

      if (_myLocation != null) {
        await _resolveDistances(
          reset ? _shops : newShops,
        );
      }
    } catch (e) {
      if (!mounted ||
          requestId != _requestId) {
        return;
      }

      setState(() {
        _loading = false;
        _loadingMore = false;

        if (reset) {
          _error = e.toString();
        }
      });
    }
  }

  Future<void> _resolveDistances(
    List<Shop> shops,
  ) async {
    final me = _myLocation;

    if (me == null || shops.isEmpty) {
      return;
    }

    const batchSize = 5;

    for (int i = 0;
        i < shops.length;
        i += batchSize) {
      final end =
          (i + batchSize < shops.length)
              ? i + batchSize
              : shops.length;

      final batch = shops.sublist(i, end);

      final results = await Future.wait(
        batch.map((shop) async {
          final point =
              await _locationService
                  .resolveShop(shop);

          if (point == null) {
            return MapEntry(shop.id, null);
          }

          final distance =
              _locationService.distanceMeters(
            from: me,
            to: point,
          );

          return MapEntry(
            shop.id,
            distance,
          );
        }),
      );

      if (!mounted) return;

      setState(() {
        for (final entry in results) {
          final distance = entry.value;

          if (distance != null) {
            _distanceById[entry.key] =
                distance;
          }
        }

        _sortByNearest();
      });
    }
  }

  void _sortByNearest() {
    if (_myLocation == null) return;

    _shops.sort((a, b) {
      final da = _distanceById[a.id];
      final db = _distanceById[b.id];

      if (da == null && db == null) {
        return 0;
      }

      if (da == null) return 1;
      if (db == null) return -1;

      return da.compareTo(db);
    });
  }

  String _distanceText(Shop shop) {
    final meters = _distanceById[shop.id];

    if (meters == null) return '';

    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _onSearchChanged(
    String value,
  ) {
    _debounce?.cancel();

    setState(() {});

    _debounce = Timer(
      const Duration(milliseconds: 450),
      () {
        _loadShops(
          reset: true,
        );
      },
    );
  }

  List<RegionOption> get _visibleRegions {
    if (_selectedCityId == 0) {
      return _regions;
    }

    return _regions
        .where(
          (region) =>
              region.cityId ==
              _selectedCityId,
        )
        .toList();
  }

  String _businessTypeName(
    String raw,
  ) {
    for (final type in _businessTypes) {
      if (type.matches(raw)) {
        return type.name;
      }
    }

    return raw.isEmpty ? 'دوکان' : raw;
  }

  Future<void> _toggleFavorite(
    Shop shop,
  ) async {
    final nowFavorite =
        await _store.toggleFavorite(shop);

    if (!mounted) return;

    setState(() {
      if (nowFavorite) {
        _favoriteIds.add(shop.id);
      } else {
        _favoriteIds.remove(shop.id);
      }
    });
  }

  Future<void> _openProfile(
    Shop shop,
  ) async {
    if (shop.slug.isEmpty) return;

    await showShopProfileSheet(
      context,
      shop.slug,
      sourceShop: shop,
    );

    await _loadLocalData();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onMapTap: widget.onOpenMap,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: green,
                  onRefresh: () async {
                    await _loadLocalData();
                    await _loadShops(
                      reset: true,
                      meta: true,
                    );
                  },
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      110,
                    ),
                    children: [
                      const _HeroCard(),
                      const SizedBox(height: 14),
                      _LocationStrip(
                        active:
                            _myLocation != null,
                        loading:
                            _findingLocation,
                        onTap: _prepareLocation,
                        onMap:
                            widget.onOpenMap,
                      ),
                      if (_recent.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _RecentSection(
                          shops: _recent,
                          onTap: _openProfile,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _FiltersCard(
                        searchController:
                            _searchController,
                        onSearchChanged:
                            _onSearchChanged,
                        cities: _cities,
                        regions:
                            _visibleRegions,
                        businessTypes:
                            _businessTypes,
                        selectedCityId:
                            _selectedCityId,
                        selectedRegionId:
                            _selectedRegionId,
                        selectedBusinessType:
                            _selectedBusinessType,
                        onCityChanged:
                            (value) {
                          setState(() {
                            _selectedCityId =
                                value;
                            _selectedRegionId =
                                0;
                          });

                          _loadShops(
                            reset: true,
                          );
                        },
                        onRegionChanged:
                            (value) {
                          setState(() {
                            _selectedRegionId =
                                value;
                          });

                          _loadShops(
                            reset: true,
                          );
                        },
                        onBusinessChanged:
                            (value) {
                          setState(() {
                            _selectedBusinessType =
                                value;
                          });

                          _loadShops(
                            reset: true,
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _ResultsHeader(
                        count: _total,
                        nearest:
                            _myLocation != null,
                      ),
                      const SizedBox(height: 10),
                      if (_loading)
                        const _LoadingSkeleton()
                      else if (_error != null)
                        _ErrorBox(
                          onRetry: () {
                            _loadShops(
                              reset: true,
                              meta: true,
                            );
                          },
                        )
                      else if (_shops.isEmpty)
                        const _EmptyBox()
                      else ...[
                        for (final shop
                            in _shops)
                          Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 10,
                            ),
                            child: _ShopCard(
                              shop: shop,
                              typeName:
                                  _businessTypeName(
                                shop.businessType,
                              ),
                              distance:
                                  _distanceText(
                                shop,
                              ),
                              favorite:
                                  _favoriteIds
                                      .contains(
                                shop.id,
                              ),
                              onFavorite: () {
                                _toggleFavorite(
                                  shop,
                                );
                              },
                              onTap: () {
                                _openProfile(
                                  shop,
                                );
                              },
                            ),
                          ),
                        if (_hasMore)
                          Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              top: 6,
                            ),
                            child: SizedBox(
                              height: 48,
                              child:
                                  FilledButton(
                                onPressed:
                                    _loadingMore
                                        ? null
                                        : () {
                                            _loadShops(
                                              reset:
                                                  false,
                                            );
                                          },
                                style:
                                    FilledButton
                                        .styleFrom(
                                  backgroundColor:
                                      green,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      16,
                                    ),
                                  ),
                                ),
                                child:
                                    _loadingMore
                                        ? const SizedBox(
                                            width:
                                                20,
                                            height:
                                                20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth:
                                                  2,
                                              color:
                                                  Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'زیاتر پیشان بدە',
                                            style:
                                                TextStyle(
                                              fontWeight:
                                                  FontWeight.w900,
                                            ),
                                          ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onMapTap;

  const _TopBar({
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xF2FFFFFF),
        border: Border(
          bottom: BorderSide(
            color: Color(0x0F0F172A),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                begin: Alignment.topRight,
                end:
                    Alignment.bottomLeft,
                colors: [
                  Color(0xFF34D399),
                  green,
                  darkGreen,
                ],
              ),
              borderRadius:
                  BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color:
                      Color(0x40059669),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'نزیک',
                  style: TextStyle(
                    color: ink,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'دوکانە نزیکەکان بدۆزەرەوە',
                  style: TextStyle(
                    color:
                        Color(0xFF94A3B8),
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: softGreen,
            borderRadius:
                BorderRadius.circular(14),
            child: InkWell(
              onTap: onMapTap,
              borderRadius:
                  BorderRadius.circular(14),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.map_rounded,
                  color: green,
                  size: 23,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white,
            Color(0xFFF0FDF4),
          ],
        ),
        borderRadius:
            BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0x2410B981),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30059669),
            blurRadius: 45,
            spreadRadius: -24,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                color: Color(0xFF10B981),
                size: 9,
              ),
              SizedBox(width: 7),
              Text(
                'دوکان و بزنسەکان',
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text:
                      'شوێنی دڵخوازت\n',
                  style: TextStyle(
                    color: ink,
                  ),
                ),
                TextSpan(
                  text: 'لە نزیکت ',
                  style: TextStyle(
                    color: green,
                  ),
                ),
                TextSpan(
                  text: 'بدۆزەرەوە',
                  style: TextStyle(
                    color: ink,
                  ),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 27,
              height: 1.45,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'بە ناو، شار، ناوچە یان جۆری بزنس بگەڕێ و بە ئاسانی دوکانە نزیکەکان بدۆزەرەوە.',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              height: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationStrip
    extends StatelessWidget {
  final bool active;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback onMap;

  const _LocationStrip({
    required this.active,
    required this.loading,
    required this.onTap,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? softGreen
            : Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? const Color(0xFFD1FAE5)
              : lineColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : softGreen,
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: loading
                ? const Padding(
                    padding:
                        EdgeInsets.all(10),
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: green,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: green,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? 'دوکانەکان بە نزیکترین ڕیزکراون'
                      : 'شوێنت چالاک بکە',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active
                      ? 'دووری هەر دوکانێک لە تۆ نیشان دەدرێت'
                      : 'بۆ دۆزینەوەی نزیکترین دوکانەکان',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed:
                active ? onMap : onTap,
            child: Text(
              active ? 'ماپ' : 'چالاککردن',
              style: const TextStyle(
                color: green,
                fontWeight:
                    FontWeight.w900,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSection
    extends StatelessWidget {
  final List<Shop> shops;
  final Future<void> Function(Shop) onTap;

  const _RecentSection({
    required this.shops,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shown =
        shops.take(8).toList();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'دوا جار بینراوەکان',
          style: TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length,
            separatorBuilder:
                (_, __) =>
                    const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final shop = shown[index];
              final logo =
                  normalizeNizikUrl(
                shop.logoUrl,
              );

              return GestureDetector(
                onTap: () {
                  onTap(shop);
                },
                child: Container(
                  width: 105,
                  padding:
                      const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    border: Border.all(
                      color: lineColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        clipBehavior:
                            Clip.antiAlias,
                        decoration:
                            BoxDecoration(
                          color: softGreen,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),
                        ),
                        child: logo.isEmpty
                            ? const Icon(
                                Icons
                                    .storefront_rounded,
                                color:
                                    green,
                              )
                            : Image.network(
                                logo,
                                fit: BoxFit
                                    .cover,
                                errorBuilder:
                                    (_, __,
                                        ___) {
                                  return const Icon(
                                    Icons
                                        .storefront_rounded,
                                    color:
                                        green,
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        shop.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color: ink,
                          fontSize: 9,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final TextEditingController
      searchController;

  final ValueChanged<String>
      onSearchChanged;

  final List<CityOption> cities;
  final List<RegionOption> regions;
  final List<BusinessTypeOption>
      businessTypes;

  final int selectedCityId;
  final int selectedRegionId;
  final String selectedBusinessType;

  final ValueChanged<int>
      onCityChanged;
  final ValueChanged<int>
      onRegionChanged;
  final ValueChanged<String>
      onBusinessChanged;

  const _FiltersCard({
    required this.searchController,
    required this.onSearchChanged,
    required this.cities,
    required this.regions,
    required this.businessTypes,
    required this.selectedCityId,
    required this.selectedRegionId,
    required this.selectedBusinessType,
    required this.onCityChanged,
    required this.onRegionChanged,
    required this.onBusinessChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFAFFFFFF),
        borderRadius:
            BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0x0F0F172A),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 38,
            spreadRadius: -22,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller:
                searchController,
            onChanged:
                onSearchChanged,
            textDirection:
                TextDirection.rtl,
            decoration: InputDecoration(
              hintText:
                  'گەڕان بە ناوی دوکان...',
              hintTextDirection:
                  TextDirection.rtl,
              hintStyle:
                  const TextStyle(
                color:
                    Color(0xFF94A3B8),
                fontSize: 11,
              ),
              prefixIcon:
                  const Icon(
                Icons.search_rounded,
                color: muted,
                size: 21,
              ),
              suffixIcon:
                  searchController
                          .text.isEmpty
                      ? null
                      : IconButton(
                          icon:
                              const Icon(
                            Icons
                                .close_rounded,
                            size: 18,
                          ),
                          onPressed: () {
                            searchController
                                .clear();
                            onSearchChanged(
                              '',
                            );
                          },
                        ),
              filled: true,
              fillColor: background,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                borderSide:
                    const BorderSide(
                  color: lineColor,
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                borderSide:
                    const BorderSide(
                  color: lineColor,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                borderSide:
                    const BorderSide(
                  color: green,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child:
                    _FilterSelect<int>(
                  label: 'شار',
                  value:
                      selectedCityId,
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text(
                        'هەموو شارەکان',
                      ),
                    ),
                    ...cities.map(
                      (city) =>
                          DropdownMenuItem(
                        value: city.id,
                        child: Text(
                          city.name,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onCityChanged(
                        value,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child:
                    _FilterSelect<int>(
                  label: 'ناوچە',
                  value:
                      selectedRegionId,
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text(
                        'هەموو ناوچەکان',
                      ),
                    ),
                    ...regions.map(
                      (region) =>
                          DropdownMenuItem(
                        value:
                            region.id,
                        child: Text(
                          region.name,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onRegionChanged(
                        value,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _FilterSelect<String>(
            label: 'جۆری بزنس',
            value:
                selectedBusinessType,
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text(
                  'هەموو جۆرەکان',
                ),
              ),
              ...businessTypes.map(
                (type) =>
                    DropdownMenuItem(
                  value:
                      type.filterValue,
                  child: Text(
                    '${type.icon} ${type.name}',
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onBusinessChanged(
                  value,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _FilterSelect<T>
    extends StatelessWidget {
  final String label;
  final T value;

  final List<DropdownMenuItem<T>>
      items;

  final ValueChanged<T?> onChanged;

  const _FilterSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(
            right: 4,
            bottom: 6,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),
        Container(
          height: 47,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: lineColor,
            ),
          ),
          child:
              DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
              icon: const Icon(
                Icons
                    .keyboard_arrow_down_rounded,
                color: muted,
                size: 18,
              ),
              style: const TextStyle(
                color: ink,
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
              ),
              dropdownColor:
                  Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultsHeader
    extends StatelessWidget {
  final int count;
  final bool nearest;

  const _ResultsHeader({
    required this.count,
    required this.nearest,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                nearest
                    ? 'نزیکترین دوکانەکان'
                    : 'دوکانەکان',
                style: const TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                nearest
                    ? 'بەپێی دووری لە شوێنی تۆ'
                    : 'دوکان و بزنسە بەردەستەکان',
                style: const TextStyle(
                  color:
                      Color(0xFF94A3B8),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius:
                BorderRadius.circular(
              999,
            ),
          ),
          child: Text(
            '$count ئەنجام',
            style: const TextStyle(
              color: darkGreen,
              fontSize: 9,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Shop shop;
  final String typeName;
  final String distance;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  const _ShopCard({
    required this.shop,
    required this.typeName,
    required this.distance,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final logo = normalizeNizikUrl(shop.logoUrl);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFAFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0x0F0F172A),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: softGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: logo.isEmpty
                      ? const Icon(
                          Icons.storefront_rounded,
                          color: green,
                          size: 28,
                        )
                      : Image.network(
                          logo,
                          fit: BoxFit.cover,
                          frameBuilder: (
                            context,
                            child,
                            frame,
                            wasSynchronouslyLoaded,
                          ) {
                            if (wasSynchronouslyLoaded) {
                              return child;
                            }

                            return AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration:
                                  const Duration(milliseconds: 250),
                              child: child,
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.storefront_rounded,
                              color: green,
                              size: 28,
                            );
                          },
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              shop.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: softGreen,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              typeName,
                              style: const TextStyle(
                                color: darkGreen,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (distance.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                distance,
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              shop.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (shop.bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          shop.bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onFavorite,
                  tooltip:
                      favorite ? 'لابردن لە دڵخوازەکان' : 'زیادکردن بۆ دڵخوازەکان',
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(favorite),
                      color: favorite ? Colors.red : green,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton();

  @override
  State<_LoadingSkeleton> createState() =>
      _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar({
    required double width,
    required double height,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE7ECEF),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity =
            0.45 + (_controller.value * 0.45);

        return Opacity(
          opacity: opacity,
          child: Column(
            children: List.generate(
              4,
              (index) => Container(
                height: 92,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: lineColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7ECEF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          _bar(
                            width: double.infinity,
                            height: 10,
                          ),
                          const SizedBox(height: 9),
                          _bar(
                            width: 110,
                            height: 8,
                          ),
                          const SizedBox(height: 9),
                          _bar(
                            width: 150,
                            height: 7,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE7ECEF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class _ErrorBox
    extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBox({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Colors.redAccent,
            size: 38,
          ),
          const SizedBox(height: 10),
          const Text(
            'نەتوانرا دوکانەکان بهێنرێن',
            style: TextStyle(
              color: ink,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text(
              'دووبارە هەوڵبدە',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox
    extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 35,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.storefront_outlined,
            color:
                Color(0xFF94A3B8),
            size: 38,
          ),
          SizedBox(height: 12),
          Text(
            'هیچ دوکانێک نەدۆزرایەوە',
            style: TextStyle(
              color: ink,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

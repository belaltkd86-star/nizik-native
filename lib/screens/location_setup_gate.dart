import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/area_detection_service.dart';
import '../services/location_preference_service.dart';
import '../services/location_service.dart';
import '../services/shop_service.dart';

class LocationSetupGate extends StatefulWidget {
  const LocationSetupGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<LocationSetupGate> createState() => _LocationSetupGateState();
}

class _LocationSetupGateState extends State<LocationSetupGate> {
  final _locationPrefs = LocationPreferenceService.instance;

  ShopMetadata? _metadata;
  bool _loadingMetadata = true;
  bool _detecting = false;
  bool _manualMode = false;
  String? _error;
  int? _cityId;
  int? _regionId;

  @override
  void initState() {
    super.initState();
    if (!_locationPrefs.setupDone) {
      _loadMetadata();
    }
  }

  Future<void> _loadMetadata() async {
    try {
      final metadata = await ShopService.fetchMetadata();
      if (!mounted) return;
      setState(() {
        _metadata = metadata;
        _loadingMetadata = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMetadata = false;
      });
    }
  }

  List<ShopRegion> get _visibleRegions {
    final metadata = _metadata;
    if (metadata == null || _cityId == null) return const <ShopRegion>[];
    return metadata.regions.where((e) => e.cityId == _cityId).toList();
  }

  Future<void> _useAutomaticLocation() async {
    if (_detecting) return;

    setState(() {
      _detecting = true;
      _error = null;
    });

    try {
      final position = await LocationService.getCurrentLocation();
      final metadata = _metadata ?? await ShopService.fetchMetadata();
      final result = await AreaDetectionService.resolveFromPosition(
        position: position,
        metadata: metadata,
      );

      await _locationPrefs.saveAutomatic(
        latitude: position.latitude,
        longitude: position.longitude,
        city: result.city,
      );
      await _locationPrefs.markSetupDone();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _detecting = false);
      }
    }
  }

  Future<void> _saveManualLocation() async {
    final metadata = _metadata;
    if (metadata == null || _cityId == null) {
      setState(() => _error = 'تکایە شارێک هەڵبژێرە.');
      return;
    }

    ShopCity? city;
    for (final item in metadata.cities) {
      if (item.id == _cityId) {
        city = item;
        break;
      }
    }

    if (city == null) {
      setState(() => _error = 'شارە هەڵبژێردراوەکە نەدۆزرایەوە.');
      return;
    }

    ShopRegion? region;
    if (_regionId != null) {
      for (final item in metadata.regions) {
        if (item.id == _regionId) {
          region = item;
          break;
        }
      }
    }

    await _locationPrefs.saveManual(city: city, region: region);
    await _locationPrefs.markSetupDone();

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _skip() async {
    await _locationPrefs.markSetupDone();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_locationPrefs.setupDone) {
      return widget.child;
    }

    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(bottom: 22),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 44,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Text(
                      'شوێنەکەت ڕێکبخە',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'نزیک شوێنەکەت بەکار دەهێنێت بۆ ئەوەی تەنها دووکان و خزمەتگوزارییەکانی ناوچەکەت نیشان بدات. دەتوانیت دواتر لە سێتینگ بگۆڕیت.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: _detecting ? null : _useAutomaticLocation,
                      icon: _detecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.location_searching_rounded),
                      label: Text(
                        _detecting ? 'شوێن دەدۆزرێتەوە...' : 'شوێنم خۆکار بدۆزەوە',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loadingMetadata
                          ? null
                          : () => setState(() {
                                _manualMode = !_manualMode;
                                _error = null;
                              }),
                      icon: const Icon(Icons.edit_location_alt_rounded),
                      label: const Text('شوێن بە دەستی هەڵبژێرە'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                    if (_manualMode) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            DropdownButtonFormField<int?>(
                              value: _cityId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'شار',
                                prefixIcon: Icon(Icons.location_city_rounded),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('شار هەڵبژێرە'),
                                ),
                                ...(_metadata?.cities ?? const <ShopCity>[]).map(
                                  (city) => DropdownMenuItem<int?>(
                                    value: city.id,
                                    child: Text(city.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) => setState(() {
                                _cityId = value;
                                _regionId = null;
                              }),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              value: _regionId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'ناوچە (ئارەزوومەندانە)',
                                prefixIcon: Icon(Icons.place_outlined),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('هەموو ناوچەکانی شار'),
                                ),
                                ..._visibleRegions.map(
                                  (region) => DropdownMenuItem<int?>(
                                    value: region.id,
                                    child: Text(region.name),
                                  ),
                                ),
                              ],
                              onChanged: _cityId == null
                                  ? null
                                  : (value) => setState(() => _regionId = value),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _saveManualLocation,
                                child: const Text('پاشەکەوتکردنی شوێن'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _skip,
                      child: const Text('ئێستا نا — دواتر لە سێتینگ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

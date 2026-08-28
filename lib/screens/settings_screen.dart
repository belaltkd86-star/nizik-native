import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';
import '../services/area_detection_service.dart';
import '../services/contact_service.dart';
import '../services/location_preference_service.dart';
import '../services/location_service.dart';
import '../services/shop_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _instagramUsername = 'BILAL.REBWAR_';

  final _locationPrefs = LocationPreferenceService.instance;

  ShopMetadata? _metadata;
  bool _loadingMetadata = true;
  bool _detecting = false;
  String? _locationError;
  int? _cityId;
  int? _regionId;

  @override
  void initState() {
    super.initState();
    final current = _locationPrefs.preference.value;
    _cityId = current.cityId;
    _regionId = current.regionId;
    _locationPrefs.preference.addListener(_onPreferenceChanged);
    _loadMetadata();
  }

  @override
  void dispose() {
    _locationPrefs.preference.removeListener(_onPreferenceChanged);
    super.dispose();
  }

  void _onPreferenceChanged() {
    if (!mounted) return;
    final current = _locationPrefs.preference.value;
    setState(() {
      _cityId = current.cityId;
      _regionId = current.regionId;
    });
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
      setState(() => _loadingMetadata = false);
    }
  }

  List<ShopRegion> get _visibleRegions {
    final metadata = _metadata;
    if (metadata == null || _cityId == null) return const <ShopRegion>[];
    return metadata.regions.where((e) => e.cityId == _cityId).toList();
  }

  Future<void> _detectLocation() async {
    if (_detecting) return;
    setState(() {
      _detecting = true;
      _locationError = null;
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

      if (!mounted) return;
      if (result.city == null) {
        setState(() {
          _locationError =
              'GPS دۆزرایەوە، بەڵام شارەکە لە داتای دووکانەکانەوە دیاری نەکرا. دەتوانیت شار بە دەستی هەڵبژێریت.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _saveManualLocation() async {
    final metadata = _metadata;
    if (metadata == null || _cityId == null) {
      setState(() => _locationError = 'تکایە شارێک هەڵبژێرە.');
      return;
    }

    ShopCity? city;
    for (final item in metadata.cities) {
      if (item.id == _cityId) {
        city = item;
        break;
      }
    }

    if (city == null) return;

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
    if (!mounted) return;
    setState(() => _locationError = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('شوێن پاشەکەوت کرا.')),
    );
  }

  Future<void> _openUrl(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نەتوانرا لینکەکە بکرێتەوە')),
      );
    }
  }

  Future<void> _openInstagram() async {
    final appUri = Uri.parse(
      'instagram://user?username=${_instagramUsername.toLowerCase()}',
    );
    if (await canLaunchUrl(appUri)) {
      await _openUrl(appUri);
      return;
    }
    await _openUrl(
      Uri.parse('https://www.instagram.com/${_instagramUsername.toLowerCase()}/'),
    );
  }

  Future<void> _openWhatsApp() async {
    await _openUrl(NizikContactService.whatsappUri());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [
              const Text(
                'سێتینگ',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                'شوێن، ڕووکار و زانیارییەکانی نزیک لێرە ڕێکبخە.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _sectionTitle(context, 'شوێن'),
              const SizedBox(height: 10),
              ValueListenableBuilder<NizikLocationPreference>(
                valueListenable: _locationPrefs.preference,
                builder: (context, location, _) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _boxDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location.label,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    location.isAutomatic
                                        ? 'خۆکار بە GPS'
                                        : location.isManual
                                            ? 'هەڵبژاردنی دەستی'
                                            : 'هێشتا دیاری نەکراوە',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _detecting ? null : _detectLocation,
                          icon: _detecting
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(
                            _detecting ? 'شوێن دەدۆزرێتەوە...' : 'شوێنی ئێستا بەکاربهێنە',
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_loadingMetadata)
                          const LinearProgressIndicator()
                        else ...[
                          DropdownButtonFormField<int?>(
                            value: _cityId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'شار بگۆڕە',
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
                          const SizedBox(height: 10),
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
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _cityId == null ? null : _saveManualLocation,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('پاشەکەوتکردنی هەڵبژاردن'),
                          ),
                        ],
                        if (_locationError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _locationError!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'ڕووکار'),
              const SizedBox(height: 10),
              Container(
                decoration: _boxDecoration(context),
                child: SwitchListTile.adaptive(
                  value: theme.brightness == Brightness.dark,
                  onChanged: (value) => ThemeService.instance.setDark(value),
                  secondary: Icon(
                    theme.brightness == Brightness.dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'دارک مۆد',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('ڕووکار بۆ شەو و ڕۆژ بگۆڕە'),
                ),
              ),
              const SizedBox(height: 28),
              _sectionTitle(context, 'دەربارە'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _boxDecoration(context),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 34,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'نزیک',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نزیک بۆ دۆزینەوەی دووکان، خزمەتگوزاری و بازاڕی نزیک بە تۆ دروست کراوە.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _contactTile(
                context,
                icon: Icons.camera_alt_rounded,
                title: 'Instagram',
                value: _instagramUsername,
                onTap: _openInstagram,
              ),
              const SizedBox(height: 10),
              _contactTile(
                context,
                icon: Icons.chat_rounded,
                title: 'WhatsApp',
                value: NizikContactService.whatsappDisplay,
                onTap: _openWhatsApp,
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  '© نزیک',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }

  BoxDecoration _boxDecoration(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: theme.colorScheme.outlineVariant),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _boxDecoration(context),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

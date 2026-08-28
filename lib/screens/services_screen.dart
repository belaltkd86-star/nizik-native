import 'package:flutter/material.dart';

import '../models/app_feature.dart';
import '../models/module_spec.dart';
import '../services/app_config_service.dart';
import 'market_screen.dart';
import 'module_list_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final TextEditingController _searchController = TextEditingController();

  AppConfig? _config;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final config = await AppConfigService.fetch();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _query => _searchController.text.trim().toLowerCase();

  bool get _marketEnabled => _config?.isEnabled('market') ?? false;

  bool get _showMarket {
    if (!_marketEnabled) return false;
    if (_query.isEmpty) return true;
    return 'بازاڕ'.contains(_query) ||
        'کاڵا و شتە فرۆشیارییەکان'.contains(_query) ||
        'market'.contains(_query);
  }

  List<_ServiceEntry> get _serviceEntries {
    final config = _config;
    if (config == null) return const <_ServiceEntry>[];

    final entries = config.features
        .where((feature) => feature.group.toLowerCase() == 'services')
        .where((feature) {
          if (_query.isEmpty) return true;
          return feature.title.toLowerCase().contains(_query) ||
              feature.subtitle.toLowerCase().contains(_query) ||
              feature.key.toLowerCase().contains(_query);
        })
        .map(
          (feature) => _ServiceEntry(
            feature: feature,
            spec: ModuleRegistry.fromFeature(feature),
          ),
        )
        .toList();

    entries.sort(
      (a, b) => a.feature.sortOrder.compareTo(b.feature.sortOrder),
    );
    return entries;
  }

  int get _enabledCount {
    final config = _config;
    if (config == null) return 0;
    final moduleCount = config.features
        .where((feature) => feature.group.toLowerCase() == 'services')
        .length;
    return moduleCount + (_marketEnabled ? 1 : 0);
  }


  void _open(ModuleSpec spec) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModuleListScreen(spec: spec),
      ),
    );
  }

  void _openMarket() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MarketScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _serviceEntries;
    final totalVisible = entries.length + (_showMarket ? 1 : 0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  sliver: SliverToBoxAdapter(child: _buildHeader()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  sliver: SliverToBoxAdapter(child: _buildSearch()),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildError(),
                  )
                else if (totalVisible == 0)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          const Text(
                            'بەشە چالاکەکان',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '$totalVisible بەش',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final count = width >= 850
                            ? 3
                            : width >= 520
                                ? 2
                                : 1;

                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: count,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: count == 1 ? 2.9 : 1.75,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (_showMarket && index == 0) {
                                return _buildMarketCard();
                              }
                              final moduleIndex = index - (_showMarket ? 1 : 0);
                              return _buildModuleCard(entries[moduleIndex]);
                            },
                            childCount: totalVisible,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final count = _enabledCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B5D3B), Color(0xFF2E7D32)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0B5D3B),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'خزمەتگوزارییەکان',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'بەشەکان لە Admin و داتابەیسەوە کۆنتڕۆڵ دەکرێن'
                      : '$count بەشی چالاک لە داتابەیسەوە',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.5,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'گەڕان لە خزمەتگوزاری و بازاڕ...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  Widget _buildMarketCard() {
    return _serviceCard(
      emoji: '🛍️',
      title: 'بازاڕ',
      subtitle: 'کاڵا و شتە فرۆشیارییەکان ببینە و داواکاری بکە',
      badge: 'MARKET',
      onTap: _openMarket,
    );
  }

  Widget _buildModuleCard(_ServiceEntry entry) {
    return _serviceCard(
      emoji: entry.spec.emoji,
      title: entry.spec.title,
      subtitle: entry.spec.subtitle,
      onTap: () => _open(entry.spec),
    );
  }

  Widget _serviceCard({
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 27)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 52,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          const Text(
            'بەشەکان لۆد نەکران',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('دووبارە هەوڵ بدە'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.widgets_outlined,
            size: 54,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          const Text(
            'هیچ بەشێکی چالاک نییە',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            'لە Admin ـەوە بەشە پێویستەکان ON بکە.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ServiceEntry {
  final AppFeature feature;
  final ModuleSpec spec;

  const _ServiceEntry({
    required this.feature,
    required this.spec,
  });
}

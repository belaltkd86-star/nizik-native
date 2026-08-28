import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/market_item.dart';
import '../services/market_service.dart';
import '../services/favorites_service.dart';
import '../services/share_service.dart';
import '../widgets/report_sheet.dart';

class MarketDetailScreen extends StatefulWidget {
  final int itemId;

  const MarketDetailScreen({
    super.key,
    required this.itemId,
  });

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  late Future<MarketItemDetail> _future;
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = _fetchDetail();
  }


  Future<MarketItemDetail> _fetchDetail() async {
    return MarketService.fetchDetail(widget.itemId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _call(String phone) async {
    final uri = Uri(
      scheme: 'tel',
      path: phone,
    );

    if (!await launchUrl(uri)) {
      _showMessage('نەتوانرا پەیوەندی بکرێت.');
    }
  }

  Future<void> _openWhatsApp(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');

    final uri = Uri.parse(
      'https://wa.me/$cleanNumber',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      _showMessage('نەتوانرا WhatsApp بکرێتەوە.');
    }
  }


  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: FutureBuilder<MarketItemDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _DetailError(
                onRetry: () {
                  setState(() {
                    _future = _fetchDetail();
                  });
                },
              );
            }

            final item = snapshot.data!;

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 330,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  actions: [
                    ValueListenableBuilder(
                      valueListenable: FavoritesService.contentNotifier,
                      builder: (context, _, __) {
                        final favorite =
                            FavoritesService.isMarketFavorite(item.id);
                        return IconButton(
                          tooltip: favorite
                              ? 'لابردن لە دڵخواز'
                              : 'دڵخواز',
                          onPressed: () =>
                              FavoritesService.toggleMarketDetail(item),
                          icon: Icon(
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: favorite
                                ? const Color(0xFFE53935)
                                : null,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'هاوبەشکردن',
                      onPressed: () => NizikShareService.show(
                        context,
                        title: 'بازاڕ: ${item.title}',
                        link: NizikShareService.marketLink(item.id),
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                    IconButton(
                      tooltip: 'ڕاپۆرتکردن',
                      onPressed: () => ReportSheet.show(
                        context,
                        targetType: 'market_item',
                        targetId: item.id,
                      ),
                      icon: const Icon(Icons.flag_outlined),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _ImageGallery(
                      images: item.images,
                      controller: _pageController,
                      currentPage: _page,
                      onChanged: (index) {
                        setState(() => _page = index);
                      },
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(
                              text: item.conditionLabel,
                              icon: Icons.inventory_2_outlined,
                            ),
                            _Chip(
                              text: item.statusLabel,
                              icon: Icons.check_circle_outline,
                            ),
                            if (item.isFeatured)
                              const _Chip(
                                text: '⭐ تایبەت',
                                icon: Icons.star_outline,
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          item.priceLabel,
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 18),

                        _InfoCard(
                          icon: Icons.location_on_outlined,
                          title: 'شوێن',
                          value: item.locationLabel,
                        ),

                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'وردەکاری',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    height: 1.9,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        if (item.phone != null || item.whatsapp != null)
                          const SizedBox(height: 10),

                        Row(
                          children: [
                            if (item.phone != null)
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _call(item.phone!),
                                  icon: const Icon(
                                    Icons.phone_rounded,
                                  ),
                                  label: const Text('پەیوەندی'),
                                  style: FilledButton.styleFrom(
                                    minimumSize:
                                        const Size.fromHeight(52),
                                  ),
                                ),
                              ),

                            if (item.phone != null &&
                                item.whatsapp != null)
                              const SizedBox(width: 10),

                            if (item.whatsapp != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _openWhatsApp(item.whatsapp!),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                  ),
                                  label: const Text('WhatsApp'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize:
                                        const Size.fromHeight(52),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImageGallery extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onChanged;

  const _ImageGallery({
    required this.images,
    required this.controller,
    required this.currentPage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        color: const Color(0xFFEAF4EB),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 64,
            color: Color(0xFF7BA27F),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          itemCount: images.length,
          onPageChanged: onChanged,
          itemBuilder: (_, index) {
            return CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined),
              ),
            );
          },
        ),

        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: currentPage == index ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: currentPage == index
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Chip({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  final VoidCallback onRetry;

  const _DetailError({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            const Text(
              'وردەکاری کاڵاکە لۆد نەکرا.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('دووبارە هەوڵ بدەوە'),
            ),
          ],
        ),
      ),
    );
  }
}

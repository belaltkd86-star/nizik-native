import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';
import '../services/favorites_service.dart';
import '../services/shop_service.dart';
import '../widgets/report_sheet.dart';
import 'shop_map_screen.dart';

class ShopDetailScreen extends StatefulWidget {
  final String slug;

  const ShopDetailScreen({
    super.key,
    required this.slug,
  });

  @override
  State<ShopDetailScreen> createState() =>
      _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late Future<ShopDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = ShopService.fetchDetail(widget.slug);
  }

  Future<void> _reload() async {
    setState(() {
      _future = ShopService.fetchDetail(widget.slug);
    });
  }

  Future<void> _call(String phone) async {
    final uri = Uri(
      scheme: 'tel',
      path: phone,
    );

    final ok = await launchUrl(uri);

    if (!ok && mounted) {
      _message('نەتوانرا پەیوەندی بکرێت.');
    }
  }

  Future<void> _openSocial(ShopSocialLink social) async {
    var value = social.url.trim();

    if (value.isEmpty) return;

    if (!value.startsWith('http://') &&
        !value.startsWith('https://') &&
        !value.startsWith('tel:') &&
        !value.startsWith('mailto:')) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);

    if (uri == null) {
      _message('لینکەکە دروست نییە.');
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      _message('نەتوانرا لینکەکە بکرێتەوە.');
    }
  }

  void _openInternalMap(Shop shop) {
    if (shop.googleMapsUrl == null ||
        shop.googleMapsUrl!.trim().isEmpty) {
      _message('شوێنی دووکانەکە لە نەخشە دیاری نەکراوە.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopMapScreen(
          focusShop: shop,
        ),
      ),
    );
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

  IconData _socialIcon(String platform) {
    final value = platform.toLowerCase();

    if (value.contains('instagram')) {
      return Icons.camera_alt_outlined;
    }
    if (value.contains('facebook') ||
        value.contains('فەیسبووک')) {
      return Icons.facebook_rounded;
    }
    if (value.contains('whatsapp') ||
        value.contains('واتس')) {
      return Icons.chat_bubble_rounded;
    }
    if (value.contains('telegram') ||
        value.contains('تێلیگرام')) {
      return Icons.send_rounded;
    }
    if (value.contains('youtube')) {
      return Icons.play_circle_fill_rounded;
    }
    if (value.contains('tiktok')) {
      return Icons.music_note_rounded;
    }
    if (value.contains('phone') ||
        value.contains('mobile') ||
        value.contains('tel')) {
      return Icons.phone_rounded;
    }

    return Icons.link_rounded;
  }

  Future<void> _showSocialPopup(
    ShopDetail detail,
  ) async {
    if (detail.socialLinks.isEmpty) {
      _message('هیچ لینکی سۆشیال میدیا زیاد نەکراوە.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height =
            MediaQuery.sizeOf(sheetContext).height;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: height * 0.72,
              ),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF8),
                borderRadius: BorderRadius.circular(30),
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
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF16A34A),
                                Color(0xFF047857),
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.alternate_email_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سۆشیال میدیا',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'ڕێگای پەیوەندی لەگەڵ دووکان',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext),
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.55,
                      ),
                      itemCount: detail.socialLinks.length,
                      itemBuilder: (context, index) {
                        final social =
                            detail.socialLinks[index];

                        return Material(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(20),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _openSocial(social);
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration:
                                        BoxDecoration(
                                      color: const Color(
                                        0xFFE8F5E9,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(
                                        15,
                                      ),
                                    ),
                                    child: Icon(
                                      _socialIcon(
                                        social.platform,
                                      ),
                                      color: const Color(
                                        0xFF15803D,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          social.label,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .w900,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 3,
                                        ),
                                        const Text(
                                          'کردنەوە',
                                          style: TextStyle(
                                            color:
                                                Colors.black45,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: FavoritesService.notifier,
        builder: (context, favorites, _) {
          final isFavorite =
              favorites.contains(widget.slug);

          return Scaffold(
            backgroundColor: const Color(0xFFF3F7F4),
            body: FutureBuilder<ShopDetail>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState !=
                    ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return _ProfileError(
                    message: snapshot.error
                            ?.toString()
                            .replaceFirst(
                              'Exception: ',
                              '',
                            ) ??
                        'پڕۆفایل لۆد نەکرا.',
                    onRetry: _reload,
                  );
                }

                final detail = snapshot.data!;
                final shop = detail.shop;

                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 285,
                      backgroundColor:
                          const Color(0xFF065F46),
                      foregroundColor: Colors.white,
                      actions: [
                        IconButton(
                          tooltip: 'ڕاپۆرتکردن',
                          onPressed: () => ReportSheet.show(
                            context,
                            targetType: 'shop',
                            targetId: shop.id,
                            targetSlug: shop.slug,
                          ),
                          icon: const Icon(
                            Icons.flag_outlined,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: 'دڵخواز',
                          onPressed: () =>
                              FavoritesService.toggle(
                            shop.slug,
                          ),
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons
                                    .favorite_border_rounded,
                            color: isFavorite
                                ? const Color(0xFFFFE4E6)
                                : Colors.white,
                          ),
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: _ProfileHero(
                          shop: shop,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          18,
                          16,
                          28,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            _QuickActions(
                              hasPhone:
                                  shop.phone != null,
                              hasMap:
                                  shop.googleMapsUrl != null &&
                                      shop.googleMapsUrl!
                                          .trim()
                                          .isNotEmpty,
                              hasSocial:
                                  detail.socialLinks.isNotEmpty,
                              onCall: shop.phone == null
                                  ? null
                                  : () => _call(
                                        shop.phone!,
                                      ),
                              onMap: () =>
                                  _openInternalMap(shop),
                              onSocial: () =>
                                  _showSocialPopup(
                                detail,
                              ),
                            ),

                            if (detail.workingHours !=
                                null) ...[
                              const SizedBox(height: 14),
                              _InfoCard(
                                icon:
                                    Icons.schedule_rounded,
                                title: 'کاتی کارکردن',
                                text:
                                    detail.workingHours!,
                              ),
                            ],

                            if (shop.bio != null) ...[
                              const SizedBox(height: 14),
                              _InfoCard(
                                icon:
                                    Icons.auto_awesome_rounded,
                                title:
                                    'دەربارەی دووکان',
                                text: shop.bio!,
                              ),
                            ],

                            const SizedBox(height: 24),

                            if (detail.menuItems.isEmpty &&
                                detail.socialLinks.isNotEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F6EA),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.alternate_email_rounded,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'سۆشیال میدیا',
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'ئەم دووکانە مێنیوی نییە؛ ڕێگاکانی پەیوەندی لێرەن',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _InlineSocialLinks(
                                links: detail.socialLinks,
                                onTap: _openSocial,
                                iconFor: _socialIcon,
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F6EA),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.restaurant_menu_rounded,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'مێنۆ و بەرهەمەکان',
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'بەشێک بکەرەوە بۆ بینینی ئایتمەکان',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _MenuCategories(
                                detail: detail,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final Shop shop;

  const _ProfileHero({
    required this.shop,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (shop.logoUrl != null)
          CachedNetworkImage(
            imageUrl: shop.logoUrl!,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                Container(
              color: const Color(0xFF047857),
            ),
          )
        else
          Container(
            color: const Color(0xFF047857),
          ),

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0xAA064E3B),
                Color(0xFF064E3B),
              ],
              stops: [
                0,
                0.55,
                1,
              ],
            ),
          ),
        ),

        Positioned(
          right: 20,
          left: 20,
          bottom: 24,
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black26,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(24),
                  child: shop.logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl:
                              shop.logoUrl!,
                          fit: BoxFit.cover,
                          errorWidget:
                              (_, __, ___) =>
                                  const _HeroLogoFallback(),
                        )
                      : const _HeroLogoFallback(),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      shop.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    width: 22,
                    height: 22,
                    decoration:
                        const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    icon:
                        Icons.storefront_rounded,
                    text: shop.typeLabel,
                  ),
                  _HeroChip(
                    icon:
                        Icons.location_on_rounded,
                    text: shop.locationLabel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.16,
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.16,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
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

class _QuickActions extends StatelessWidget {
  final bool hasPhone;
  final bool hasMap;
  final bool hasSocial;
  final VoidCallback? onCall;
  final VoidCallback onMap;
  final VoidCallback onSocial;

  const _QuickActions({
    required this.hasPhone,
    required this.hasMap,
    required this.hasSocial,
    required this.onCall,
    required this.onMap,
    required this.onSocial,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.phone_rounded,
            label: 'پەیوەندی',
            enabled: hasPhone,
            onTap: onCall,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ActionCard(
            icon: Icons.map_rounded,
            label: 'نەخشە',
            enabled: hasMap,
            onTap: hasMap ? onMap : null,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ActionCard(
            icon:
                Icons.alternate_email_rounded,
            label: 'سۆشیال',
            enabled: hasSocial,
            onTap:
                hasSocial ? onSocial : null,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? Colors.white
          : const Color(0xFFF1F3F2),
      borderRadius:
          BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius:
            BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: const Color(
                0xFFE8EEE9,
              ),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(
                          0xFFE6F6EA,
                        )
                      : Colors.black12,
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? const Color(
                          0xFF15803D,
                        )
                      : Colors.black26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 12,
                  color: enabled
                      ? const Color(
                          0xFF17211A,
                        )
                      : Colors.black26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              const Color(0xFFE8EEE9),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFE6F6EA),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFF15803D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.75,
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

class _InlineSocialLinks extends StatelessWidget {
  final List<ShopSocialLink> links;
  final ValueChanged<ShopSocialLink> onTap;
  final IconData Function(String platform) iconFor;

  const _InlineSocialLinks({
    required this.links,
    required this.onTap,
    required this.iconFor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: links.map((social) {
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onTap(social),
            child: Container(
              constraints: const BoxConstraints(minWidth: 145),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE8EEE9),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F6EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconFor(social.platform),
                      color: const Color(0xFF15803D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      social.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MenuCategories extends StatelessWidget {
  final ShopDetail detail;

  const _MenuCategories({
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    if (detail.menuItems.isEmpty) {
      return const _EmptyMenu(
        text:
            'هێشتا هیچ مێنیو یان بەرهەمێک زیاد نەکراوە.',
      );
    }

    if (detail.categories.isEmpty) {
      return _MenuCategoryCard(
        title: 'هەموو بەرهەمەکان',
        icon: '🛍️',
        items: detail.menuItems,
        initiallyExpanded: true,
      );
    }

    final cards = <Widget>[];

    for (var i = 0;
        i < detail.categories.length;
        i++) {
      final category =
          detail.categories[i];

      final items = detail.menuItems
          .where(
            (item) =>
                item.categoryId ==
                category.id,
          )
          .toList();

      cards.add(
        _MenuCategoryCard(
          title: category.name,
          icon: category.icon,
          items: items,
          initiallyExpanded: i == 0,
        ),
      );
    }

    final knownIds = detail.categories
        .map((category) => category.id)
        .toSet();

    final uncategorized = detail.menuItems
        .where(
          (item) =>
              item.categoryId == null ||
              !knownIds.contains(
                item.categoryId,
              ),
        )
        .toList();

    if (uncategorized.isNotEmpty) {
      cards.add(
        _MenuCategoryCard(
          title: 'بەرهەمی تر',
          icon: '✨',
          items: uncategorized,
        ),
      );
    }

    return Column(
      children: cards,
    );
  }
}

class _MenuCategoryCard extends StatelessWidget {
  final String title;
  final String icon;
  final List<ShopMenuItem> items;
  final bool initiallyExpanded;

  const _MenuCategoryCard({
    required this.title,
    required this.icon,
    required this.items,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              const Color(0xFFE8EEE9),
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Color(0x0A000000),
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(
          'menu-$title',
        ),
        initiallyExpanded:
            initiallyExpanded,
        maintainState: true,
        tilePadding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 4,
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12,
        ),
        shape: const Border(),
        collapsedShape:
            const Border(),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(
              colors: [
                Color(0xFFEAF9EF),
                Color(0xFFDDF4E4),
              ],
            ),
            borderRadius:
                BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              icon.trim().isEmpty
                  ? '•'
                  : icon,
              style:
                  const TextStyle(
                fontSize: 21,
              ),
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${items.length} ئایتم',
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 11,
          ),
        ),
        children: items.isEmpty
            ? const [
                Padding(
                  padding:
                      EdgeInsets.all(16),
                  child: Text(
                    'هێشتا هیچ ئایتمێک لەم بەشەدا نییە.',
                    style: TextStyle(
                      color:
                          Colors.black45,
                    ),
                  ),
                ),
              ]
            : items
                .map(
                  (item) => _MenuItemCard(
                    item: item,
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final ShopMenuItem item;

  const _MenuItemCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF7FAF8),
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(14),
            child: SizedBox(
              width: 78,
              height: 78,
              child: item.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl:
                          item.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget:
                          (_, __, ___) =>
                              const _MenuImageFallback(),
                    )
                  : const _MenuImageFallback(),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                if (item.description !=
                    null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.black45,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                if (item.price !=
                    null) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFE6F6EA,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        99,
                      ),
                    ),
                    child: Text(
                      item.priceLabel,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF15803D,
                        ),
                        fontWeight:
                            FontWeight
                                .w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuImageFallback extends StatelessWidget {
  const _MenuImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE6F6EA),
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF15803D),
      ),
    );
  }
}

class _HeroLogoFallback extends StatelessWidget {
  const _HeroLogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE6F6EA),
      child: const Icon(
        Icons.storefront_rounded,
        size: 44,
        color: Color(0xFF15803D),
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  final String text;

  const _EmptyMenu({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: Colors.black26,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ProfileError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                size: 60,
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
      ),
    );
  }
}

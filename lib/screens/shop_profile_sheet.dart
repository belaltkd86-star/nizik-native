import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/local_store_service.dart';

const _green = Color(0xFF059669);
const _darkGreen = Color(0xFF047857);
const _softGreen = Color(0xFFECFDF5);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _background = Color(0xFFF8FAFC);

Future<void> showShopProfileSheet(
  BuildContext context,
  String slug, {
  Shop? sourceShop,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) {
      return ShopProfileSheet(
        slug: slug,
        sourceShop: sourceShop,
      );
    },
  );
}

class ShopProfileSheet extends StatefulWidget {
  final String slug;
  final Shop? sourceShop;

  const ShopProfileSheet({
    super.key,
    required this.slug,
    this.sourceShop,
  });

  @override
  State<ShopProfileSheet> createState() =>
      _ShopProfileSheetState();
}

class _ShopProfileSheetState
    extends State<ShopProfileSheet> {
  final ApiService _api = ApiService();
  final LocalStoreService _store =
      LocalStoreService.instance;

  ShopProfileData? _profile;
  bool _loading = true;
  bool _favorite = false;
  String? _error;

  int? _selectedCategoryId;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile =
          await _api.getPublicProfile(widget.slug);

      final shop =
          widget.sourceShop ?? profile.toShop();

      await _store.addRecent(shop);
      final favorite =
          await _store.isFavorite(shop);

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _favorite = favorite;

        if (profile.categories.isNotEmpty) {
          _selectedCategoryId =
              profile.categories.first.categoryId;
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final profile = _profile;

    if (profile == null) return;

    final shop =
        widget.sourceShop ?? profile.toShop();

    final result =
        await _store.toggleFavorite(shop);

    if (!mounted) return;

    setState(() {
      _favorite = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? 'زیاد کرا بۆ دڵخوازەکان'
              : 'لە دڵخوازەکان لابرا',
        ),
        duration:
            const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _openExternal(
    String value,
  ) async {
    var raw = value.trim();

    if (raw.isEmpty) return;

    if (!raw.contains(':')) {
      if (RegExp(r'^[+0-9 ]+$').hasMatch(raw)) {
        raw = 'tel:${raw.replaceAll(' ', '')}';
      } else {
        raw = 'https://$raw';
      }
    }

    final uri = Uri.tryParse(raw);

    if (uri == null) return;

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'نەتوانرا بەستەرەکە بکرێتەوە',
          ),
        ),
      );
    }
  }

  Future<void> _openSocial(
    SocialLink social,
  ) async {
    final platform =
        social.platform.toLowerCase();
    final raw = social.url.trim();

    if (raw.isEmpty) return;

    if (platform.contains('whatsapp') ||
        platform.contains('واتس')) {
      if (RegExp(r'^[+0-9 ()-]+$')
          .hasMatch(raw)) {
        final number =
            raw.replaceAll(RegExp(r'[^0-9]'), '');

        await _openExternal(
          'https://wa.me/$number',
        );
        return;
      }
    }

    if (platform.contains('phone') ||
        platform.contains('mobile') ||
        platform.contains('tel') ||
        platform.contains('تەلەفۆن') ||
        platform.contains('مۆبایل')) {
      final number =
          raw.replaceAll(RegExp(r'[^0-9+]'), '');

      await _openExternal('tel:$number');
      return;
    }

    await _openExternal(
      normalizeNizikUrl(raw),
    );
  }

  Future<void> _shareProfile() async {
    final link =
        'https://my-pro.click/public/?p=${Uri.encodeComponent(widget.slug)}';

    await Clipboard.setData(
      ClipboardData(text: link),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'لینکی پڕۆفایل کۆپی کرا',
        ),
      ),
    );
  }

  void _openGallery(
    List<String> images,
    int initialIndex,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) {
        return _GalleryViewer(
          images: images,
          initialIndex: initialIndex,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.sizeOf(context).height * 0.94;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(30),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _SheetHeader(
              favorite: _favorite,
              onFavorite: _profile == null
                  ? null
                  : _toggleFavorite,
              onClose: () {
                Navigator.of(context).pop();
              },
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const _ProfileLoadingSkeleton();
    }

    if (_error != null || _profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'نەتوانرا پڕۆفایلەکە بهێنرێت',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'دووبارە هەوڵبدە',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;
    final gallery = profile.galleryUrls;

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _ProfileHero(
            profile: profile,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              18,
              16,
              30,
            ),
            child: Column(
              children: [
                _QuickActions(
                  hasMap:
                      profile.googleMapsUrl.isNotEmpty,
                  onMap: profile.googleMapsUrl.isEmpty
                      ? null
                      : () {
                          _openExternal(
                            normalizeNizikUrl(
                              profile.googleMapsUrl,
                            ),
                          );
                        },
                  onShare: _shareProfile,
                  onContact:
                      profile.socialLinks.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _selectedTab = 1;
                              });
                            },
                ),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _BioSection(
                    bio: profile.bio,
                  ),
                ],
                if (gallery.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _GallerySection(
                    images: gallery,
                    onTap: _openGallery,
                  ),
                ],
                const SizedBox(height: 18),
                _ProfileTabs(
                  selected: _selectedTab,
                  onChanged: (index) {
                    setState(() {
                      _selectedTab = index;
                    });
                  },
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.025),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _selectedTab == 0
                      ? KeyedSubtree(
                          key: const ValueKey('menu'),
                          child: _buildMenu(profile),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('contact'),
                          child: _ContactSection(
                            links: profile.socialLinks,
                            onOpen: _openSocial,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(
    ShopProfileData profile,
  ) {
    if (profile.categories.isEmpty) {
      if (profile.items.isEmpty) {
        return const _EmptySection(
          icon: Icons.shopping_bag_outlined,
          text:
              'هێشتا هیچ مێنۆ یان بەرهەمێک زیاد نەکراوە.',
        );
      }

      return Column(
        children: [
          for (final item in profile.items)
            Padding(
              padding:
                  const EdgeInsets.only(bottom: 10),
              child: _MenuItemCard(
                item: item,
                onImageTap: item.imageUrl.isEmpty
                    ? null
                    : () {
                        final url =
                            normalizeNizikUrl(
                          item.imageUrl,
                        );

                        if (url.isNotEmpty) {
                          _openGallery([url], 0);
                        }
                      },
              ),
            ),
        ],
      );
    }

    final selectedId =
        _selectedCategoryId ??
            profile.categories.first.categoryId;

    final items = profile.items
        .where(
          (item) =>
              item.categoryId == selectedId,
        )
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 45,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: profile.categories.length,
            separatorBuilder: (_, __) {
              return const SizedBox(width: 8);
            },
            itemBuilder: (context, index) {
              final category =
                  profile.categories[index];

              final active =
                  category.categoryId == selectedId;

              return ChoiceChip(
                selected: active,
                showCheckmark: false,
                selectedColor: _green,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color:
                      active ? _green : _line,
                ),
                label: Text(
                  '${category.icon.isEmpty ? '•' : category.icon} ${category.name}',
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedCategoryId =
                        category.categoryId;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _EmptySection(
            icon: Icons.inventory_2_outlined,
            text: 'لەم بەشەدا بەرهەم نییە.',
          )
        else
          ...items.map(
            (item) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 10),
              child: _MenuItemCard(
                item: item,
                onImageTap: item.imageUrl.isEmpty
                    ? null
                    : () {
                        final url =
                            normalizeNizikUrl(
                          item.imageUrl,
                        );

                        if (url.isNotEmpty) {
                          _openGallery([url], 0);
                        }
                      },
              ),
            ),
          ),
      ],
    );
  }
}


class _ProfileLoadingSkeleton extends StatefulWidget {
  const _ProfileLoadingSkeleton();

  @override
  State<_ProfileLoadingSkeleton> createState() =>
      _ProfileLoadingSkeletonState();
}

class _ProfileLoadingSkeletonState
    extends State<_ProfileLoadingSkeleton>
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

  Widget _block({
    required double height,
    double? width,
    double radius = 16,
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
        final opacity = 0.45 + (_controller.value * 0.45);

        return Opacity(
          opacity: opacity,
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 260,
                color: const Color(0xFFD7E9E2),
                padding: const EdgeInsets.all(22),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block(
                      width: 72,
                      height: 72,
                      radius: 22,
                    ),
                    const SizedBox(height: 14),
                    _block(
                      width: 190,
                      height: 17,
                    ),
                    const SizedBox(height: 9),
                    _block(
                      width: 130,
                      height: 10,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _block(height: 92, radius: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _block(height: 92, radius: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _block(height: 92, radius: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _block(height: 110, radius: 22),
                    const SizedBox(height: 16),
                    _block(height: 48, radius: 16),
                    const SizedBox(height: 12),
                    _block(height: 92, radius: 20),
                    const SizedBox(height: 10),
                    _block(height: 92, radius: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.favorite,
    required this.onFavorite,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        8,
        6,
        8,
        6,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
            ),
          ),
          const Spacer(),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius:
                  BorderRadius.circular(999),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onFavorite,
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
                color: favorite ? Colors.red : _green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final ShopProfileData profile;

  const _ProfileHero({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final logo =
        normalizeNizikUrl(profile.logoUrl);

    return SizedBox(
      height: 290,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (logo.isNotEmpty)
            Image.network(
              logo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: _darkGreen,
                );
              },
            )
          else
            Container(
              color: _darkGreen,
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99047857),
                  Color(0xF2059669),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        const Color(0x33FFFFFF),
                    borderRadius:
                        BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          const Color(0x55FFFFFF),
                    ),
                  ),
                  child: const Text(
                    '●  نزیک • پڕۆفایلی دوکان',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 76,
                  height: 76,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: logo.isEmpty
                      ? const Icon(
                          Icons.storefront_rounded,
                          color: _green,
                          size: 36,
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
                              size: 36,
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name.isEmpty
                            ? 'دوکان'
                            : profile.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      decoration:
                          const BoxDecoration(
                        color:
                            Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${profile.businessTypeIcon} ${profile.businessTypeName}',
                  style: const TextStyle(
                    color: Color(0xFFE6FFFA),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (profile
                    .locationText.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons
                            .location_on_outlined,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          profile.locationText,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
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

class _QuickActions extends StatelessWidget {
  final bool hasMap;
  final VoidCallback? onMap;
  final VoidCallback onShare;
  final VoidCallback? onContact;

  const _QuickActions({
    required this.hasMap,
    required this.onMap,
    required this.onShare,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (hasMap)
        _ActionCard(
          icon: Icons.location_on_rounded,
          label: 'شوێنی دوکان',
          value: 'ڕێگا بۆ دوکان',
          onTap: onMap,
        ),
      _ActionCard(
        icon: Icons.ios_share_rounded,
        label: 'پڕۆفایل',
        value: 'هاوبەشکردن',
        onTap: onShare,
      ),
      if (onContact != null)
        _ActionCard(
          icon: Icons.chat_bubble_rounded,
          label: 'پەیوەندی',
          value: 'پەیوەندی بکە',
          onTap: onContact,
        ),
    ];

    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          for (int i = 0;
              i < actions.length;
              i++) ...[
            Expanded(
              child: actions[i],
            ),
            if (i != actions.length - 1)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: _line,
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: _green,
                  size: 19,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BioSection extends StatelessWidget {
  final String bio;

  const _BioSection({
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _line,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: _green,
                size: 18,
              ),
              SizedBox(width: 7),
              Text(
                'دەربارەی دوکان',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bio,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              height: 1.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  final List<String> images;
  final void Function(
    List<String> images,
    int index,
  ) onTap;

  const _GallerySection({
    required this.images,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'وێنەکان',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 9),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  onTap(images, index);
                },
                child: Container(
                  width: 112,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: _softGreen,
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: _line,
                    ),
                  ),
                  child: Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return const Icon(
                        Icons.image_not_supported,
                        color: _muted,
                      );
                    },
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

class _ProfileTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _ProfileTabs({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              text: '🛍️ بەرهەم و مێنۆ',
              active: selected == 0,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _TabButton(
              text: '🔗 پەیوەندی',
              active: selected == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.text,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? _green : _muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback? onImageTap;

  const _MenuItemCard({
    required this.item,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final image =
        normalizeNizikUrl(item.imageUrl);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _line,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          if (image.isNotEmpty) ...[
            GestureDetector(
              onTap: onImageTap,
              child: Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) {
                    return const Icon(
                      Icons
                          .restaurant_menu_rounded,
                      color: _green,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                if (item
                    .description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.price.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: _softGreen,
                borderRadius:
                    BorderRadius.circular(999),
              ),
              child: Text(
                item.price,
                style: const TextStyle(
                  color: _darkGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final List<SocialLink> links;
  final Future<void> Function(
    SocialLink social,
  ) onOpen;

  const _ContactSection({
    required this.links,
    required this.onOpen,
  });

  IconData _iconFor(
    String platform,
  ) {
    final name = platform.toLowerCase();

    if (name.contains('instagram')) {
      return Icons.camera_alt_rounded;
    }

    if (name.contains('whatsapp') ||
        name.contains('واتس')) {
      return Icons.chat_rounded;
    }

    if (name.contains('telegram') ||
        name.contains('تێلیگرام')) {
      return Icons.send_rounded;
    }

    if (name.contains('tiktok')) {
      return Icons.music_note_rounded;
    }

    if (name.contains('phone') ||
        name.contains('mobile') ||
        name.contains('tel') ||
        name.contains('مۆبایل') ||
        name.contains('تەلەفۆن')) {
      return Icons.phone_rounded;
    }

    if (name.contains('facebook')) {
      return Icons.facebook_rounded;
    }

    return Icons.link_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const _EmptySection(
        icon: Icons.link_off_rounded,
        text:
            'هیچ بەستەری پەیوەندییەک زیاد نەکراوە.',
      );
    }

    return Column(
      children: [
        for (final social in links)
          Padding(
            padding:
                const EdgeInsets.only(bottom: 9),
            child: Material(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(18),
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(18),
                onTap: () {
                  onOpen(social);
                },
                child: Container(
                  padding:
                      const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(18),
                    border:
                        Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration:
                            BoxDecoration(
                          color: _softGreen,
                          borderRadius:
                              BorderRadius
                                  .circular(13),
                        ),
                        child: Icon(
                          _iconFor(
                            social.platform,
                          ),
                          color: _green,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'پەیوەندی',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 8,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              social.platform
                                      .isEmpty
                                  ? 'Link'
                                  : social
                                      .platform,
                              style:
                                  const TextStyle(
                                color: _ink,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: Color(
                          0xFF94A3B8,
                        ),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptySection({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _line,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _GalleryViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_GalleryViewer> createState() =>
      _GalleryViewerState();
}

class _GalleryViewerState
    extends State<_GalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _index = index;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) {
                        return const Icon(
                          Icons
                              .broken_image_outlined,
                          color: Colors.white70,
                          size: 64,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Text(
                '${_index + 1} / ${widget.images.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

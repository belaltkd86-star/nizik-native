import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/module_item.dart';
import '../models/module_spec.dart';
import '../security/nizik_network.dart';
import '../services/module_service.dart';
import '../services/favorites_service.dart';
import '../services/share_service.dart';

class ModuleDetailScreen extends StatefulWidget {
  final ModuleSpec spec;
  final int itemId;
  final ModuleItem? initialItem;

  const ModuleDetailScreen({
    super.key,
    required this.spec,
    required this.itemId,
    this.initialItem,
  });

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  ModuleItem? _item;
  bool _loading = true;
  String? _error;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final item = await ModuleService.fetchDetail(
        widget.spec,
        widget.itemId,
      );

      if (!mounted) return;

      setState(() {
        _item = item;
        _loading = false;
      });
      try {
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _call(String phone) async {
    final value = phone.trim();
    if (value.isEmpty) return;

    final uri = Uri(
      scheme: 'tel',
      path: value,
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _whatsapp(String phone) async {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    if (digits.startsWith('0')) {
      digits = '964${digits.substring(1)}';
    }

    final uri = Uri.parse('https://wa.me/$digits');

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }


  Future<void> _openExternal(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return;

    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'https' &&
            uri.scheme.toLowerCase() != 'http')) {
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Text(
            widget.spec.title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          actions: [
            if (item != null)
              ValueListenableBuilder(
                valueListenable: FavoritesService.contentNotifier,
                builder: (context, _, __) {
                  final favorite = FavoritesService.isModuleFavorite(
                    widget.spec.key,
                    item.id,
                  );
                  return IconButton(
                    tooltip: favorite ? 'لابردن لە دڵخواز' : 'دڵخواز',
                    onPressed: () => FavoritesService.toggleModule(
                      widget.spec,
                      item,
                    ),
                    icon: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorite ? const Color(0xFFE53935) : null,
                    ),
                  );
                },
              ),
            if (item != null)
              IconButton(
                tooltip: 'هاوبەشکردن',
                onPressed: () => NizikShareService.show(
                  context,
                  title: '${widget.spec.title}: ${item.title}',
                  link: NizikShareService.moduleLink(widget.spec.key, item.id),
                ),
                icon: const Icon(Icons.ios_share_rounded),
              ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: item == null
            ? _buildInitialState()
            : _buildContent(item),
      ),
    );
  }

  Widget _buildInitialState() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Color(0xFFD65A5A),
            ),
            const SizedBox(height: 14),
            Text(
              _error ?? 'وردەکاری داتاکە لۆد نەکرا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      ),
    );
  }

  Widget _buildContent(ModuleItem item) {
    final images = item.imageUrls
        .map(NizikEndpoints.normalizeUrl)
        .where((url) => url.isNotEmpty)
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
        children: [
          _buildMedia(item, images),
          const SizedBox(height: 14),
          _buildTitleCard(item),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _buildStaleWarning(),
          ],
          const SizedBox(height: 14),
          _buildDetailsCard(item),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDescription(item),
          ],
          if (item.address.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildAddress(item),
          ],
          const SizedBox(height: 14),
          _buildActions(item),
        ],
      ),
    );
  }

  Widget _buildMedia(
    ModuleItem item,
    List<String> images,
  ) {
    if (images.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFE8F5E9),
              Color(0xFFF4FAF4),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          widget.spec.emoji,
          style: const TextStyle(fontSize: 68),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          SizedBox(
            height: 245,
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() => _imageIndex = index);
              },
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  fadeInDuration: const Duration(milliseconds: 160),
                  placeholder: (_, __) => Container(
                    color: const Color(0xFFEAF0EA),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFFEAF0EA),
                    alignment: Alignment.center,
                    child: Text(
                      widget.spec.emoji,
                      style: const TextStyle(fontSize: 54),
                    ),
                  ),
                );
              },
            ),
          ),
          if (images.length > 1)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${_imageIndex + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (item.featured)
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6A609),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'پێشنیارکراو',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleCard(ModuleItem item) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: const Color(0xFFE8EDE8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  widget.spec.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1.35,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (item.verified)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Tooltip(
                              message: 'پشتڕاستکراوە',
                              child: Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF2E9BFF),
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF2E7D32),
                size: 18,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  item.locationLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4D5C50),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaleWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFB77900),
            size: 19,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'داتای پاشەکەوتکراو پیشان دەدرێت؛ نوێکردنەوە سەرکەوتوو نەبوو.',
              style: TextStyle(
                color: Color(0xFF7D5A00),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(ModuleItem item) {
    final rows = <Widget>[];

    for (final field in widget.spec.detailFields) {
      if (const <String>{
        'phone',
        'whatsapp',
        'external_url',
        'address_detail',
      }.contains(field.key)) {
        continue;
      }

      final value = field.format(
        item.value(field.key),
        currency: item.currency,
      );

      if (value.isEmpty) continue;

      rows.add(_infoRow(field.label, value));
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: const Color(0xFFE8EDE8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'زانیاری',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(ModuleItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: const Color(0xFFE8EDE8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'وردەکاری',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddress(ModuleItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.place_outlined,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ناونیشانی ورد',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.address,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ModuleItem item) {
    final buttons = <Widget>[];

    if (item.phone.isNotEmpty) {
      buttons.add(
        _actionButton(
          icon: Icons.call_rounded,
          label: 'پەیوەندی',
          onPressed: () => _call(item.phone),
        ),
      );
    }

    if (item.whatsapp.isNotEmpty) {
      buttons.add(
        _actionButton(
          icon: Icons.chat_rounded,
          label: 'WhatsApp',
          onPressed: () => _whatsapp(item.whatsapp),
        ),
      );
    }

    if (item.externalUrl.isNotEmpty) {
      buttons.add(
        _actionButton(
          icon: Icons.open_in_new_rounded,
          label: 'لینک',
          onPressed: () => _openExternal(item.externalUrl),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B5D3B),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: buttons,
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B5D3B),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

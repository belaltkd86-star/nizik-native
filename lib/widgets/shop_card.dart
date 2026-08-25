import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/shop.dart';

class ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  const ShopCard({
    super.key,
    required this.shop,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: shop.logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: shop.logoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const _ShopImageFallback(),
                          errorWidget: (_, __, ___) =>
                              const _ShopImageFallback(),
                        )
                      : const _ShopImageFallback(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      shop.typeLabel,
                      style: const TextStyle(
                        color: Color(0xFF43A047),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            shop.locationLabel,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: isFavorite
                    ? 'لابردن لە دڵخوازەکان'
                    : 'زیادکردن بۆ دڵخوازەکان',
                onPressed: onFavoriteTap,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? const Color(0xFFE53935)
                      : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopImageFallback extends StatelessWidget {
  const _ShopImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: const Icon(
        Icons.storefront_rounded,
        size: 34,
        color: Color(0xFF43A047),
      ),
    );
  }
}

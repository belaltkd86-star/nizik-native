import 'package:flutter/material.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationText = 'شوێن دیاری نەکراوە';

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    final position = await LocationService.getCurrentLocation();

    if (!mounted) return;

    setState(() {
      if (position == null) {
        _locationText = 'ڕێگە بە Location نەدراوە';
      } else {
        _locationText =
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF43A047),
                  child: Icon(Icons.storefront_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'نزیک',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _locationText,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _requestLocation,
                  icon: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF43A047),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'گەڕان بە ناوی دووکان...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'بەشەکان',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 95,
              child: ListView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                children: const [
                  CategoryItem(icon: Icons.restaurant, title: 'خواردنگە'),
                  CategoryItem(icon: Icons.local_cafe, title: 'کافێ'),
                  CategoryItem(icon: Icons.shopping_cart, title: 'مارکێت'),
                  CategoryItem(icon: Icons.checkroom, title: 'جلوبەرگ'),
                  CategoryItem(icon: Icons.store, title: 'گشتی'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'دووکانە نزیکەکان',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            const ShopCard(
              name: 'دووکانی نموونە',
              type: 'خواردنگە',
              distance: '1.2 km',
            ),
            const ShopCard(
              name: 'کافێی نموونە',
              type: 'کافێ',
              distance: '2.4 km',
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const CategoryItem({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      margin: const EdgeInsets.only(left: 10),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: const Color(0xFF43A047)),
          ),
          const SizedBox(height: 8),
          Text(title, textDirection: TextDirection.rtl),
        ],
      ),
    );
  }
}

class ShopCard extends StatelessWidget {
  final String name;
  final String type;
  final String distance;

  const ShopCard({
    super.key,
    required this.name,
    required this.type,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storefront,
              color: Color(0xFF43A047),
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  type,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      distance,
                      style: const TextStyle(
                        color: Color(0xFF43A047),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.location_on,
                      size: 17,
                      color: Color(0xFF43A047),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

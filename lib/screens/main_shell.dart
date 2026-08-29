import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'market_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'shop_map_screen.dart';
import 'shops_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goTo(int index) {
    setState(() => _index = index);
  }

  void _openMarket() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MarketScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        onOpenMarket: _openMarket,
        onOpenMap: () => _goTo(1),
        onOpenShops: () => _goTo(2),
        onOpenServices: () => _goTo(3),
      ),
      ShopMapScreen(autoLocate: _index == 1),
      const ShopsScreen(),
      const ServicesScreen(),
      const SettingsScreen(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'سەرەکی',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'نەخشە',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'دووکانەکان',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'خزمەتگوزاری',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'سێتینگ',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'about_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'market_screen.dart';
import 'shop_map_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        onOpenMarket: () => _goTo(2),
      ),
      const ShopMapScreen(),
      const MarketScreen(),
      const FavoritesScreen(),
      const AboutScreen(),
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
              icon: Icon(
                Icons.shopping_bag_outlined,
              ),
              selectedIcon: Icon(
                Icons.shopping_bag_rounded,
              ),
              label: 'بازاڕ',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.favorite_border_rounded,
              ),
              selectedIcon: Icon(
                Icons.favorite_rounded,
              ),
              label: 'دڵخوازەکان',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.info_outline_rounded,
              ),
              selectedIcon: Icon(
                Icons.info_rounded,
              ),
              label: 'دەربارە',
            ),
          ],
        ),
      ),
    );
  }
}

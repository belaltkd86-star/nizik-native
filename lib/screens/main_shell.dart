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

  void _goTo(int index) => setState(() => _index = index);

  void _openMarket() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    const destinations = <({IconData icon, IconData selected, String label})>[
      (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'سەرەکی'),
      (icon: Icons.map_outlined, selected: Icons.map_rounded, label: 'نەخشە'),
      (icon: Icons.storefront_outlined, selected: Icons.storefront_rounded, label: 'دووکان'),
      (icon: Icons.grid_view_outlined, selected: Icons.grid_view_rounded, label: 'خزمەتگوزاری'),
      (icon: Icons.settings_outlined, selected: Icons.settings_rounded, label: 'سێتینگ'),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .98),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? .28 : .10),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: List.generate(destinations.length, (i) {
                final item = destinations[i];
                final selected = _index == i;
                return Expanded(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label: item.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _goTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? item.selected : item.icon,
                              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                              size: 21,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                fontSize: 8.7,
                                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

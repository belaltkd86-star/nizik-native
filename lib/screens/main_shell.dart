import 'package:flutter/material.dart';

import '../theme/nizik_theme.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _favoritesRefresh = 0;

  void _selectTab(int index) {
    if (_index == index) return;

    setState(() {
      _index = index;

      if (index == 2) {
        _favoritesRefresh++;
      }
    });
  }

  Widget _animatedPage({
    required int index,
    required Widget child,
  }) {
    final active = _index == index;

    return IgnorePointer(
      ignoring: !active,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: NizikMotion.normal,
        curve: NizikMotion.curve,
        child: AnimatedScale(
          scale: active ? 1 : 0.985,
          duration: NizikMotion.normal,
          curve: NizikMotion.curve,
          child: Offstage(
            offstage: !active,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            _animatedPage(
              index: 0,
              child: HomeScreen(
                onOpenMap: () {
                  _selectTab(1);
                },
              ),
            ),
            _animatedPage(
              index: 1,
              child: const MapScreen(
                embedded: true,
              ),
            ),
            _animatedPage(
              index: 2,
              child: FavoritesScreen(
                refreshSignal: _favoritesRefresh,
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 28,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _selectTab,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(
                    Icons.home_outlined,
                    color: NizikColors.ink,
                  ),
                  selectedIcon: Icon(
                    Icons.home_rounded,
                    color: NizikColors.green,
                  ),
                  label: 'سەرەتا',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.map_outlined,
                    color: NizikColors.ink,
                  ),
                  selectedIcon: Icon(
                    Icons.map_rounded,
                    color: NizikColors.green,
                  ),
                  label: 'ماپ',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.favorite_border_rounded,
                    color: NizikColors.ink,
                  ),
                  selectedIcon: Icon(
                    Icons.favorite_rounded,
                    color: Colors.red,
                  ),
                  label: 'دڵخوازەکان',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

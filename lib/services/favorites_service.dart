import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  FavoritesService._();

  static const String _key = 'favorite_shop_slugs';

  static final ValueNotifier<Set<String>> notifier =
      ValueNotifier<Set<String>>(<String>{});

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? const <String>[];

    notifier.value = saved.toSet();
  }

  static bool isFavorite(String slug) {
    return notifier.value.contains(slug);
  }

  static Future<void> toggle(String slug) async {
    final next = Set<String>.from(notifier.value);

    if (next.contains(slug)) {
      next.remove(slug);
    } else {
      next.add(slug);
    }

    notifier.value = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      next.toList()..sort(),
    );
  }

  static Future<void> remove(String slug) async {
    if (!notifier.value.contains(slug)) return;

    final next = Set<String>.from(notifier.value)
      ..remove(slug);

    notifier.value = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      next.toList()..sort(),
    );
  }
}

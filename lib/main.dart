import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'services/favorites_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FavoritesService.init();

  runApp(const NizikApp());
}

class NizikApp extends StatelessWidget {
  const NizikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نزیک',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF43A047),
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF6F8F6),
        navigationBarTheme:
            const NavigationBarThemeData(
          height: 68,
          labelTextStyle:
              WidgetStatePropertyAll(
            TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

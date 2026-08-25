import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFFF6F8F6),
      ),
      home: const HomeScreen(),
    );
  }
}

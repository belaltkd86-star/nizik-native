import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
class NizikColors {
  static const green = Color(0xFF059669);
  static const darkGreen = Color(0xFF047857);
  static const mint = Color(0xFF34D399);
  static const softGreen = Color(0xFFECFDF5);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);
  static const line = Color(0xFFE2E8F0);
}

class NizikMotion {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}

class NizikRadius {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 22.0;
  static const xLarge = 28.0;
}

class NizikTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: NizikColors.green,
      brightness: Brightness.light,
      surface: NizikColors.surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: NizikColors.background,
    );

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      dividerColor: NizikColors.line,
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          color: NizikColors.ink,
          fontWeight: FontWeight.w900,
          height: 1.25,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: NizikColors.ink,
          fontWeight: FontWeight.w900,
          height: 1.3,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: NizikColors.ink,
          fontWeight: FontWeight.w900,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: NizikColors.ink,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: NizikColors.ink,
          height: 1.65,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: NizikColors.muted,
          height: 1.6,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: NizikColors.muted,
          height: 1.5,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NizikRadius.large),
          side: const BorderSide(color: NizikColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NizikRadius.medium),
          borderSide: const BorderSide(color: NizikColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NizikRadius.medium),
          borderSide: const BorderSide(color: NizikColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NizikRadius.medium),
          borderSide: const BorderSide(
            color: NizikColors.green,
            width: 1.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NizikColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NizikRadius.medium),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NizikColors.green,
          minimumSize: const Size(0, 46),
          side: const BorderSide(color: NizikColors.green),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NizikRadius.medium),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: NizikColors.softGreen,
        surfaceTintColor: Colors.white,
        elevation: 12,
        shadowColor: const Color(0x140F172A),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? NizikColors.darkGreen : NizikColors.muted,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          );
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

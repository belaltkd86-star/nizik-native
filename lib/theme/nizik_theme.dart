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

  static const darkBackground = Color(0xFF07110E);
  static const darkSurface = Color(0xFF101B17);
  static const darkSurface2 = Color(0xFF16231E);
  static const darkLine = Color(0xFF263A32);
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

    return _base(
      scheme: scheme,
      background: NizikColors.background,
      surface: NizikColors.surface,
      line: NizikColors.line,
      input: Colors.white,
      nav: Colors.white,
      navIndicator: NizikColors.softGreen,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: NizikColors.mint,
      brightness: Brightness.dark,
      surface: NizikColors.darkSurface,
    ).copyWith(
      primary: NizikColors.mint,
      onPrimary: const Color(0xFF052E20),
      secondary: NizikColors.green,
      surface: NizikColors.darkSurface,
      onSurface: const Color(0xFFF1FAF5),
      onSurfaceVariant: const Color(0xFFB7CEC1),
      surfaceContainerHighest: NizikColors.darkSurface2,
      outline: NizikColors.darkLine,
      outlineVariant: const Color(0xFF30483D),
      errorContainer: const Color(0xFF4C1D24),
      onErrorContainer: const Color(0xFFFFDAD6),
    );

    return _base(
      scheme: scheme,
      background: NizikColors.darkBackground,
      surface: NizikColors.darkSurface,
      line: NizikColors.darkLine,
      input: NizikColors.darkSurface2,
      nav: const Color(0xFF0D1713),
      navIndicator: const Color(0xFF173C2C),
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color background,
    required Color surface,
    required Color line,
    required Color input,
    required Color nav,
    required Color navIndicator,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      brightness: scheme.brightness,
      fontFamily: 'NizikSomar',
    );

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.25,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          height: 1.3,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.65),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.6),
        bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.5),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NizikRadius.large),
          side: BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NizikRadius.medium),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NizikRadius.medium),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NizikRadius.medium),
          borderSide: BorderSide(
            color: scheme.primary,
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
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 46),
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NizikRadius.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: nav,
        indicatorColor: navIndicator,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
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

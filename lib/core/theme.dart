import 'package:flutter/material.dart';
import 'constants.dart';

// Brand palette
const kSaffron = Color(0xFFFF6B23);
const kMagenta = Color(0xFFC21860);
const kGold    = Color(0xFFFFD700);

// Gradient used across hero headers, splash, and the polling screen.
const kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kSaffron, kMagenta],
);

ThemeData buildAppTheme() {
  const onPrimary  = Colors.white;
  const errorColor = Color(0xFFC62828);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: kSaffron,
    brightness: Brightness.light,
    error: errorColor,
  ).copyWith(
    primary: kSaffron,
    onPrimary: onPrimary,
    secondary: kMagenta,
    onSecondary: onPrimary,
    tertiary: kGold,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

  return base.copyWith(
    // Large, readable text — optimised for cheap Android screens at arm's length.
    textTheme: base.textTheme.copyWith(
      bodyLarge:  base.textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.4),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kSaffron,
        foregroundColor: onPrimary,
        minimumSize: const Size.fromHeight(kMinTapTarget + 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kSaffron,
        side: const BorderSide(color: kSaffron, width: 1.5),
        minimumSize: const Size.fromHeight(kMinTapTarget + 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kSaffron),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpaceMd,
        vertical: kSpaceMd,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBDBDBD), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBDBDBD), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kSaffron, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 16),
    ),

    // AppBar: white background, saffron title & icons — cleaner than solid colour.
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kSaffron,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: const Color(0xFF1A1A1A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: kSaffron),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: kSpaceSm),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kSaffron),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kMagenta,
      foregroundColor: Colors.white,
    ),

    chipTheme: ChipThemeData(
      selectedColor: kSaffron.withValues(alpha: 0.15),
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

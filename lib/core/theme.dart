import 'package:flutter/material.dart';
import 'constants.dart';

// Optimised for cheap Android screens: high contrast, large tap targets,
// readable at arm's length in bright outdoor light.
ThemeData buildAppTheme() {
  const primaryColor = Color(0xFF0D47A1); // deep blue — high contrast on white
  const onPrimary = Colors.white;
  const errorColor = Color(0xFFC62828);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      error: errorColor,
    ),
  );

  return base.copyWith(
    // Large, readable text
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
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

    // Buttons: large tap targets
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: onPrimary,
        minimumSize: const Size.fromHeight(kMinTapTarget + 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(kMinTapTarget + 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),

    // Input fields: large, clear, high-contrast borders
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
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 16),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: onPrimary,
      elevation: 0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: onPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: kSpaceSm),
    ),
  );
}

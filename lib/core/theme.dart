import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

// Brand palette
const kSaffron = Color(0xFFFF6B23);
const kMagenta = Color(0xFFC21860);
const kGold    = Color(0xFFFFD700);

// Dark surface colours
const kDarkBg      = Color(0xFF0A0A0A);
const kDarkSurface = Color(0xFF181818);
const kDarkCard    = Color(0xFF242424);

// Gradient used across hero headers, splash, and the polling screen.
const kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kSaffron, kMagenta],
);

ThemeData buildAppTheme() => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  const onPrimary  = Colors.white;
  const errorColor = Color(0xFFFF5252);

  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: kSaffron,
    brightness: brightness,
    error: errorColor,
  ).copyWith(
    primary: kSaffron,
    onPrimary: onPrimary,
    secondary: kMagenta,
    onSecondary: onPrimary,
    tertiary: kGold,
    surface: isDark ? kDarkBg : Colors.white,
    surfaceContainerLow: isDark ? kDarkSurface : const Color(0xFFF8F8F8),
    surfaceContainer: isDark ? kDarkCard : const Color(0xFFF0F0F0),
    surfaceContainerHighest: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE8E8E8),
    onSurface: isDark ? Colors.white : const Color(0xFF1A1A1A),
    onSurfaceVariant: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF606060),
    outline: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

  return base.copyWith(
    scaffoldBackgroundColor: isDark ? kDarkBg : Colors.white,

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
      fillColor: isDark ? kDarkSurface : const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpaceMd,
        vertical: kSpaceMd,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFBDBDBD),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFBDBDBD),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kSaffron, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      labelStyle: TextStyle(
        fontSize: 16,
        color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF606060),
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? kDarkBg : Colors.white,
      foregroundColor: isDark ? Colors.white : kSaffron,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white : kSaffron),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? kDarkSurface : Colors.white,
      indicatorColor: kSaffron.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kSaffron);
        }
        return IconThemeData(color: isDark ? const Color(0xFF888888) : const Color(0xFF888888));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: kSaffron,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: isDark ? const Color(0xFF888888) : const Color(0xFF888888),
          fontSize: 12,
        );
      }),
    ),

    cardTheme: CardThemeData(
      color: isDark ? kDarkCard : Colors.white,
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kSaffron),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kMagenta,
      foregroundColor: Colors.white,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: isDark ? kDarkCard : const Color(0xFFF0F0F0),
      selectedColor: kSaffron.withValues(alpha: isDark ? 0.25 : 0.15),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? kDarkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
    ),
  );
}

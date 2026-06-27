import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

// Supported locales — keep in sync with lib/l10n/app_*.arb files.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
  Locale('te'),
];

const Map<String, String> kLocaleDisplayNames = {
  'en': 'English',
  'hi': 'हिन्दी',
  'te': 'తెలుగు',
};

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------
class LocaleController extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(kLocaleKey);
    if (code != null) return Locale(code);
    // Default to English on first launch — no language picker shown.
    await prefs.setString(kLocaleKey, 'en');
    return const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocaleKey, locale.languageCode);
    state = AsyncData(locale);
  }
}

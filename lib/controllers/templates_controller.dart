import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/locale_controller.dart';
import '../models/template.dart';
import '../repositories/templates_repository.dart';

// ---------------------------------------------------------------------------
// Provider — non-auto-dispose so the cache survives home↔detail navigation.
// ---------------------------------------------------------------------------
final templatesControllerProvider =
    AsyncNotifierProvider<TemplatesController, List<Template>>(
        TemplatesController.new);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------
class TemplatesController extends AsyncNotifier<List<Template>> {
  // Theme filter persists across locale changes because the same notifier
  // instance is reused when build() is re-called due to a watched dependency
  // changing (Riverpod 2.x behaviour).
  String? _selectedTheme;

  String? get selectedTheme => _selectedTheme;

  @override
  Future<List<Template>> build() async {
    // Watching localeControllerProvider means build() is automatically
    // re-called whenever the user switches language — picks up the new
    // language for the API call while keeping _selectedTheme intact.
    final locale =
        ref.watch(localeControllerProvider).valueOrNull;
    final language = locale?.languageCode ?? 'en';

    return ref.read(templatesRepositoryProvider).getTemplates(
          language: language,
          theme: _selectedTheme,
        );
  }

  /// Switches the active theme filter and re-fetches.
  /// Pass null to show all themes.
  Future<void> setTheme(String? theme) async {
    if (_selectedTheme == theme) return;
    _selectedTheme = theme;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(bypassCache: false));
  }

  /// Forces a network call, bypassing the in-memory cache.
  /// Called on pull-to-refresh.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(bypassCache: true));
  }

  Future<List<Template>> _fetch({required bool bypassCache}) {
    final language = ref.read(localeControllerProvider).valueOrNull?.languageCode ?? 'en';
    return ref.read(templatesRepositoryProvider).getTemplates(
          language: language,
          theme: _selectedTheme,
          bypassCache: bypassCache,
        );
  }

  /// Derive the set of available themes from the currently loaded templates.
  /// Returns an empty list while loading or on error.
  List<String> get availableThemes {
    final templates = state.valueOrNull ?? [];
    return templates.map((t) => t.theme).toSet().toList()..sort();
  }
}

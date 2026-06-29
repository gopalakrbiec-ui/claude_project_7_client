import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/template.dart';
import '../repositories/templates_repository.dart';

// ---------------------------------------------------------------------------
// Grouped templates provider — used by the home screen discover tab.
// ---------------------------------------------------------------------------
final groupedTemplatesProvider =
    AsyncNotifierProvider<GroupedTemplatesController, List<TemplateCategoryGroup>>(
        GroupedTemplatesController.new);

class GroupedTemplatesController
    extends AsyncNotifier<List<TemplateCategoryGroup>> {
  @override
  Future<List<TemplateCategoryGroup>> build() =>
      ref.read(templatesRepositoryProvider).getGroupedTemplates();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(templatesRepositoryProvider).getGroupedTemplates(bypassCache: true),
    );
  }
}

// ---------------------------------------------------------------------------
// Flat templates provider — used by the All Templates grid tab.
// ---------------------------------------------------------------------------
final templatesControllerProvider =
    AsyncNotifierProvider<TemplatesController, List<Template>>(
        TemplatesController.new);

class TemplatesController extends AsyncNotifier<List<Template>> {
  String? _selectedTheme;

  String? get selectedTheme => _selectedTheme;

  @override
  Future<List<Template>> build() =>
      ref.read(templatesRepositoryProvider).getTemplates(theme: _selectedTheme);

  Future<void> setTheme(String? theme) async {
    if (_selectedTheme == theme) return;
    _selectedTheme = theme;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(bypassCache: false));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(bypassCache: true));
  }

  Future<List<Template>> _fetch({required bool bypassCache}) =>
      ref.read(templatesRepositoryProvider).getTemplates(
            theme: _selectedTheme,
            bypassCache: bypassCache,
          );

  List<String> get availableThemes {
    final templates = state.valueOrNull ?? [];
    return templates.map((t) => t.category).toSet().toList()..sort();
  }
}

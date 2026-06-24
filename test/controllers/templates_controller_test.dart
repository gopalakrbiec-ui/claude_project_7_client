import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:life_event_editor/api/api_error.dart';
import 'package:life_event_editor/controllers/locale_controller.dart';
import 'package:life_event_editor/controllers/templates_controller.dart';
import 'package:life_event_editor/models/template.dart';
import 'package:life_event_editor/repositories/templates_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockTemplatesRepository extends Mock implements TemplatesRepository {}

class _FixedLocaleController extends AsyncNotifier<Locale?> {
  _FixedLocaleController(this._locale);
  final Locale? _locale;

  @override
  Future<Locale?> build() async => _locale;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------
Template _tpl(String id, {String theme = 'floral', String language = 'en'}) =>
    Template(
      id: id,
      name: 'Template $id',
      language: language,
      theme: theme,
      basePricePaise: 1000,
      assetKeys: ['https://cdn.example.com/$id.jpg'],
    );

final _kTemplates = [
  _tpl('1', theme: 'floral'),
  _tpl('2', theme: 'wedding'),
  _tpl('3', theme: 'floral'),
];

// ---------------------------------------------------------------------------
// Test container factory
// ---------------------------------------------------------------------------
ProviderContainer _makeContainer({
  required MockTemplatesRepository repo,
  Locale locale = const Locale('en'),
}) {
  final c = ProviderContainer(
    overrides: [
      templatesRepositoryProvider.overrideWithValue(repo),
      localeControllerProvider.overrideWith(
        () => _FixedLocaleController(locale),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle(ProviderContainer c) async {
  await Future<void>.delayed(Duration.zero);
  while (c.read(templatesControllerProvider).isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late MockTemplatesRepository repo;

  setUp(() {
    repo = MockTemplatesRepository();
  });

  group('Initial load', () {
    test('returns templates on success', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      final c = _makeContainer(repo: repo);
      await _settle(c);

      final state = c.read(templatesControllerProvider);
      expect(state.hasValue, true);
      expect(state.value, _kTemplates);
    });

    test('uses locale language code in the API call', () async {
      when(() => repo.getTemplates(
            language: 'hi',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => [_tpl('1', language: 'hi')]);

      final c = _makeContainer(repo: repo, locale: const Locale('hi'));
      await _settle(c);

      verify(() => repo.getTemplates(
            language: 'hi',
            theme: null,
            bypassCache: false,
          )).called(1);
    });

    test('surfaces error on API failure', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenThrow(const NetworkError());

      final c = _makeContainer(repo: repo);
      await _settle(c);

      expect(c.read(templatesControllerProvider).hasError, true);
    });

    test('handles empty list without error', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => []);

      final c = _makeContainer(repo: repo);
      await _settle(c);

      final state = c.read(templatesControllerProvider);
      expect(state.hasValue, true);
      expect(state.value, isEmpty);
    });
  });

  group('setTheme', () {
    test('re-fetches with new theme and updates state', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      when(() => repo.getTemplates(
            language: 'en',
            theme: 'floral',
            bypassCache: false,
          )).thenAnswer((_) async =>
              _kTemplates.where((t) => t.theme == 'floral').toList());

      final c = _makeContainer(repo: repo);
      await _settle(c);

      await c.read(templatesControllerProvider.notifier).setTheme('floral');

      final state = c.read(templatesControllerProvider);
      expect(state.value?.every((t) => t.theme == 'floral'), true);
      expect(state.value?.length, 2);
    });

    test('calling setTheme with same value is a no-op', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      final c = _makeContainer(repo: repo);
      await _settle(c);

      await c.read(templatesControllerProvider.notifier).setTheme(null);

      // Only the initial call should have been made.
      verify(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).called(1);
    });

    test('clears theme filter when null is passed', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: 'floral',
            bypassCache: false,
          )).thenAnswer((_) async =>
              _kTemplates.where((t) => t.theme == 'floral').toList());

      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      final c = _makeContainer(repo: repo);
      // Start with a filter.
      await c.read(templatesControllerProvider.notifier).setTheme('floral');
      await _settle(c);

      // Clear filter.
      await c.read(templatesControllerProvider.notifier).setTheme(null);
      await _settle(c);

      expect(c.read(templatesControllerProvider).value?.length, 3);
      expect(
          c.read(templatesControllerProvider.notifier).selectedTheme, isNull);
    });
  });

  group('refresh', () {
    test('bypasses cache and re-fetches', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: true,
          )).thenAnswer((_) async => [_tpl('4')]); // new data after refresh

      final c = _makeContainer(repo: repo);
      await _settle(c);

      await c.read(templatesControllerProvider.notifier).refresh();
      await _settle(c);

      final state = c.read(templatesControllerProvider);
      expect(state.value?.length, 1);
      expect(state.value?.first.id, '4');
      verify(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: true,
          )).called(1);
    });
  });

  group('availableThemes', () {
    test('derives unique sorted themes from loaded templates', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      final c = _makeContainer(repo: repo);
      await _settle(c);

      final themes =
          c.read(templatesControllerProvider.notifier).availableThemes;
      expect(themes, ['floral', 'wedding']); // sorted
    });

    test('returns empty list while loading', () async {
      when(() => repo.getTemplates(
            language: 'en',
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _kTemplates;
      });

      final c = _makeContainer(repo: repo);
      // Don't settle — check while still loading.
      expect(
          c.read(templatesControllerProvider.notifier).availableThemes, isEmpty);
    });
  });
}

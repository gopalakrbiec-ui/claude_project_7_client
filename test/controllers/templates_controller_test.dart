import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:life_event_editor/api/api_error.dart';
import 'package:life_event_editor/controllers/templates_controller.dart';
import 'package:life_event_editor/models/template.dart';
import 'package:life_event_editor/repositories/templates_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockTemplatesRepository extends Mock implements TemplatesRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------
Template _tpl(String id, {String theme = 'floral'}) => Template(
      id: id,
      name: 'Template $id',
      language: 'en',
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
ProviderContainer _makeContainer({required MockTemplatesRepository repo}) {
  final c = ProviderContainer(
    overrides: [
      templatesRepositoryProvider.overrideWithValue(repo),
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
    test('returns all templates on success', () async {
      when(() => repo.getTemplates(
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      final c = _makeContainer(repo: repo);
      await _settle(c);

      final state = c.read(templatesControllerProvider);
      expect(state.hasValue, true);
      expect(state.value, _kTemplates);
    });

    test('surfaces error on API failure', () async {
      when(() => repo.getTemplates(
            theme: null,
            bypassCache: false,
          )).thenThrow(const NetworkError());

      final c = _makeContainer(repo: repo);
      await _settle(c);

      expect(c.read(templatesControllerProvider).hasError, true);
    });

    test('handles empty list without error', () async {
      when(() => repo.getTemplates(
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
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      when(() => repo.getTemplates(
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
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      final c = _makeContainer(repo: repo);
      await _settle(c);

      await c.read(templatesControllerProvider.notifier).setTheme(null);

      verify(() => repo.getTemplates(
            theme: null,
            bypassCache: false,
          )).called(1);
    });

    test('clears theme filter when null is passed', () async {
      when(() => repo.getTemplates(
            theme: 'floral',
            bypassCache: false,
          )).thenAnswer((_) async =>
              _kTemplates.where((t) => t.theme == 'floral').toList());

      when(() => repo.getTemplates(
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      final c = _makeContainer(repo: repo);
      await c.read(templatesControllerProvider.notifier).setTheme('floral');
      await _settle(c);

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
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      when(() => repo.getTemplates(
            theme: null,
            bypassCache: true,
          )).thenAnswer((_) async => [_tpl('4')]);

      final c = _makeContainer(repo: repo);
      await _settle(c);

      await c.read(templatesControllerProvider.notifier).refresh();
      await _settle(c);

      final state = c.read(templatesControllerProvider);
      expect(state.value?.length, 1);
      expect(state.value?.first.id, '4');
      verify(() => repo.getTemplates(
            theme: null,
            bypassCache: true,
          )).called(1);
    });
  });

  group('availableThemes', () {
    test('derives unique sorted themes from loaded templates', () async {
      when(() => repo.getTemplates(
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async => _kTemplates);

      final c = _makeContainer(repo: repo);
      await _settle(c);

      final themes =
          c.read(templatesControllerProvider.notifier).availableThemes;
      expect(themes, ['floral', 'wedding']);
    });

    test('returns empty list while loading', () async {
      when(() => repo.getTemplates(
            theme: null,
            bypassCache: false,
          )).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _kTemplates;
      });

      final c = _makeContainer(repo: repo);
      expect(
          c.read(templatesControllerProvider.notifier).availableThemes, isEmpty);
    });
  });
}

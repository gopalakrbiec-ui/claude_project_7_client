import 'dart:io';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import 'package:life_event_editor/api/api_error.dart';
import 'package:life_event_editor/controllers/create_order_controller.dart';
import 'package:life_event_editor/controllers/locale_controller.dart';
import 'package:life_event_editor/core/image_compress.dart';
import 'package:life_event_editor/models/order.dart';
import 'package:life_event_editor/models/template.dart';
import 'package:life_event_editor/repositories/orders_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockOrdersRepository extends Mock implements OrdersRepository {}

class MockUuid extends Mock implements Uuid {}

class _FixedLocaleController extends LocaleController {
  @override
  Future<Locale?> build() async => const Locale('en');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Template _tpl(String id) => Template(
      id: id,
      name: 'Template $id',
      language: 'en',
      theme: 'floral',
      basePricePaise: 1000,
      assetKeys: [],
    );

Order _order(String id) => Order(
      id: id,
      status: 'pending',
      templateId: 'tpl1',
      pricePaise: 1000,
      priceDisplay: '₹10',
      createdAt: DateTime(2025, 1, 1),
    );

// A no-op compress function — avoids hitting platform channels in tests.
Future<File?> _noopCompress(File f) async => f;

ProviderContainer _makeContainer({
  required MockOrdersRepository repo,
  String uuidValue = 'fixed-uuid-1234',
}) {
  final mockUuid = MockUuid();
  when(() => mockUuid.v4()).thenReturn(uuidValue);

  final c = ProviderContainer(
    overrides: [
      ordersRepositoryProvider.overrideWithValue(repo),
      uuidProvider.overrideWithValue(mockUuid),
      imageCompressFnProvider.overrideWithValue(_noopCompress),
      localeControllerProvider
          .overrideWith(() => _FixedLocaleController()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late MockOrdersRepository repo;

  setUp(() {
    repo = MockOrdersRepository();
    registerFallbackValue(CreateOrderParams(
      templateId: 'tpl1',
      idempotencyKey: 'key',
      name: 'Test',
      eventDate: '2025-12-25',
      theme: 'floral',
      language: 'en',
      mediaType: 'image',
    ));
  });

  group('Idempotency key lifecycle', () {
    test('key is generated once in build() and held in state', () {
      const key = 'uuid-abc-123';
      final c = _makeContainer(repo: repo, uuidValue: key);

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.idempotencyKey, key);
    });

    test('key is the same across multiple reads (not regenerated)', () {
      const key = 'uuid-stable';
      final c = _makeContainer(repo: repo, uuidValue: key);

      final key1 =
          c.read(createOrderControllerProvider('tpl1')).idempotencyKey;
      final key2 =
          c.read(createOrderControllerProvider('tpl1')).idempotencyKey;
      expect(key1, key2);
    });

    test('key is preserved across failed submit (retry reuses same key)', () async {
      const key = 'uuid-retry-key';
      final c = _makeContainer(repo: repo, uuidValue: key);

      when(() => repo.createOrder(any())).thenThrow(const NetworkError());

      final tpl = _tpl('tpl1');
      c.read(createOrderControllerProvider('tpl1').notifier).setName('Ravi');
      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setEventDate(DateTime(2025, 12, 25));

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit(tpl);

      // After error, key must still be the same.
      expect(
        c.read(createOrderControllerProvider('tpl1')).idempotencyKey,
        key,
      );
    });

    test('startNewOrder generates a new key', () {
      var callCount = 0;
      final mockUuid = MockUuid();
      when(() => mockUuid.v4()).thenAnswer((_) => 'key-${++callCount}');

      final c = ProviderContainer(
        overrides: [
          ordersRepositoryProvider.overrideWithValue(repo),
          uuidProvider.overrideWithValue(mockUuid),
          imageCompressFnProvider.overrideWithValue(_noopCompress),
          localeControllerProvider
              .overrideWith(() => _FixedLocaleController()),
        ],
      );
      addTearDown(c.dispose);

      final key1 =
          c.read(createOrderControllerProvider('tpl1')).idempotencyKey;
      c.read(createOrderControllerProvider('tpl1').notifier).startNewOrder();
      final key2 =
          c.read(createOrderControllerProvider('tpl1')).idempotencyKey;

      expect(key1, isNot(key2));
    });

    test('submit sends the stored idempotency key to the repository', () async {
      const key = 'uuid-sent-to-api';
      final c = _makeContainer(repo: repo, uuidValue: key);

      when(() => repo.createOrder(any()))
          .thenAnswer((_) async => _order('order1'));

      final tpl = _tpl('tpl1');
      c.read(createOrderControllerProvider('tpl1').notifier).setName('Priya');
      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setEventDate(DateTime(2025, 12, 25));

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit(tpl);

      final captured =
          verify(() => repo.createOrder(captureAny())).captured.single
              as CreateOrderParams;
      expect(captured.idempotencyKey, key);
    });
  });

  group('Submit success', () {
    test('transitions to success state with created order', () async {
      final c = _makeContainer(repo: repo);
      when(() => repo.createOrder(any()))
          .thenAnswer((_) async => _order('order42'));

      final tpl = _tpl('tpl1');
      c.read(createOrderControllerProvider('tpl1').notifier).setName('Test');
      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setEventDate(DateTime(2025, 6, 1));

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit(tpl);

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.isSuccess, true);
      expect(state.createdOrder?.id, 'order42');
    });
  });

  group('Submit errors', () {
    test('sets error message on NetworkError', () async {
      final c = _makeContainer(repo: repo);
      when(() => repo.createOrder(any())).thenThrow(const NetworkError());

      final tpl = _tpl('tpl1');
      c.read(createOrderControllerProvider('tpl1').notifier).setName('Test');
      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setEventDate(DateTime(2025, 6, 1));

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit(tpl);

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.status, CreateOrderStatus.error);
      expect(state.errorMessage, contains('internet'));
    });

    test('sets isInsufficientCredits on 402', () async {
      final c = _makeContainer(repo: repo);
      when(() => repo.createOrder(any()))
          .thenThrow(const ServerError(statusCode: 402, message: 'Insufficient credits'));

      final tpl = _tpl('tpl1');
      c.read(createOrderControllerProvider('tpl1').notifier).setName('Test');
      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setEventDate(DateTime(2025, 6, 1));

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit(tpl);

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.isInsufficientCredits, true);
      expect(state.status, CreateOrderStatus.error);
    });

    test('resetError returns to idle without changing idempotency key', () async {
      const key = 'uuid-reset-test';
      final c = _makeContainer(repo: repo, uuidValue: key);
      when(() => repo.createOrder(any())).thenThrow(const NetworkError());

      final tpl = _tpl('tpl1');
      c.read(createOrderControllerProvider('tpl1').notifier).setName('Test');
      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setEventDate(DateTime(2025, 6, 1));
      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit(tpl);

      c.read(createOrderControllerProvider('tpl1').notifier).resetError();

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.status, CreateOrderStatus.idle);
      expect(state.idempotencyKey, key); // preserved!
    });
  });

  group('Field setters', () {
    test('setName updates name in state', () {
      final c = _makeContainer(repo: repo);
      c.read(createOrderControllerProvider('tpl1').notifier).setName('Ananya');
      expect(c.read(createOrderControllerProvider('tpl1')).name, 'Ananya');
    });

    test('setMediaType updates mediaType', () {
      final c = _makeContainer(repo: repo);
      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setMediaType('video');
      expect(
          c.read(createOrderControllerProvider('tpl1')).mediaType, 'video');
    });

    test('setEventDate stores date; clearing sets null', () {
      final c = _makeContainer(repo: repo);
      final date = DateTime(2026, 1, 26);
      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setEventDate(date);
      expect(c.read(createOrderControllerProvider('tpl1')).eventDate, date);

      c
          .read(createOrderControllerProvider('tpl1').notifier)
          .setEventDate(null);
      expect(
          c.read(createOrderControllerProvider('tpl1')).eventDate, isNull);
    });
  });
}

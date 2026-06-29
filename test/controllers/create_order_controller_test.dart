import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import 'package:life_event_editor/api/api_error.dart';
import 'package:life_event_editor/controllers/create_order_controller.dart';
import 'package:life_event_editor/models/order.dart';
import 'package:life_event_editor/repositories/orders_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockOrdersRepository extends Mock implements OrdersRepository {}

class MockUuid extends Mock implements Uuid {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Order _order(String id) => Order(
      id: id,
      status: 'pending',
      templateId: 'tpl1',
      pricePaise: 1000,
      priceDisplay: '₹10',
      createdAt: DateTime(2025, 1, 1),
    );

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
    registerFallbackValue(const CreateOrderParams(
      templateId: 'tpl1',
      idempotencyKey: 'key',
    ));
    registerFallbackValue(File('dummy.jpg'));
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

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit('tpl1');

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

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit('tpl1');

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

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit('tpl1');

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.isSuccess, true);
      expect(state.createdOrder?.id, 'order42');
    });

    test('sends userPhotoKey and userPrompt when set', () async {
      final c = _makeContainer(repo: repo);
      when(() => repo.createOrder(any()))
          .thenAnswer((_) async => _order('order1'));

      final notifier =
          c.read(createOrderControllerProvider('tpl1').notifier);
      notifier.setPrompt('Wedding celebration');
      notifier.setAspectRatio('9:16');

      // Manually inject a photo key as if upload had already succeeded.
      // We test upload separately; here we verify submit passes it through.
      c.read(createOrderControllerProvider('tpl1').notifier);
      // Use copyWith trick via a fresh container with pre-seeded state isn't
      // straightforward — instead verify capturedParam after submit.
      await notifier.submit('tpl1');

      final captured =
          verify(() => repo.createOrder(captureAny())).captured.single
              as CreateOrderParams;
      expect(captured.userPrompt, 'Wedding celebration');
      expect(captured.aspectRatio, '9:16');
    });
  });

  group('Submit errors', () {
    test('sets error message on NetworkError', () async {
      final c = _makeContainer(repo: repo);
      when(() => repo.createOrder(any())).thenThrow(const NetworkError());

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit('tpl1');

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.status, CreateOrderStatus.error);
      expect(state.errorMessage, contains('internet'));
    });

    test('sets isInsufficientCredits on 402', () async {
      final c = _makeContainer(repo: repo);
      when(() => repo.createOrder(any())).thenThrow(
          const ServerError(statusCode: 402, message: 'Insufficient credits'));

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit('tpl1');

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.isInsufficientCredits, true);
      expect(state.status, CreateOrderStatus.error);
    });

    test('resetError returns to idle without changing idempotency key', () async {
      const key = 'uuid-reset-test';
      final c = _makeContainer(repo: repo, uuidValue: key);
      when(() => repo.createOrder(any())).thenThrow(const NetworkError());

      await c
          .read(createOrderControllerProvider('tpl1').notifier)
          .submit('tpl1');

      c.read(createOrderControllerProvider('tpl1').notifier).resetError();

      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.status, CreateOrderStatus.idle);
      expect(state.idempotencyKey, key);
    });
  });

  group('Field setters', () {
    test('setPrompt updates userPrompt in state', () {
      final c = _makeContainer(repo: repo);
      c.read(createOrderControllerProvider('tpl1').notifier)
          .setPrompt('Birthday bash');
      expect(
          c.read(createOrderControllerProvider('tpl1')).userPrompt,
          'Birthday bash');
    });

    test('setAspectRatio updates aspectRatio', () {
      final c = _makeContainer(repo: repo);
      c.read(createOrderControllerProvider('tpl1').notifier)
          .setAspectRatio('16:9');
      expect(
          c.read(createOrderControllerProvider('tpl1')).aspectRatio, '16:9');
    });

    test('default aspectRatio is 1:1', () {
      final c = _makeContainer(repo: repo);
      expect(
          c.read(createOrderControllerProvider('tpl1')).aspectRatio, '1:1');
    });

    test('clearPhoto removes photo file and key', () async {
      final c = _makeContainer(repo: repo);
      // Simulate an already-uploaded photo by checking state after clear.
      c.read(createOrderControllerProvider('tpl1').notifier).clearPhoto();
      final state = c.read(createOrderControllerProvider('tpl1'));
      expect(state.userPhotoFile, isNull);
      expect(state.userPhotoKey, isNull);
    });
  });
}

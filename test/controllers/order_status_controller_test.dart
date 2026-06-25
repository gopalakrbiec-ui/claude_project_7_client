import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:life_event_editor/api/api_error.dart';
import 'package:life_event_editor/controllers/order_status_controller.dart';
import 'package:life_event_editor/models/order.dart';
import 'package:life_event_editor/repositories/orders_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockOrdersRepository extends Mock implements OrdersRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------
Order _order(String status, {String? resultUrl}) => Order(
      id: 'ord1',
      status: status,
      templateId: 'tpl1',
      pricePaise: 1000,
      priceDisplay: '₹10',
      resultUrl: resultUrl,
      createdAt: DateTime(2025, 1, 1),
    );

// ---------------------------------------------------------------------------
// Container factory — 1 ms poll interval so tests run instantly.
// ---------------------------------------------------------------------------
ProviderContainer _makeContainer({
  required MockOrdersRepository repo,
  int maxAttempts = 5,
}) {
  final c = ProviderContainer(
    overrides: [
      ordersRepositoryProvider.overrideWithValue(repo),
      orderPollInitialDelayProvider
          .overrideWithValue(const Duration(milliseconds: 1)),
      orderPollMaxAttemptsProvider.overrideWithValue(maxAttempts),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

// Drains microtasks + a few event-loop ticks so async polling can progress.
Future<void> _pump([int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late MockOrdersRepository repo;

  setUp(() {
    repo = MockOrdersRepository();
    // Provide a fallback for mocktail's type-matching.
    registerFallbackValue('ord1');
  });

  // ---- Happy-path polling -------------------------------------------------

  group('Polling happy path', () {
    test('starts in polling phase', () {
      when(() => repo.getOrder(any()))
          .thenAnswer((_) async => _order('queued'));

      final c = _makeContainer(repo: repo);
      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.polling,
      );
    });

    test('reaches done when server returns status=done', () async {
      var call = 0;
      when(() => repo.getOrder(any())).thenAnswer((_) async {
        call++;
        return call >= 2
            ? _order('done', resultUrl: 'https://cdn.example.com/r.jpg')
            : _order('generating');
      });

      final c = _makeContainer(repo: repo);
      await _pump();

      final state = c.read(orderStatusControllerProvider('ord1'));
      expect(state.phase, OrderPhase.done);
      expect(state.order?.resultUrl, 'https://cdn.example.com/r.jpg');
    });

    test('reaches done for legacy status=completed', () async {
      when(() => repo.getOrder(any()))
          .thenAnswer((_) async =>
              _order('completed', resultUrl: 'https://cdn.example.com/r.jpg'));

      final c = _makeContainer(repo: repo);
      await _pump();

      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.done,
      );
    });

    test('reaches rejected when server returns status=rejected', () async {
      when(() => repo.getOrder(any()))
          .thenAnswer((_) async => _order('rejected'));

      final c = _makeContainer(repo: repo);
      await _pump();

      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.rejected,
      );
    });

    test('polls through queued → moderating → generating → done', () async {
      final statuses = ['queued', 'moderating', 'generating', 'done'];
      var call = 0;
      when(() => repo.getOrder(any())).thenAnswer((_) async {
        final s = statuses[call.clamp(0, statuses.length - 1)];
        call++;
        return _order(s,
            resultUrl:
                s == 'done' ? 'https://cdn.example.com/r.jpg' : null);
      });

      final c = _makeContainer(repo: repo, maxAttempts: 10);
      await _pump(60);

      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.done,
      );
    });
  });

  // ---- Backoff ------------------------------------------------------------

  group('Backoff', () {
    test('currentDelay grows across polls (backoff is increasing)', () async {
      // Always returns in-progress so we can observe delay growth.
      when(() => repo.getOrder(any()))
          .thenAnswer((_) async => _order('generating'));

      final c = _makeContainer(repo: repo, maxAttempts: 6);

      final delays = <int>[];
      c.listen(orderStatusControllerProvider('ord1'), (_, state) {
        if (state.currentDelay != null) {
          delays.add(state.currentDelay!.inMilliseconds);
        }
      });

      await _pump(60);

      // Each recorded delay must be >= the previous (truncated exponential).
      for (var i = 1; i < delays.length; i++) {
        expect(delays[i], greaterThanOrEqualTo(delays[i - 1]),
            reason:
                'delay[$i]=${delays[i]}ms should be >= delay[${i - 1}]=${delays[i - 1]}ms');
      }
    });

    test('reaches timeout when max attempts exhausted without terminal status',
        () async {
      when(() => repo.getOrder(any()))
          .thenAnswer((_) async => _order('generating'));

      final c = _makeContainer(repo: repo, maxAttempts: 3);
      await _pump(30);

      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.timeout,
      );
    });
  });

  // ---- Network resilience -------------------------------------------------

  group('Network resilience', () {
    test('continues polling after transient NetworkError', () async {
      var call = 0;
      when(() => repo.getOrder(any())).thenAnswer((_) async {
        call++;
        if (call == 1) throw const NetworkError();
        return _order('done',
            resultUrl: 'https://cdn.example.com/r.jpg');
      });

      final c = _makeContainer(repo: repo, maxAttempts: 5);
      await _pump();

      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.done,
      );
    });

    test('transitions to networkError on ServerError (not retriable)', () async {
      when(() => repo.getOrder(any())).thenThrow(
          const ServerError(statusCode: 500, message: 'Backend exploded'));

      final c = _makeContainer(repo: repo);
      await _pump();

      final state = c.read(orderStatusControllerProvider('ord1'));
      expect(state.phase, OrderPhase.networkError);
      expect(state.errorMessage, contains('Backend'));
    });
  });

  // ---- Retry --------------------------------------------------------------

  group('retry()', () {
    test('resets to polling and restarts the loop', () async {
      // First loop: always generating → timeout.
      when(() => repo.getOrder(any()))
          .thenAnswer((_) async => _order('generating'));

      final c = _makeContainer(repo: repo, maxAttempts: 2);
      await _pump();

      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.timeout,
      );

      // Now server returns done.
      when(() => repo.getOrder(any()))
          .thenAnswer((_) async =>
              _order('done', resultUrl: 'https://cdn.example.com/r.jpg'));

      c.read(orderStatusControllerProvider('ord1').notifier).retry();
      await _pump();

      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.done,
      );
    });
  });

  // ---- Remove watermark ---------------------------------------------------

  group('removeWatermark()', () {
    test('transitions done → done with cleanUrl on success', () async {
      when(() => repo.getOrder(any())).thenAnswer((_) async =>
          _order('done', resultUrl: 'https://cdn.example.com/watermarked.jpg'));
      when(() => repo.removeWatermark(any()))
          .thenAnswer((_) async => 'https://cdn.example.com/clean.jpg');

      final c = _makeContainer(repo: repo);
      await _pump(); // reach done state

      expect(
          c.read(orderStatusControllerProvider('ord1')).phase,
          OrderPhase.done);

      await c
          .read(orderStatusControllerProvider('ord1').notifier)
          .removeWatermark();

      final state = c.read(orderStatusControllerProvider('ord1'));
      expect(state.phase, OrderPhase.done);
      expect(state.cleanUrl, 'https://cdn.example.com/clean.jpg');
      expect(state.displayUrl, 'https://cdn.example.com/clean.jpg');
    });

    test('displayUrl falls back to watermarked when cleanUrl is null',
        () async {
      when(() => repo.getOrder(any())).thenAnswer((_) async =>
          _order('done', resultUrl: 'https://cdn.example.com/watermarked.jpg'));

      final c = _makeContainer(repo: repo);
      await _pump();

      expect(
        c.read(orderStatusControllerProvider('ord1')).displayUrl,
        'https://cdn.example.com/watermarked.jpg',
      );
    });

    test('sets needsTopup on 402 from remove-watermark', () async {
      when(() => repo.getOrder(any())).thenAnswer((_) async =>
          _order('done', resultUrl: 'https://cdn.example.com/wm.jpg'));
      when(() => repo.removeWatermark(any())).thenThrow(
          const ServerError(statusCode: 402, message: 'Insufficient credits'));

      final c = _makeContainer(repo: repo);
      await _pump();

      await c
          .read(orderStatusControllerProvider('ord1').notifier)
          .removeWatermark();

      final state = c.read(orderStatusControllerProvider('ord1'));
      expect(state.needsTopup, true);
      expect(state.phase, OrderPhase.done); // stays on done, doesn't crash
    });

    test('sets errorMessage on non-402 ServerError from remove-watermark',
        () async {
      when(() => repo.getOrder(any())).thenAnswer((_) async =>
          _order('done', resultUrl: 'https://cdn.example.com/wm.jpg'));
      when(() => repo.removeWatermark(any())).thenThrow(
          const ServerError(statusCode: 500, message: 'Server error'));

      final c = _makeContainer(repo: repo);
      await _pump();

      await c
          .read(orderStatusControllerProvider('ord1').notifier)
          .removeWatermark();

      final state = c.read(orderStatusControllerProvider('ord1'));
      expect(state.phase, OrderPhase.done);
      expect(state.errorMessage, isNotNull);
      expect(state.needsTopup, false);
    });

    test('sets errorMessage on NetworkError from remove-watermark', () async {
      when(() => repo.getOrder(any())).thenAnswer((_) async =>
          _order('done', resultUrl: 'https://cdn.example.com/wm.jpg'));
      when(() => repo.removeWatermark(any())).thenThrow(const NetworkError());

      final c = _makeContainer(repo: repo);
      await _pump();

      await c
          .read(orderStatusControllerProvider('ord1').notifier)
          .removeWatermark();

      final state = c.read(orderStatusControllerProvider('ord1'));
      expect(state.phase, OrderPhase.done);
      expect(state.errorMessage, contains('internet'));
    });

    test('is a no-op if already removing watermark', () async {
      when(() => repo.getOrder(any())).thenAnswer((_) async =>
          _order('done', resultUrl: 'https://cdn.example.com/wm.jpg'));

      // Slow remove-watermark call.
      when(() => repo.removeWatermark(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(seconds: 10));
        return 'https://cdn.example.com/clean.jpg';
      });

      final c = _makeContainer(repo: repo);
      await _pump();

      // Fire twice without awaiting.
      c.read(orderStatusControllerProvider('ord1').notifier)
          .removeWatermark().ignore();
      await Future<void>.delayed(Duration.zero);

      expect(
        c.read(orderStatusControllerProvider('ord1')).phase,
        OrderPhase.removingWatermark,
      );

      // Second call should be ignored.
      await c
          .read(orderStatusControllerProvider('ord1').notifier)
          .removeWatermark();

      // removeWatermark should only have been called once.
      verify(() => repo.removeWatermark(any())).called(1);
    });
  });

  // ---- clearNeedsTopup ----------------------------------------------------

  group('clearNeedsTopup()', () {
    test('resets needsTopup to false', () async {
      when(() => repo.getOrder(any())).thenAnswer((_) async =>
          _order('done', resultUrl: 'https://cdn.example.com/wm.jpg'));
      when(() => repo.removeWatermark(any())).thenThrow(
          const ServerError(statusCode: 402, message: 'Insufficient credits'));

      final c = _makeContainer(repo: repo);
      await _pump();
      await c
          .read(orderStatusControllerProvider('ord1').notifier)
          .removeWatermark();

      expect(c.read(orderStatusControllerProvider('ord1')).needsTopup, true);

      c.read(orderStatusControllerProvider('ord1').notifier).clearNeedsTopup();

      expect(c.read(orderStatusControllerProvider('ord1')).needsTopup, false);
    });
  });
}

// ignore: prefer_void_to_null
void unawaited(Future<Null> future) {}

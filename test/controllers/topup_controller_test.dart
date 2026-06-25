import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:life_event_editor/api/api_error.dart';
import 'package:life_event_editor/controllers/credits_controller.dart';
import 'package:life_event_editor/controllers/topup_controller.dart';
import 'package:life_event_editor/models/credits_balance.dart';
import 'package:life_event_editor/models/payment_order.dart';
import 'package:life_event_editor/repositories/credits_repository.dart';
import 'package:life_event_editor/repositories/payments_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockPaymentsRepository extends Mock implements PaymentsRepository {}

class MockCreditsRepository extends Mock implements CreditsRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------
final _kPaymentOrder = PaymentOrder(
  paymentId: 'pay_123',
  gatewayOrderId: 'order_abc',
  amountPaise: 10000,
  currency: 'INR',
  keyId: 'rzp_test_from_server', // from server, not hardcoded
);

CreditsBalance _balance(int paise) => CreditsBalance(
      balancePaise: paise,
      balanceRupees: '₹${paise ~/ 100}',
    );

// ---------------------------------------------------------------------------
// Container factory
// ---------------------------------------------------------------------------
// Uses a 1-ms poll interval + 3 max attempts so tests run instantly.
ProviderContainer _makeContainer({
  required MockPaymentsRepository paymentsRepo,
  required MockCreditsRepository creditsRepo,
  int pollMaxAttempts = 3,
}) {
  final c = ProviderContainer(
    overrides: [
      paymentsRepositoryProvider.overrideWithValue(paymentsRepo),
      creditsRepositoryProvider.overrideWithValue(creditsRepo),
      topupPollIntervalProvider
          .overrideWithValue(const Duration(milliseconds: 1)),
      topupPollMaxAttemptsProvider.overrideWithValue(pollMaxAttempts),
      // creditsControllerProvider starts with a 0-paise balance by default.
      creditsControllerProvider.overrideWith(
        () => _FakeCreditsController(CreditsAsyncState.data(_balance(0))),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

// Minimal stub that holds a fixed balance so TopupController can read it.
class _FakeCreditsController extends CreditsController {
  _FakeCreditsController(this._initial);
  final AsyncValue<CreditsBalance> _initial;

  @override
  Future<CreditsBalance> build() async => _initial.value!;

  @override
  Future<void> refresh() async {}
}

// Expose AsyncValue.data as a convenient alias for tests.
typedef CreditsAsyncState = AsyncValue<CreditsBalance>;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late MockPaymentsRepository paymentsRepo;
  late MockCreditsRepository creditsRepo;

  setUp(() {
    paymentsRepo = MockPaymentsRepository();
    creditsRepo = MockCreditsRepository();

    registerFallbackValue(0);
  });

  // ---- initTopup ----------------------------------------------------------

  group('initTopup', () {
    test('transitions idle → creatingOrder → awaitingCheckout on success',
        () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);

      final states = <TopupStatus>[];
      c.listen(topupControllerProvider,
          (_, s) => states.add(s.status), fireImmediately: true);

      await c.read(topupControllerProvider.notifier).initTopup(10000);

      expect(states, containsAllInOrder([
        TopupStatus.idle,
        TopupStatus.creatingOrder,
        TopupStatus.awaitingCheckout,
      ]));
    });

    test('stores paymentOrder in state so widget can pass it to Razorpay',
        () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);

      final order = c.read(topupControllerProvider).paymentOrder;
      expect(order?.keyId, 'rzp_test_from_server');
      expect(order?.gatewayOrderId, 'order_abc');
      expect(order?.amountPaise, 10000);
    });

    test('transitions to error on NetworkError', () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenThrow(const NetworkError());

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);

      expect(c.read(topupControllerProvider).status, TopupStatus.error);
      expect(c.read(topupControllerProvider).errorMessage,
          contains('internet'));
    });

    test('transitions to error on ServerError', () async {
      when(() => paymentsRepo.createOrder(any())).thenThrow(
          const ServerError(statusCode: 500, message: 'Internal error'));

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);

      expect(c.read(topupControllerProvider).status, TopupStatus.error);
    });

    test('is a no-op if already loading', () async {
      // Pause the payment order creation so we're stuck in creatingOrder.
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async {
        await Future<void>.delayed(const Duration(seconds: 10));
        return _kPaymentOrder;
      });

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);

      // Fire but don't await — leaves controller in creatingOrder.
      unawaited(
          c.read(topupControllerProvider.notifier).initTopup(10000));

      await Future<void>.delayed(Duration.zero);
      expect(c.read(topupControllerProvider).status,
          TopupStatus.creatingOrder);

      // Second call while loading: should be ignored.
      await c.read(topupControllerProvider.notifier).initTopup(20000);

      // selected amount must not have changed to 20000.
      expect(
          c.read(topupControllerProvider).selectedAmountPaise, 10000);
    });
  });

  // ---- Razorpay success / error callbacks ---------------------------------

  group('onRazorpaySuccess', () {
    test('starts polling and reaches success when balance increases', () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);

      // First poll call: balance still 0. Second: balance rose.
      var pollCall = 0;
      when(() => creditsRepo.getBalance()).thenAnswer((_) async {
        pollCall++;
        return pollCall >= 2 ? _balance(10000) : _balance(0);
      });

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);
      c.read(topupControllerProvider.notifier).onRazorpaySuccess();

      // Wait for polling to finish.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = c.read(topupControllerProvider);
      expect(state.status, TopupStatus.success);
      expect(state.newBalance?.balancePaise, 10000);
    });

    test('transitions confirming → timeout when balance never rises', () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);
      when(() => creditsRepo.getBalance())
          .thenAnswer((_) async => _balance(0)); // never rises

      final c = _makeContainer(
          paymentsRepo: paymentsRepo,
          creditsRepo: creditsRepo,
          pollMaxAttempts: 2);
      await c.read(topupControllerProvider.notifier).initTopup(10000);
      c.read(topupControllerProvider.notifier).onRazorpaySuccess();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.read(topupControllerProvider).status, TopupStatus.timeout);
    });

    test('continues polling through transient API errors', () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);

      var pollCall = 0;
      when(() => creditsRepo.getBalance()).thenAnswer((_) async {
        pollCall++;
        if (pollCall == 1) throw const NetworkError();
        return _balance(10000); // succeeds on second call
      });

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);
      c.read(topupControllerProvider.notifier).onRazorpaySuccess();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.read(topupControllerProvider).status, TopupStatus.success);
    });
  });

  group('onRazorpayExternalWallet', () {
    test('also starts polling (external wallet credits via webhook too)',
        () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);
      when(() => creditsRepo.getBalance())
          .thenAnswer((_) async => _balance(10000));

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);
      c.read(topupControllerProvider.notifier).onRazorpayExternalWallet();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.read(topupControllerProvider).status, TopupStatus.success);
    });
  });

  group('onRazorpayError', () {
    test('code 0 (user cancelled) → cancelled state', () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);
      c
          .read(topupControllerProvider.notifier)
          .onRazorpayError(0, 'Payment cancelled by user');

      expect(c.read(topupControllerProvider).status, TopupStatus.cancelled);
    });

    test('non-zero code → failed state with message', () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);
      c
          .read(topupControllerProvider.notifier)
          .onRazorpayError(2, 'Payment failed at bank');

      final state = c.read(topupControllerProvider);
      expect(state.status, TopupStatus.failed);
      expect(state.errorMessage, 'Payment failed at bank');
    });
  });

  // ---- reset --------------------------------------------------------------

  group('reset', () {
    test('returns to idle and clears all fields', () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);

      final c = _makeContainer(
          paymentsRepo: paymentsRepo, creditsRepo: creditsRepo);
      await c.read(topupControllerProvider.notifier).initTopup(10000);
      c.read(topupControllerProvider.notifier).reset();

      final state = c.read(topupControllerProvider);
      expect(state.status, TopupStatus.idle);
      expect(state.paymentOrder, isNull);
      expect(state.selectedAmountPaise, isNull);
    });

    test('cancels in-flight polling', () async {
      when(() => paymentsRepo.createOrder(any()))
          .thenAnswer((_) async => _kPaymentOrder);

      var getBalanceCalls = 0;
      when(() => creditsRepo.getBalance()).thenAnswer((_) async {
        getBalanceCalls++;
        return _balance(0); // never rises
      });

      final c = _makeContainer(
          paymentsRepo: paymentsRepo,
          creditsRepo: creditsRepo,
          pollMaxAttempts: 100);
      await c.read(topupControllerProvider.notifier).initTopup(10000);
      c.read(topupControllerProvider.notifier).onRazorpaySuccess();

      // Let one poll tick execute then reset.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      c.read(topupControllerProvider.notifier).reset();

      final callsBeforeReset = getBalanceCalls;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // No further calls after reset.
      expect(getBalanceCalls, callsBeforeReset);
      expect(c.read(topupControllerProvider).status, TopupStatus.idle);
    });
  });
}

// ignore: prefer_void_to_null
void unawaited(Future<Null> future) {}

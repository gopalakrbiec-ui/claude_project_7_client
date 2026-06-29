import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../core/constants.dart';
import '../models/order.dart';
import '../repositories/orders_repository.dart';

// ---------------------------------------------------------------------------
// Injectable poll tuning — overridden in tests so we don't wait real seconds.
// ---------------------------------------------------------------------------
final orderPollInitialDelayProvider =
    Provider<Duration>((_) => kOrderPollInitialDelay);
final orderPollMaxAttemptsProvider =
    Provider<int>((_) => kOrderPollMaxAttempts);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum OrderPhase {
  polling,           // actively polling; order is queued/moderating/generating
  done,              // order.isDone — result URL available
  rejected,          // order.isRejected — credits refunded
  timeout,           // ran out of poll attempts without a terminal status
  networkError,      // persistent network failure
  removingWatermark, // POST /orders/{id}/remove-watermark in flight
}

class OrderStatusState {
  const OrderStatusState({
    required this.phase,
    this.order,
    this.cleanUrl,
    this.needsTopup = false,
    this.errorMessage,
    this.attemptCount = 0,
    this.currentDelay,
    this.lastPollError,
  });

  final OrderPhase phase;

  /// The most recent order from the server.
  final Order? order;

  /// Populated after a successful remove-watermark call.
  /// Non-null means we should display the clean version.
  final String? cleanUrl;

  /// True when remove-watermark returned 402 — widget should navigate to topup.
  final bool needsTopup;

  final String? errorMessage;
  final int attemptCount;

  /// The delay currently in use (displayed to the user if desired).
  final Duration? currentDelay;

  /// Last network/server error during polling — surfaced in debug builds.
  final String? lastPollError;

  bool get isTerminal =>
      phase == OrderPhase.done ||
      phase == OrderPhase.rejected ||
      phase == OrderPhase.timeout ||
      phase == OrderPhase.networkError;

  /// The display URL: clean version when available, otherwise watermarked.
  String? get displayUrl => cleanUrl ?? order?.resultUrl;

  OrderStatusState copyWith({
    OrderPhase? phase,
    Order? order,
    String? cleanUrl,
    bool? needsTopup,
    String? errorMessage,
    bool clearError = false,
    int? attemptCount,
    Duration? currentDelay,
    String? lastPollError,
    bool clearLastPollError = false,
  }) =>
      OrderStatusState(
        phase: phase ?? this.phase,
        order: order ?? this.order,
        cleanUrl: cleanUrl ?? this.cleanUrl,
        needsTopup: needsTopup ?? this.needsTopup,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        attemptCount: attemptCount ?? this.attemptCount,
        currentDelay: currentDelay ?? this.currentDelay,
        lastPollError: clearLastPollError ? null : (lastPollError ?? this.lastPollError),
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final orderStatusControllerProvider = NotifierProvider.family<
    OrderStatusController, OrderStatusState, String>(
  OrderStatusController.new,
);

// ---------------------------------------------------------------------------
// Controller
//
// Backoff strategy
// ---------------
// We use truncated exponential backoff (multiplier 1.5×, cap 30 s) rather
// than fixed-interval polling for two reasons:
//
// 1. GPU / AI queue behaviour: generation typically takes 30–120 s. A fixed
//    3 s poll would fire 10–40 times during that window, most of them wasted.
//    Backoff naturally concentrates polls at the start (catching fast jobs)
//    and spaces them out for slow jobs, reducing unnecessary API load without
//    sacrificing responsiveness.
//
// 2. Flaky networks: on a 2G/3G link, a failed request is followed by an
//    immediate retry storm in fixed-interval schemes. Exponential backoff
//    gives the network time to recover before the next attempt, preventing
//    the server from being hit with a burst of retries from every affected
//    device simultaneously.
//
// Sequence (seconds): 3 → 4.5 → 6.75 → 10.1 → 15.2 → 22.8 → 30 → 30 → …
// A transient NetworkError resets the next delay to 3 s (fresh backoff)
// so that a device that just came back online isn't made to wait 30 s.
// ---------------------------------------------------------------------------
class OrderStatusController
    extends FamilyNotifier<OrderStatusState, String> {
  bool _cancelled = false;

  String get _orderId => arg;

  @override
  OrderStatusState build(String orderId) {
    ref.onDispose(() => _cancelled = true);
    _startPolling(delay: ref.read(orderPollInitialDelayProvider));
    return const OrderStatusState(phase: OrderPhase.polling);
  }

  // -- Public API -----------------------------------------------------------

  void retry() {
    _cancelled = false;
    state = const OrderStatusState(phase: OrderPhase.polling);
    _startPolling(delay: ref.read(orderPollInitialDelayProvider));
  }

  Future<void> removeWatermark() async {
    if (state.phase == OrderPhase.removingWatermark) return;
    state = state.copyWith(
        phase: OrderPhase.removingWatermark,
        needsTopup: false,
        clearError: true);

    try {
      final cleanUrl = await ref
          .read(ordersRepositoryProvider)
          .removeWatermark(_orderId);
      state = state.copyWith(phase: OrderPhase.done, cleanUrl: cleanUrl);
    } on InsufficientCreditsError catch (_) {
      state = state.copyWith(phase: OrderPhase.done, needsTopup: true);
    } on ServerError catch (e) {
      state = state.copyWith(phase: OrderPhase.done, errorMessage: e.message);
    } on NetworkError {
      state = state.copyWith(
          phase: OrderPhase.done,
          errorMessage: 'No internet connection. Please try again.');
    }
  }

  void clearNeedsTopup() => state = state.copyWith(needsTopup: false);

  /// DEBUG only — forces the phase to done with a placeholder image so the
  /// download/share flow can be tested without a real successful order.
  void debugForceDone() {
    state = state.copyWith(
      phase: OrderPhase.done,
      order: Order(
        id: state.order?.id ?? 'debug',
        status: 'done',
        templateId: state.order?.templateId ?? 'debug',
        pricePaise: 0,
        priceDisplay: '₹0',
        resultUrl: 'https://picsum.photos/seed/yaadein/800/1200',
        createdAt: DateTime.now(),
      ),
    );
  }

  // -- Polling loop ---------------------------------------------------------

  Future<void> _startPolling({required Duration delay}) async {
    final maxAttempts = ref.read(orderPollMaxAttemptsProvider);
    dev.log('[OrderStatus] polling start — orderId=$_orderId maxAttempts=$maxAttempts', name: 'order');

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future<void>.delayed(delay);
      if (_cancelled) return;

      dev.log('[OrderStatus] attempt ${attempt + 1}/$maxAttempts — delay=${delay.inSeconds}s', name: 'order');

      // Expose the current delay so the UI can say "checking again soon".
      state = state.copyWith(
          phase: OrderPhase.polling,
          attemptCount: attempt + 1,
          currentDelay: delay);

      try {
        final order =
            await ref.read(ordersRepositoryProvider).getOrder(_orderId);
        if (_cancelled) return;

        dev.log('[OrderStatus] GET /orders/$_orderId → status=${order.status}', name: 'order');

        if (order.isDone) {
          dev.log('[OrderStatus] done — resultUrl=${order.resultUrl}', name: 'order');
          state = state.copyWith(phase: OrderPhase.done, order: order, clearLastPollError: true);
          return;
        }

        if (order.isRejected) {
          dev.log('[OrderStatus] rejected', name: 'order');
          state = state.copyWith(phase: OrderPhase.rejected, order: order);
          return;
        }

        // Still in progress — update the displayed order and back off.
        state = state.copyWith(order: order, clearLastPollError: true);
        delay = _backoff(delay);
      } on NetworkError catch (e) {
        dev.log('[OrderStatus] NetworkError on attempt ${attempt + 1}: $e', name: 'order');
        state = state.copyWith(lastPollError: 'NetworkError: $e');
        delay = ref.read(orderPollInitialDelayProvider);
      } on ServerError catch (e) {
        dev.log('[OrderStatus] ServerError on attempt ${attempt + 1}: ${e.statusCode} ${e.message}', name: 'order');
        if (_cancelled) return;
        state = state.copyWith(
            phase: OrderPhase.networkError,
            errorMessage: e.message,
            lastPollError: 'ServerError ${e.statusCode}: ${e.message}');
        return;
      } catch (e, st) {
        dev.log('[OrderStatus] unexpected error on attempt ${attempt + 1}: $e\n$st', name: 'order', error: e);
        state = state.copyWith(lastPollError: 'Error: $e');
      }
    }

    if (!_cancelled) {
      dev.log('[OrderStatus] timeout after $maxAttempts attempts', name: 'order');
      state = state.copyWith(phase: OrderPhase.timeout);
    }
  }

  // Back off with 1.5× multiplier, capped at kOrderPollMaxDelay.
  Duration _backoff(Duration current) {
    final next =
        Duration(milliseconds: (current.inMilliseconds * 1.5).round());
    return next > kOrderPollMaxDelay ? kOrderPollMaxDelay : next;
  }
}

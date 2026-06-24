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
  }) =>
      OrderStatusState(
        phase: phase ?? this.phase,
        order: order ?? this.order,
        cleanUrl: cleanUrl ?? this.cleanUrl,
        needsTopup: needsTopup ?? this.needsTopup,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        attemptCount: attemptCount ?? this.attemptCount,
        currentDelay: currentDelay ?? this.currentDelay,
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
    } on ServerError catch (e) {
      if (e.isInsufficientCredits) {
        state = state.copyWith(phase: OrderPhase.done, needsTopup: true);
      } else {
        state = state.copyWith(
            phase: OrderPhase.done, errorMessage: e.message);
      }
    } on NetworkError {
      state = state.copyWith(
          phase: OrderPhase.done,
          errorMessage: 'No internet connection. Please try again.');
    }
  }

  void clearNeedsTopup() => state = state.copyWith(needsTopup: false);

  // -- Polling loop ---------------------------------------------------------

  Future<void> _startPolling({required Duration delay}) async {
    final maxAttempts = ref.read(orderPollMaxAttemptsProvider);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future<void>.delayed(delay);
      if (_cancelled) return;

      // Expose the current delay so the UI can say "checking again soon".
      state = state.copyWith(
          phase: OrderPhase.polling,
          attemptCount: attempt + 1,
          currentDelay: delay);

      try {
        final order =
            await ref.read(ordersRepositoryProvider).getOrder(_orderId);
        if (_cancelled) return;

        if (order.isDone) {
          state = state.copyWith(phase: OrderPhase.done, order: order);
          return;
        }

        if (order.isRejected) {
          state = state.copyWith(phase: OrderPhase.rejected, order: order);
          return;
        }

        // Still in progress — update the displayed order and back off.
        state = state.copyWith(order: order);
        delay = _backoff(delay);
      } on NetworkError {
        // Transient network failure: keep trying from a fresh short delay.
        // Do NOT count this as a wasted attempt toward maxAttempts — it
        // wasn't the server's response, just a connectivity blip.
        //
        // However we do still advance the loop counter so the poll
        // terminates eventually.  Reset delay to initial so recovery is
        // fast once the connection comes back.
        delay = ref.read(orderPollInitialDelayProvider);
      } on ServerError catch (e) {
        if (_cancelled) return;
        state = state.copyWith(
            phase: OrderPhase.networkError,
            errorMessage: e.message);
        return;
      }
    }

    if (!_cancelled) {
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

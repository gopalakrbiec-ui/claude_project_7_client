import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../controllers/credits_controller.dart';
import '../core/constants.dart';
import '../models/credits_balance.dart';
import '../models/payment_order.dart';
import '../repositories/credits_repository.dart';
import '../repositories/payments_repository.dart';

// ---------------------------------------------------------------------------
// Injectable poll tuning — overridden in tests so we don't wait real seconds.
// ---------------------------------------------------------------------------
final topupPollIntervalProvider =
    Provider<Duration>((_) => kTopupPollInterval);
final topupPollMaxAttemptsProvider =
    Provider<int>((_) => kTopupPollMaxAttempts);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum TopupStatus {
  idle,
  creatingOrder,    // POST /payments/create-order in flight
  awaitingCheckout, // Razorpay SDK is open; waiting for user
  confirming,       // Razorpay closed; polling GET /credits/balance
  success,          // balance confirmed increased by server
  failed,           // Razorpay reported a payment failure
  cancelled,        // user dismissed Razorpay without paying
  timeout,          // webhook didn't arrive within kTopupPollMaxAttempts
  error,            // network/server error before checkout could open
}

class TopupState {
  const TopupState({
    this.status = TopupStatus.idle,
    this.selectedAmountPaise,
    this.paymentOrder,
    this.balanceBefore,
    this.newBalance,
    this.errorMessage,
  });

  final TopupStatus status;
  final int? selectedAmountPaise;

  /// Populated once POST /payments/create-order succeeds.
  /// The widget reads paymentOrder.keyId to initialise Razorpay.
  final PaymentOrder? paymentOrder;

  /// Balance before checkout opened — used to detect credit arrival.
  final int? balanceBefore;

  /// Populated on success: the confirmed new balance from the server.
  final CreditsBalance? newBalance;

  final String? errorMessage;

  bool get isLoading =>
      status == TopupStatus.creatingOrder ||
      status == TopupStatus.confirming;

  TopupState copyWith({
    TopupStatus? status,
    int? selectedAmountPaise,
    PaymentOrder? paymentOrder,
    int? balanceBefore,
    CreditsBalance? newBalance,
    String? errorMessage,
    bool clearError = false,
  }) =>
      TopupState(
        status: status ?? this.status,
        selectedAmountPaise: selectedAmountPaise ?? this.selectedAmountPaise,
        paymentOrder: paymentOrder ?? this.paymentOrder,
        balanceBefore: balanceBefore ?? this.balanceBefore,
        newBalance: newBalance ?? this.newBalance,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// ---------------------------------------------------------------------------
// Preset amounts
// ---------------------------------------------------------------------------
const List<int> kTopupPresetsPaise = [
  5000,    // ₹50
  10000,   // ₹100
  20000,   // ₹200
  50000,   // ₹500
  100000,  // ₹1000
];

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final topupControllerProvider =
    NotifierProvider<TopupController, TopupState>(TopupController.new);

// ---------------------------------------------------------------------------
// Controller
//
// Design split:
//   - Controller owns the state machine and all business logic.
//   - The widget owns the Razorpay SDK instance (it requires a Flutter Activity
//     context and a MethodChannel that cannot run in unit tests).
//   - Widget → controller via onRazorpaySuccess / onRazorpayError / onRazorpayExternalWallet.
//   - Controller → widget via state.status == awaitingCheckout (widget opens SDK).
//
// Why we poll instead of trusting the Razorpay success callback:
//   Razorpay fires EVENT_PAYMENT_SUCCESS as soon as the UPI app reports success
//   to the SDK. However, the *actual* credit transfer happens on the backend via
//   a Razorpay webhook (POST from Razorpay servers → our backend). Network
//   delays, webhook retries, or UPI settlement timing mean the credit can land
//   anywhere from 1 second to 30+ seconds after the SDK callback. Marking
//   success from the device callback would show the user a balance that hasn't
//   actually been applied yet. We poll until the server-side balance confirms
//   the increase, so the user sees a balance that's guaranteed to be real.
//
// Why key_id comes from the server:
//   Razorpay issues separate key pairs for test and live environments. Hardcoding
//   either key into the APK means every environment switch requires a new build
//   and a Play Store submission. By returning key_id from POST /payments/create-order,
//   the backend can flip between test/live without any client-side change.
// ---------------------------------------------------------------------------
class TopupController extends Notifier<TopupState> {
  bool _pollingCancelled = false;

  @override
  TopupState build() {
    ref.onDispose(() => _pollingCancelled = true);
    return const TopupState();
  }

  // -- Step 1: user picks an amount; we hit the backend ----------------------

  Future<void> initTopup(int amountPaise) async {
    if (state.isLoading) return;

    // Snapshot balance now so we know what "increased" means.
    final balanceBefore =
        ref.read(creditsControllerProvider).valueOrNull?.balancePaise ?? 0;

    state = state.copyWith(
      status: TopupStatus.creatingOrder,
      selectedAmountPaise: amountPaise,
      clearError: true,
    );

    try {
      final order =
          await ref.read(paymentsRepositoryProvider).createOrder(amountPaise);

      // Transition to awaitingCheckout — widget detects this and opens Razorpay.
      state = state.copyWith(
        status: TopupStatus.awaitingCheckout,
        paymentOrder: order,
        balanceBefore: balanceBefore,
      );
    } on ServerError catch (e) {
      state = state.copyWith(
        status: TopupStatus.error,
        errorMessage: e.message,
      );
    } on NetworkError {
      state = state.copyWith(
        status: TopupStatus.error,
        errorMessage: 'No internet connection. Please try again.',
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        status: TopupStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // -- Step 2a: Razorpay closed with success (or external wallet) -----------
  // We do NOT mark success here. We start polling until the server confirms
  // the credit actually landed via its webhook.

  void onRazorpaySuccess() => _startPolling(state.balanceBefore ?? 0);

  // External wallet (e.g. PhonePe, Paytm) behaves the same — wait for webhook.
  void onRazorpayExternalWallet() => _startPolling(state.balanceBefore ?? 0);

  // -- Step 2b: Razorpay reported failure or cancellation --------------------
  // Razorpay error codes: 0 = user cancelled, all others = payment failure.

  void onRazorpayError(int code, String description) {
    if (code == 0) {
      state = state.copyWith(status: TopupStatus.cancelled);
    } else {
      state = state.copyWith(
        status: TopupStatus.failed,
        errorMessage: description,
      );
    }
  }

  // -- Reset so the user can try again (new amount or same) -----------------

  void reset() {
    _pollingCancelled = true;
    state = const TopupState();
  }

  // -- Polling --------------------------------------------------------------

  Future<void> _startPolling(int balanceBefore) async {
    _pollingCancelled = false;
    state = state.copyWith(status: TopupStatus.confirming);

    final interval = ref.read(topupPollIntervalProvider);
    final maxAttempts = ref.read(topupPollMaxAttemptsProvider);

    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(interval);
      if (_pollingCancelled) return;

      try {
        final balance =
            await ref.read(creditsRepositoryProvider).getBalance();
        if (_pollingCancelled) return;

        if (balance.balancePaise > balanceBefore) {
          // Credit confirmed. Propagate to global balance chip.
          ref.invalidate(creditsControllerProvider);
          state = state.copyWith(
            status: TopupStatus.success,
            newBalance: balance,
          );
          return;
        }
      } on ApiError {
        // Transient failure — keep polling; don't abort.
      }
    }

    if (!_pollingCancelled) {
      // Webhook hasn't arrived yet. Tell the user to check back.
      state = state.copyWith(status: TopupStatus.timeout);
    }
  }
}

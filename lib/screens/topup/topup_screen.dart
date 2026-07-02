import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../controllers/credits_controller.dart';
import '../../controllers/topup_controller.dart';
import '../../core/constants.dart';
import '../../models/payment_order.dart';

// ---------------------------------------------------------------------------
// TopupScreen
// ---------------------------------------------------------------------------
// Owns the Razorpay SDK instance. All state lives in TopupController.
// The SDK is a Flutter plugin that requires a live Activity — it cannot be
// created in a Notifier/isolate.
//
// Lifecycle:
//   1. User picks a preset amount → initTopup().
//   2. Controller POSTs to /payments/create-order → state = awaitingCheckout.
//   3. ref.listen detects awaitingCheckout → _openRazorpay() called once.
//   4. Razorpay SDK fires success/error/externalWallet → controller transitions.
//   5. Controller polls GET /credits/balance until balance rises.
//   6. UI shows success/timeout/failed/cancelled result.
// ---------------------------------------------------------------------------
class TopupScreen extends ConsumerStatefulWidget {
  const TopupScreen({super.key});

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  late final Razorpay _razorpay;
  bool _checkoutOpen = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // -- Razorpay SDK callbacks (fire on platform thread) ---------------------

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    _checkoutOpen = false;
    // Pass Razorpay's proof to the backend via POST /payments/verify.
    // Never call verify from error or dismiss callbacks.
    ref.read(topupControllerProvider.notifier).onRazorpaySuccess(
          paymentId: response.paymentId ?? '',
          orderId: response.orderId ?? '',
          signature: response.signature ?? '',
        );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _checkoutOpen = false;
    ref
        .read(topupControllerProvider.notifier)
        .onRazorpayError(response.code ?? -1, response.message ?? 'Payment failed');
  }

  void _onExternalWallet(ExternalWalletResponse _) {
    // External wallet (PhonePe / Paytm) — treat same as success path:
    // the credit arrives via webhook, not inline.
    _checkoutOpen = false;
    ref.read(topupControllerProvider.notifier).onRazorpayExternalWallet();
  }

  void _openRazorpay(PaymentOrder order) {
    if (_checkoutOpen) return;
    _checkoutOpen = true;
    _razorpay.open({
      // key_id from the server — never a hardcoded key.
      'key': order.keyId,
      'amount': order.amountPaise,
      'currency': order.currency,
      'order_id': order.gatewayOrderId,
      'name': 'Yaadein',
      'description': 'Credit Top-Up',
      'prefill': {
        // Focus on UPI — most rural users pay via UPI.
        'method': 'upi',
      },
      'external': {
        'wallets': ['paytm', 'phonepe', 'googlepay'],
      },
      'theme': {
        'color': '#FF6B23', // saffron brand colour
      },
      'retry': {
        // We handle retry ourselves; don't let Razorpay loop internally.
        'enabled': false,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    // Open Razorpay exactly once when the controller reaches awaitingCheckout.
    ref.listen(topupControllerProvider, (prev, next) {
      if (next.status == TopupStatus.awaitingCheckout &&
          prev?.status != TopupStatus.awaitingCheckout &&
          next.paymentOrder != null) {
        _openRazorpay(next.paymentOrder!);
      }
    });

    final topupState = ref.watch(topupControllerProvider);
    final balanceAsync = ref.watch(creditsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Credits')),
      body: _buildBody(context, topupState, balanceAsync),
    );
  }

  Widget _buildBody(BuildContext context, TopupState topupState,
      AsyncValue<dynamic> balanceAsync) {
    switch (topupState.status) {
      case TopupStatus.idle:
      case TopupStatus.creatingOrder:
      case TopupStatus.awaitingCheckout:
        return _PickAmountBody(
          topupState: topupState,
          balanceAsync: balanceAsync,
        );

      case TopupStatus.confirming:
        return const _ConfirmingBody();

      case TopupStatus.success:
        return _SuccessBody(topupState: topupState);

      case TopupStatus.failed:
        return _ResultBody(
          icon: Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          title: 'Payment Failed',
          subtitle: topupState.errorMessage ?? 'The payment could not be processed.',
          primaryLabel: 'Try Again',
          onPrimary: () =>
              ref.read(topupControllerProvider.notifier).reset(),
        );

      case TopupStatus.cancelled:
        return _ResultBody(
          icon: Icons.cancel_outlined,
          color: Theme.of(context).colorScheme.outline,
          title: 'Payment Cancelled',
          subtitle: 'No money was charged.',
          primaryLabel: 'Try Again',
          onPrimary: () =>
              ref.read(topupControllerProvider.notifier).reset(),
        );

      case TopupStatus.timeout:
        return _ResultBody(
          icon: Icons.hourglass_bottom_outlined,
          color: Theme.of(context).colorScheme.tertiary,
          title: 'Still Confirming…',
          // Timeout ≠ failure — the webhook may still arrive.
          subtitle:
              'Your payment was received but the credit is still being '
              'processed. Please check your balance in a few minutes. '
              'If it hasn\'t appeared after 30 minutes, contact support.',
          primaryLabel: 'Check Balance',
          onPrimary: () {
            ref.read(topupControllerProvider.notifier).reset();
            ref.read(creditsControllerProvider.notifier).refresh();
            context.go('/home');
          },
        );

      case TopupStatus.error:
        return _ResultBody(
          icon: Icons.wifi_off_outlined,
          color: Theme.of(context).colorScheme.error,
          title: 'Could Not Start Payment',
          subtitle: topupState.errorMessage ?? 'Something went wrong.',
          primaryLabel: 'Retry',
          onPrimary: () =>
              ref.read(topupControllerProvider.notifier).reset(),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-screens
// ---------------------------------------------------------------------------

class _PickAmountBody extends ConsumerWidget {
  const _PickAmountBody({required this.topupState, required this.balanceAsync});
  final TopupState topupState;
  final AsyncValue<dynamic> balanceAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentBalancePaise =
        (balanceAsync.valueOrNull?.balancePaise as int?) ?? 0;
    final currentBalanceDisplay =
        (balanceAsync.valueOrNull?.balanceRupees as String?) ?? '₹ …';
    final isLoading = topupState.isLoading;

    return ListView(
      padding: const EdgeInsets.all(kSpaceLg),
      children: [
        // Current balance card
        Container(
          padding: const EdgeInsets.all(kSpaceMd),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: kSpaceSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Balance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      )),
                  Text(currentBalanceDisplay,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: kSpaceLg),
        Text('Choose an amount to add',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: kSpaceMd),

        // Preset amount cards
        ...kTopupPresetsPaise.map((paise) {
          final rupees = paise ~/ 100;
          final afterTopup = currentBalancePaise + paise;
          final afterRupees = afterTopup ~/ 100;
          final isSelected = topupState.selectedAmountPaise == paise;

          return Padding(
            padding: const EdgeInsets.only(bottom: kSpaceSm),
            child: _AmountCard(
              rupees: rupees,
              afterRupees: afterRupees,
              selected: isSelected,
              disabled: isLoading,
              onTap: () => ref
                  .read(topupControllerProvider.notifier)
                  .initTopup(paise),
            ),
          );
        }),

        const SizedBox(height: kSpaceLg),

        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Text(
            'Payments powered by Razorpay. UPI, cards, and wallets accepted.',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.rupees,
    required this.afterRupees,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final int rupees;
  final int afterRupees;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final border = selected
        ? BorderSide(color: theme.colorScheme.primary, width: 2)
        : BorderSide.none;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpaceMd, vertical: kSpaceMd),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.fromBorderSide(border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add ₹$rupees',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                Text('Balance after: ₹$afterRupees',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline)),
              ],
            ),
            if (selected && disabled)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ConfirmingBody extends StatelessWidget {
  const _ConfirmingBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: kSpaceLg),
            Text('Confirming payment…',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: kSpaceSm),
            Text(
              'Please wait while we confirm your payment with the bank.\n'
              'This usually takes a few seconds.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBody extends ConsumerWidget {
  const _SuccessBody({required this.topupState});
  final TopupState topupState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final newBalance = topupState.newBalance;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: kSpaceLg),
            Text('Credits Added!', style: theme.textTheme.headlineSmall),
            if (newBalance != null) ...[
              const SizedBox(height: kSpaceSm),
              Text(
                'New balance: ${newBalance.balanceRupees}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: kSpaceXl),
            ElevatedButton(
              onPressed: () {
                ref.read(topupControllerProvider.notifier).reset();
                context.go('/home');
              },
              child: const Text('Back to Templates'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: kSpaceLg),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: kSpaceSm),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline)),
            const SizedBox(height: kSpaceXl),
            ElevatedButton(
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

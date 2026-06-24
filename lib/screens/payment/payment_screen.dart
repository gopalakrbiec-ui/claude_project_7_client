import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.priceDisplay,
  });

  final String orderId;
  final String priceDisplay;

  @override
  Widget build(BuildContext context) {
    // TODO:
    // 1. Call PaymentsController.createPaymentOrder(amount_paise).
    // 2. Receive key_id + razorpay_order_id from response.
    // 3. Initialise Razorpay with key_id from response — NEVER a hardcoded key.
    //    (razorpay_flutter package: Razorpay()..open(options))
    // 4. On payment success: call PaymentsController.verifyPayment(...)
    // 5. Navigate to order-status on success.
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payment, size: 80),
                    SizedBox(height: kSpaceMd),
                    Text('Razorpay integration wires here.\nkey_id comes from POST /payments/create-order.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  context.go('/home/order-status/placeholder-order-id'),
              child: Text('Pay $priceDisplay'),
            ),
            const SizedBox(height: kSpaceMd),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class CreateOrderScreen extends StatelessWidget {
  const CreateOrderScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    // TODO:
    // 1. Load template fields from TemplatesController.
    // 2. Build dynamic form from template.fields.
    // 3. On submit: generate idempotency_key UUID (once, store in state),
    //    call OrdersController.createOrder(), navigate to payment.
    //
    // IDEMPOTENCY RULE (CLAUDE.md): generate the UUID when the screen is
    // first built (e.g. in the controller's state), NOT in the button handler.
    // Reuse the same UUID on retry. Never regenerate on every tap.
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: Center(
                child: Text(
                  'Dynamic form fields load here\n(from template.fields after gen-api)',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => context.go(
                '/home/payment',
                extra: {
                  'orderId': 'placeholder-order-id',
                  'priceDisplay': '₹10.00',
                },
              ),
              child: const Text('Proceed to Payment'),
            ),
            const SizedBox(height: kSpaceMd),
          ],
        ),
      ),
    );
  }
}

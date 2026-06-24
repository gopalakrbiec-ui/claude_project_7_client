import 'package:flutter/material.dart';
import '../../core/constants.dart';

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    // TODO:
    // 1. Poll GET /orders/{orderId} every kOrderPollInterval via OrdersController.
    // 2. Show spinner while status == 'processing'.
    // 3. On 'completed': show result image + "Share on WhatsApp" button (one tap).
    // 4. On 'failed': show error + retry option.
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your Order')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(kSpaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: kSpaceLg),
              Text('We\'re creating your design…',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: kSpaceSm),
              Text('Order: $orderId',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: kSpaceXl),
              // WhatsApp share — one tap, per CLAUDE.md rule 5.
              ElevatedButton.icon(
                onPressed: null, // enabled once result_url is available
                icon: const Icon(Icons.share),
                label: const Text('Share on WhatsApp'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

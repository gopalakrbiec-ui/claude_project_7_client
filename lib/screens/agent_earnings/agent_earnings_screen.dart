import 'package:flutter/material.dart';
import '../../core/constants.dart';

class AgentEarningsScreen extends StatelessWidget {
  const AgentEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: load from AgentController -> AgentRepository -> GET /agent/commissions
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My Earnings')),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(kSpaceLg),
                child: Column(
                  children: [
                    Text('Total Earned',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    const SizedBox(height: kSpaceSm),
                    Text('₹ —',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 36,
                          color: theme.colorScheme.primary,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: kSpaceLg),
            Text('Recent Transactions',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: kSpaceSm),
            const Expanded(
              child: Center(
                child: Text('Transaction list loads here after gen-api'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

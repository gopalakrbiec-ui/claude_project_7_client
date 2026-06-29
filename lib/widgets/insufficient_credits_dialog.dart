import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api/api_error.dart';
import '../core/constants.dart';
import '../core/theme.dart';

/// Shows a bottom sheet when a 402 InsufficientCreditsError is received.
/// Call [InsufficientCreditsDialog.show] from any widget.
class InsufficientCreditsDialog extends StatelessWidget {
  const InsufficientCreditsDialog({super.key, required this.error});
  final InsufficientCreditsError error;

  static Future<void> show(BuildContext context, InsufficientCreditsError error) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => InsufficientCreditsDialog(error: error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kSpaceLg, kSpaceLg, kSpaceLg, kSpaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_outlined,
                  color: theme.colorScheme.error),
            ),
            const SizedBox(height: kSpaceMd),
            Text(
              'Not Enough Credits',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: kSpaceSm),
            Text(
              'You need ${error.requiredDisplay} but only have ${error.availableDisplay}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpaceLg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/home/topup');
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Top Up Credits'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSaffron,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: kSpaceSm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

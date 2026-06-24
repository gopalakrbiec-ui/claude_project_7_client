import 'package:flutter/material.dart';
import '../core/constants.dart';

// ---------------------------------------------------------------------------
// ErrorView — shared error/offline/empty presentation widget.
//
// Callers pass the appropriate [icon] and [message]; this widget owns only
// layout and styling. Keep business logic in the controller, not here.
// ---------------------------------------------------------------------------
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
    this.isOffline = false,
  });

  /// Use [ErrorView.offline] for connectivity errors — picks the right icon.
  const ErrorView.offline({
    super.key,
    required this.onRetry,
    this.message = 'No internet connection.\nPlease check your network.',
  })  : icon = Icons.wifi_off_outlined,
        isOffline = true;

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  /// When true the retry button label says "Retry when online" instead of
  /// "Retry", which is clearer for users who know they are offline.
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor =
        isOffline ? theme.colorScheme.outline : theme.colorScheme.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: kSpaceMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: kSpaceLg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(isOffline ? 'Retry when online' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

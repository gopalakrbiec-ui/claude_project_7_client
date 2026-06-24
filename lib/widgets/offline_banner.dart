import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/connectivity.dart';

// ---------------------------------------------------------------------------
// OfflineBanner
//
// Sits at the top of every screen (injected via MaterialApp.router's builder).
// Slides in/out with a smooth animation so it does not jolt the layout.
// When online, it takes zero height — no impact on any screen's layout.
// ---------------------------------------------------------------------------
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final theme = Theme.of(context);

    return AnimatedSlide(
      offset: isOnline ? const Offset(0, -1) : Offset.zero,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: isOnline ? 0 : 1,
        duration: const Duration(milliseconds: 280),
        child: Material(
          color: theme.colorScheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_outlined,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No internet connection',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

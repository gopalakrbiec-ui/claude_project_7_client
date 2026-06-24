import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/credits_controller.dart';

/// AppBar action chip showing the user's credit balance.
/// Reads balance_rupees from the server — never divides balance_paise itself.
class BalanceChip extends ConsumerWidget {
  const BalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(creditsControllerProvider);

    final label = balanceAsync.when(
      loading: () => '₹ …',
      error: (_, __) => '₹ ?',
      // balance_rupees is already formatted by the server.
      data: (b) => b.balanceRupees,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
      child: GestureDetector(
        // Tap to go to the top-up screen.
        onTap: () => context.go('/home/topup'),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

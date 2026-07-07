import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/credits_controller.dart';
import '../repositories/currency_repository.dart';

/// AppBar action chip showing the user's balance in Savi Coins.
class BalanceChip extends ConsumerWidget {
  const BalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(creditsControllerProvider);
    final currency = currencyOrFallback(ref.watch(currencyInfoProvider));

    final label = balanceAsync.when(
      loading: () => '… ${currency.symbol}',
      error: (_, __) => '? ${currency.symbol}',
      data: (b) => b.coinsDisplay(currency.symbol),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 4, top: 6, bottom: 6),
      child: GestureDetector(
        onTap: () => context.go('/home/topup'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

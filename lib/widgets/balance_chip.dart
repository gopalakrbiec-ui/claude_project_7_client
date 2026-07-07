import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/credits_controller.dart';

/// AppBar action chip showing the user's balance in Savi Coins.
class BalanceChip extends ConsumerWidget {
  const BalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(creditsControllerProvider);

    final countText = balanceAsync.when(
      loading: () => '…',
      error: (_, __) => '?',
      data: (b) => '${b.balanceCoins}',
    );

    return Padding(
      padding: const EdgeInsets.only(right: 4, top: 6, bottom: 6),
      child: GestureDetector(
        onTap: () => context.go('/home/topup'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                countText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 5),
              const _CoinIcon(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold coin icon that works on all Android versions — uses a Canvas-drawn
/// circle instead of the 🪙 emoji (Unicode 13.0, unsupported on older devices).
class _CoinIcon extends StatelessWidget {
  const _CoinIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _CoinPainter(),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer gold ring
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFFFFB300),
    );
    // Inner lighter gold face
    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()..color = const Color(0xFFFFD54F),
    );
    // Dollar/coin symbol
    final tp = TextPainter(
      text: const TextSpan(
        text: '✦',
        style: TextStyle(
          color: Color(0xFFFF8F00),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

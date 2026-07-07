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
    // Diamond shape in center
    final diamondSize = radius * 0.45;
    final diamondPath = Path()
      ..moveTo(center.dx, center.dy - diamondSize)        // top
      ..lineTo(center.dx + diamondSize * 0.65, center.dy) // right
      ..lineTo(center.dx, center.dy + diamondSize)        // bottom
      ..lineTo(center.dx - diamondSize * 0.65, center.dy) // left
      ..close();
    canvas.drawPath(
      diamondPath,
      Paint()..color = const Color(0xFFFF8F00),
    );
    // Diamond highlight — small lighter triangle on top half
    final highlightPath = Path()
      ..moveTo(center.dx, center.dy - diamondSize)
      ..lineTo(center.dx + diamondSize * 0.65, center.dy)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(
      highlightPath,
      Paint()..color = const Color(0xFFFFCC02).withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

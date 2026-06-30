import 'package:flutter/material.dart';

/// A branded social auth button.  Use the named constructors:
///   SocialAuthButton.google(...)
///   SocialAuthButton.facebook(...)
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton._({
    required this.label,
    required this.logo,
    required this.bgColor,
    required this.fgColor,
    required this.borderColor,
    required this.onPressed,
    required this.loading,
  });

  factory SocialAuthButton.google({
    required VoidCallback? onPressed,
    bool loading = false,
  }) =>
      SocialAuthButton._(
        label: 'Continue with Google',
        logo: _GoogleLogo(),
        bgColor: Colors.white,
        fgColor: const Color(0xFF3C4043),
        borderColor: const Color(0xFFDADCE0),
        onPressed: onPressed,
        loading: loading,
      );

  factory SocialAuthButton.facebook({
    required VoidCallback? onPressed,
    bool loading = false,
  }) =>
      SocialAuthButton._(
        label: 'Continue with Facebook / Instagram',
        logo: const _MetaLogo(),
        bgColor: const Color(0xFF1877F2),
        fgColor: Colors.white,
        borderColor: const Color(0xFF1877F2),
        onPressed: onPressed,
        loading: loading,
      );

  final String label;
  final Widget logo;
  final Color bgColor;
  final Color fgColor;
  final Color borderColor;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fgColor.withValues(alpha: 0.8)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  logo,
                  const SizedBox(width: 10),
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fgColor)),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Draw 4 coloured arcs
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22;

    const colors = [
      Color(0xFF4285F4), // blue  — right
      Color(0xFF34A853), // green — bottom
      Color(0xFFFBBC05), // yellow — left
      Color(0xFFEA4335), // red   — top
    ];
    const startAngles = [-0.1, 1.48, 3.24, 4.85];
    const sweeps = [1.58, 1.68, 1.55, 1.55];

    for (var i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
        startAngles[i],
        sweeps[i],
        false,
        paint,
      );
    }

    // White gap strip on the right (mimics the open space for the G bar)
    final gapPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(cx, cy - size.height * 0.1, r, size.height * 0.2),
        gapPaint);

    // Blue horizontal bar
    paint
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - r * 0.05, cy - size.height * 0.11, r * 1.05,
            size.height * 0.22),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetaLogo extends StatelessWidget {
  const _MetaLogo();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.facebook_rounded, color: Colors.white, size: 22);
  }
}

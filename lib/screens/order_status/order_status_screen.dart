import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/order_status_controller.dart';
import '../../core/constants.dart';
import '../../models/order.dart';

// ---------------------------------------------------------------------------
// Screen entry point
// ---------------------------------------------------------------------------
class OrderStatusScreen extends ConsumerStatefulWidget {
  const OrderStatusScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends ConsumerState<OrderStatusScreen> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    // Navigate to topup when remove-watermark returns 402.
    ref.listen(orderStatusControllerProvider(widget.orderId), (_, state) {
      if (state.needsTopup) {
        ref
            .read(orderStatusControllerProvider(widget.orderId).notifier)
            .clearNeedsTopup();
        context.push('/home/topup');
      }
    });

    final state = ref.watch(orderStatusControllerProvider(widget.orderId));

    final isPolling = state.phase == OrderPhase.polling;

    return Scaffold(
      extendBodyBehindAppBar: isPolling,
      appBar: AppBar(
        title: Text(
          'Your Order',
          style: TextStyle(color: isPolling ? Colors.white : null),
        ),
        backgroundColor: isPolling ? Colors.transparent : null,
        elevation: isPolling ? 0 : null,
        iconTheme: isPolling
            ? const IconThemeData(color: Colors.white)
            : null,
        // Allow user to go back and browse while job runs in background.
        automaticallyImplyLeading: true,
        actions: isPolling
            ? [
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text(
                    'Browse More',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ]
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, OrderStatusState state) {
    switch (state.phase) {
      case OrderPhase.polling:
        return _ShiningPollingBody(state: state, key: const ValueKey('polling'));

      case OrderPhase.done:
        return _DoneBody(
          state: state,
          isDownloading: _isDownloading,
          onShare: () => _shareOnWhatsApp(state.displayUrl),
          onSave: () => _saveToPhone(state.displayUrl),
          onRemoveWatermark: () => ref
              .read(orderStatusControllerProvider(widget.orderId).notifier)
              .removeWatermark(),
          key: const ValueKey('done'),
        );

      case OrderPhase.rejected:
        return _RejectedBody(
          order: state.order,
          onGoHome: () => context.go('/home'),
          onTryAgain: () => context.pop(),
          onDebugForceDone: () => ref
              .read(orderStatusControllerProvider(widget.orderId).notifier)
              .debugForceDone(),
          key: const ValueKey('rejected'),
        );

      case OrderPhase.timeout:
        return _MessageBody(
          icon: Icons.hourglass_bottom_outlined,
          iconColor: Theme.of(context).colorScheme.tertiary,
          title: 'Still working on it…',
          body: 'Your design is taking longer than usual. '
              'It will be ready soon — come back in a few minutes.',
          primaryLabel: 'Check Again',
          onPrimary: () => ref
              .read(orderStatusControllerProvider(widget.orderId).notifier)
              .retry(),
          secondaryLabel: 'Back to Home',
          onSecondary: () => context.go('/home'),
          key: const ValueKey('timeout'),
        );

      case OrderPhase.networkError:
        return _MessageBody(
          icon: Icons.wifi_off_outlined,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'No Internet Connection',
          body: state.errorMessage ??
              'Please check your connection and try again.',
          primaryLabel: 'Retry',
          onPrimary: () => ref
              .read(orderStatusControllerProvider(widget.orderId).notifier)
              .retry(),
          key: const ValueKey('networkError'),
        );

      case OrderPhase.removingWatermark:
        return _RemovingWatermarkBody(
            displayUrl: state.displayUrl,
            key: const ValueKey('removingWatermark'));
    }
  }

  // -- Download helpers (presentational, not business logic) ----------------

  Future<File> _downloadFile(String? url) async {
    if (url == null) throw Exception('No result URL available');
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/result_${DateTime.now().millisecondsSinceEpoch}.jpg';
    // Use a bounded Dio instance — bare Dio() has no timeout and can hang
    // indefinitely on a flaky rural network.
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));
    await dio.download(url, path);
    return File(path);
  }

  Future<void> _shareOnWhatsApp(String? url) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final file = await _downloadFile(url);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out the design I made with Yaadein! 🎉',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not prepare image for sharing.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _saveToPhone(String? url) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final file = await _downloadFile(url);
      await Gal.putImage(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to your photo gallery!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not save image. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Phase sub-widgets
// ---------------------------------------------------------------------------

// Theme colours matching the app icon gradient.
const _kSaffron = Color(0xFFFF6B23);
const _kMagenta = Color(0xFFC21860);
const _kGold    = Color(0xFFFFD700);

const _kMessages = [
  'AI is weaving your memory…',
  'Adding the magic touches…',
  'Crafting something beautiful…',
  'Sprinkling a little stardust…',
  'Almost ready for you…',
  'Polishing every detail…',
  'Making it perfect…',
  'Your design is taking shape…',
];

class _ShiningPollingBody extends StatefulWidget {
  const _ShiningPollingBody({super.key, required this.state});
  final OrderStatusState state;

  @override
  State<_ShiningPollingBody> createState() => _ShiningPollingBodyState();
}

class _ShiningPollingBodyState extends State<_ShiningPollingBody>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _msgCtrl;
  int _msgIdx = 0;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _msgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
    _msgCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _msgIdx = (_msgIdx + 1) % _kMessages.length);
      }
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.state.order;
    final statusLabel = switch (order?.status) {
      'queued'     => 'In queue…',
      'moderating' => 'Reviewing content…',
      'generating' => 'Generating…',
      _            => 'Processing…',
    };

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kSaffron, _kMagenta],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Central animated piece
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_spinCtrl, _pulseCtrl]),
                    builder: (_, __) => CustomPaint(
                      size: const Size(260, 260),
                      painter: _ShiningPainter(
                        spin: _spinCtrl.value,
                        pulse: _pulseCtrl.value,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Fading message
                AnimatedBuilder(
                  animation: _msgCtrl,
                  builder: (_, __) {
                    final t = _msgCtrl.value;
                    final opacity = (t < 0.15
                        ? t / 0.15
                        : t > 0.85
                            ? (1.0 - t) / 0.15
                            : 1.0)
                        .clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _kMessages[_msgIdx],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                Text(
                  statusLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                  ),
                ),

                const Spacer(flex: 1),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                  child: Text(
                    'You can leave this screen — we\'ll keep working.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),

      ],
    );
  }
}



// ---------------------------------------------------------------------------

class _ShiningPainter extends CustomPainter {
  const _ShiningPainter({required this.spin, required this.pulse});

  final double spin;   // 0..1
  final double pulse;  // 0..1 (easeInOut repeated reverse)

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    _drawRays(canvas, cx, cy, r);
    _drawOrbit(canvas, cx, cy, r);
    _drawGlow(canvas, cx, cy, r);
    _drawCamera(canvas, cx, cy, r);
    _drawSparkles(canvas, cx, cy, r);
  }

  void _drawRays(Canvas canvas, double cx, double cy, double r) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 12; i++) {
      final angle = spin * 2 * math.pi + i * math.pi / 6;
      final innerR = r * 0.52;
      final outerR = r * (0.78 + 0.08 * math.sin(spin * math.pi * 4 + i));
      final opacity = (0.15 + 0.25 * math.sin(spin * math.pi * 2 + i * 0.5))
          .clamp(0.05, 0.4);
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawLine(
        Offset(cx + math.cos(angle) * innerR, cy + math.sin(angle) * innerR),
        Offset(cx + math.cos(angle) * outerR, cy + math.sin(angle) * outerR),
        paint,
      );
    }
  }

  void _drawOrbit(Canvas canvas, double cx, double cy, double r) {
    final paint = Paint()..style = PaintingStyle.fill;
    const count = 10;
    for (var i = 0; i < count; i++) {
      final angle = -spin * 2 * math.pi * 1.3 + i * 2 * math.pi / count;
      final orbitR = r * 0.82;
      final x = cx + math.cos(angle) * orbitR;
      final y = cy + math.sin(angle) * orbitR;
      final dotR = 3.5 + 1.5 * math.sin(spin * math.pi * 3 + i);
      final opacity = 0.5 + 0.5 * math.sin(spin * math.pi * 2 + i * 0.8);
      paint.color = _kGold.withOpacity(opacity.clamp(0.3, 1.0));
      canvas.drawCircle(Offset(x, y), dotR, paint);
    }
  }

  void _drawGlow(Canvas canvas, double cx, double cy, double r) {
    final glowR = r * (0.44 + 0.04 * pulse);
    final shader = RadialGradient(
      colors: [
        Colors.white.withOpacity(0.25 + 0.1 * pulse),
        _kSaffron.withOpacity(0.45),
        _kMagenta.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR * 1.5));

    canvas.drawCircle(
      Offset(cx, cy),
      glowR * 1.5,
      Paint()..shader = shader,
    );

    // Solid gradient disc
    final discShader = RadialGradient(
      colors: [
        Color.lerp(_kSaffron, Colors.white, 0.3)!,
        _kMagenta,
      ],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR));
    canvas.drawCircle(
      Offset(cx, cy),
      glowR,
      Paint()..shader = discShader,
    );
  }

  void _drawCamera(Canvas canvas, double cx, double cy, double r) {
    final scale = r / 130;
    final white = Paint()..color = Colors.white;

    // Camera body
    final bw = 72 * scale;
    final bh = 52 * scale;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 4 * scale), width: bw, height: bh),
      Radius.circular(10 * scale),
    );
    canvas.drawRRect(bodyRect, white);

    // Shutter bump
    final bumpW = 18 * scale;
    final bumpH = 10 * scale;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - bumpW / 2, cy - bh / 2 - bumpH / 2 + 4 * scale, bumpW, bumpH),
        Radius.circular(4 * scale),
      ),
      white,
    );

    // Lens ring (white)
    final lensR = 17 * scale;
    canvas.drawCircle(Offset(cx, cy + 4 * scale), lensR, white);

    // Lens inner (gradient bg colour)
    final innerR = lensR * 0.68;
    final lensShader = RadialGradient(
      colors: [_kSaffron, _kMagenta],
    ).createShader(
      Rect.fromCircle(center: Offset(cx, cy + 4 * scale), radius: innerR),
    );
    canvas.drawCircle(
      Offset(cx, cy + 4 * scale),
      innerR,
      Paint()..shader = lensShader,
    );

    // Heart inside lens
    _drawHeart(canvas, cx, cy + 4 * scale, 10 * scale);
  }

  void _drawHeart(Canvas canvas, double cx, double cy, double s) {
    final path = Path();
    // Heart via two cubic bezier arcs
    path.moveTo(cx, cy + s * 0.9);
    path.cubicTo(cx - s * 1.8, cy + s * 0.3, cx - s * 1.8, cy - s * 0.9,
        cx, cy - s * 0.3);
    path.cubicTo(cx + s * 1.8, cy - s * 0.9, cx + s * 1.8, cy + s * 0.3,
        cx, cy + s * 0.9);
    path.close();
    canvas.drawPath(path, Paint()..color = _kMagenta);
  }

  void _drawSparkles(Canvas canvas, double cx, double cy, double r) {
    final offsets = [
      const Offset(-0.60, -0.58),
      const Offset( 0.62, -0.52),
      const Offset(-0.58,  0.56),
      const Offset( 0.58,  0.62),
      const Offset( 0.02, -0.78),
    ];
    final sizes = [10.0, 8.0, 7.0, 9.0, 6.0];
    for (var i = 0; i < offsets.length; i++) {
      final twinkle = 0.5 + 0.5 * math.sin(spin * math.pi * 4 + i * 1.3);
      _drawStar(
        canvas,
        cx + offsets[i].dx * r,
        cy + offsets[i].dy * r,
        sizes[i] * (0.7 + 0.3 * twinkle),
        _kGold.withOpacity(0.6 + 0.4 * twinkle),
      );
    }
  }

  void _drawStar(Canvas canvas, double x, double y, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final dist = i.isEven ? r : r * 0.38;
      final px = x + math.cos(a) * dist;
      final py = y + math.sin(a) * dist;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ShiningPainter old) =>
      old.spin != spin || old.pulse != pulse;
}

// ---------------------------------------------------------------------------

class _DoneBody extends StatelessWidget {
  const _DoneBody({
    super.key,
    required this.state,
    required this.isDownloading,
    required this.onShare,
    required this.onSave,
    required this.onRemoveWatermark,
  });

  final OrderStatusState state;
  final bool isDownloading;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onRemoveWatermark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayUrl = state.displayUrl;
    final hasCleanVersion = state.cleanUrl != null;
    final isRemoving = state.phase == OrderPhase.removingWatermark;
    final priceDisplay = state.order?.priceDisplay ?? '';

    return Column(
      children: [
        // Result image — takes the majority of the screen
        Expanded(
          child: _ResultImage(url: displayUrl),
        ),

        // Gradient success banner
        Container(
          decoration: const BoxDecoration(gradient: kBrandGradient),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                hasCleanVersion ? 'Watermark Removed!' : 'Your design is ready!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Compact action row
        Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: isDownloading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.share_rounded, size: 26,
                            color: Color(0xFFFF6B23)),
                    label: 'WhatsApp',
                    onTap: isDownloading ? null : onShare,
                  ),
                  _ActionButton(
                    icon: const Icon(Icons.save_alt_rounded, size: 26,
                        color: Color(0xFFFF6B23)),
                    label: 'Save',
                    onTap: isDownloading ? null : onSave,
                  ),
                  if (!hasCleanVersion)
                    _ActionButton(
                      icon: isRemoving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Icon(Icons.auto_fix_high_outlined, size: 26,
                              color: Color(0xFFFF6B23)),
                      label: isRemoving
                          ? 'Removing…'
                          : 'No Watermark\n$priceDisplay',
                      onTap: isRemoving ? null : onRemoveWatermark,
                    ),
                ],
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  state.errorMessage!,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
            child: Icon(Icons.image_outlined, size: 72)),
      );
    }
    // Decode at the physical render width so the bitmap is not larger than
    // what the screen can actually display.  LayoutBuilder gives us logical
    // pixels; multiply by devicePixelRatio to get physical pixels (what
    // memCacheWidth expects).
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth =
            (constraints.maxWidth * dpr).clamp(1.0, 1080.0).toInt();
        return CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.cover,
          memCacheWidth: cacheWidth,
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, size: 72)),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RemovingWatermarkBody extends StatelessWidget {
  const _RemovingWatermarkBody({super.key, required this.displayUrl});
  final String? displayUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Dim the image behind the overlay
        Opacity(
          opacity: 0.4,
          child: _ResultImage(url: displayUrl),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: kSpaceMd),
              Text('Removing watermark…',
                  style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _RejectedBody extends StatelessWidget {
  const _RejectedBody({
    super.key,
    this.order,
    required this.onGoHome,
    required this.onTryAgain,
    required this.onDebugForceDone,
  });
  final Order? order;
  final VoidCallback onGoHome;
  final VoidCallback onTryAgain;
  final VoidCallback onDebugForceDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = order?.rejectionReason;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_outlined,
                size: 80, color: theme.colorScheme.error),
            const SizedBox(height: kSpaceLg),
            Text(
              'We couldn\'t create this design',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpaceMd),
            Container(
              padding: const EdgeInsets.all(kSpaceMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                reason ??
                    'This request was rejected during moderation. '
                    'Your credits have been fully refunded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer),
                textAlign: TextAlign.center,
              ),
            ),
            if (kDebugMode && reason == null) ...[
              const SizedBox(height: kSpaceSm),
              Text(
                'DEBUG: no rejection_reason / moderation_reason / reason in API response',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: kSpaceXl),
            ElevatedButton(
              onPressed: onTryAgain,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: kSpaceSm),
            OutlinedButton(
              onPressed: onGoHome,
              child: const Text('Try a Different Template'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: kSpaceLg),
              const Divider(),
              const SizedBox(height: kSpaceSm),
              Text(
                '🐛 DEBUG',
                style: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: kSpaceSm),
              OutlinedButton.icon(
                onPressed: onDebugForceDone,
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip to Done (test download/share)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: iconColor),
            const SizedBox(height: kSpaceLg),
            Text(title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: kSpaceSm),
            Text(body,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center),
            const SizedBox(height: kSpaceXl),
            ElevatedButton(
                onPressed: onPrimary, child: Text(primaryLabel)),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: kSpaceSm),
              OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../controllers/tool_job_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../repositories/currency_repository.dart';
import '../../repositories/tools_repository.dart' show AiToolDef, toolsRepositoryProvider;
import '../tools/tools_screen.dart' show toolsListProvider, ToolWorkScreen;

// Theme colours
const _kSaffron = Color(0xFFFF6B23);
const _kMagenta = Color(0xFFC21860);
const _kGold    = Color(0xFFFFD700);

const _kMessages = [
  'AI is processing your photo…',
  'Adding the magic touches…',
  'Crafting something beautiful…',
  'Sprinkling a little stardust…',
  'Almost ready for you…',
  'Polishing every detail…',
  'Making it perfect…',
  'Your creation is taking shape…',
];

const _kMergeMessages = [
  'Merging your photos…',
  'Blending faces and scenes…',
  'AI is weaving your photos together…',
  'Combining details from all photos…',
  'Almost there — final touches…',
  'Creating your merged photo…',
  'Crafting something special…',
  'Polishing the final merge…',
];

// ---------------------------------------------------------------------------
// Screen entry point
// ---------------------------------------------------------------------------
class ToolJobStatusScreen extends ConsumerStatefulWidget {
  const ToolJobStatusScreen({
    super.key,
    required this.jobId,
    required this.toolName,
    this.costDisplay,
  });

  final String jobId;
  final String toolName;
  final String? costDisplay;

  @override
  ConsumerState<ToolJobStatusScreen> createState() =>
      _ToolJobStatusScreenState();
}

class _ToolJobStatusScreenState extends ConsumerState<ToolJobStatusScreen> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(toolJobControllerProvider(widget.jobId));
    final isPolling = state.phase == ToolJobPhase.polling;

    return Scaffold(
      extendBodyBehindAppBar: isPolling,
      appBar: AppBar(
        title: Text(
          widget.toolName,
          style: TextStyle(color: isPolling ? Colors.white : null),
        ),
        backgroundColor: isPolling ? Colors.transparent : null,
        elevation: isPolling ? 0 : null,
        iconTheme: isPolling ? const IconThemeData(color: Colors.white) : null,
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

  static bool _isVideoResult(String toolName, String? url) {
    final n = toolName.toLowerCase();
    if (n.contains('animate') || n.contains('kling') || n.contains('veo') ||
        n.contains('seedance') || n.contains('wan') || n.contains('video')) {
      return true;
    }
    if (url == null) return false;
    final u = url.toLowerCase().split('?').first; // strip query params
    return u.endsWith('.mp4') || u.endsWith('.mov') || u.endsWith('.webm');
  }

  Widget _buildBody(BuildContext context, ToolJobState state) {
    switch (state.phase) {
      case ToolJobPhase.polling:
        final isPhotoMerge = widget.toolName.toLowerCase().contains('photo merge') ||
            widget.toolName.toLowerCase().contains('photo-merge');
        return _PollingBody(
          key: const ValueKey('polling'),
          messages: isPhotoMerge ? _kMergeMessages : _kMessages,
        );

      case ToolJobPhase.done:
        final isVideo = state.isVideo || _isVideoResult(widget.toolName, state.resultUrl);
        return _DoneBody(
          resultUrl: state.resultUrl,
          isVideo: isVideo,
          costDisplay: state.costPaise > 0
              ? state.costCoins(currencyOrFallback(ref.read(currencyInfoProvider)).symbol)
              : widget.costDisplay,
          isDownloading: _isDownloading,
          onShare: () => _share(isVideo),
          onSave: () => _save(isVideo),
          onAnimate: isVideo ? null : () => _animateThis(state.resultUrl),
          key: const ValueKey('done'),
        );

      case ToolJobPhase.failed:
        return _MessageBody(
          icon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Processing Failed',
          body: state.error ?? 'Something went wrong. Your credits were not deducted.',
          primaryLabel: 'Try Again',
          onPrimary: () => context.pop(),
          secondaryLabel: 'Back to Home',
          onSecondary: () => context.go('/home'),
          key: const ValueKey('failed'),
        );

      case ToolJobPhase.timeout:
        return _MessageBody(
          icon: Icons.hourglass_bottom_outlined,
          iconColor: Theme.of(context).colorScheme.tertiary,
          title: 'Still working on it…',
          body: 'Your photo is taking longer than usual. Come back in a few minutes.',
          primaryLabel: 'Check Again',
          onPrimary: () => ref
              .read(toolJobControllerProvider(widget.jobId).notifier)
              .retry(),
          secondaryLabel: 'Back to Home',
          onSecondary: () => context.go('/home'),
          key: const ValueKey('timeout'),
        );

      case ToolJobPhase.networkError:
        return _MessageBody(
          icon: Icons.wifi_off_outlined,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'No Internet Connection',
          body: state.error ?? 'Please check your connection and try again.',
          primaryLabel: 'Retry',
          onPrimary: () => ref
              .read(toolJobControllerProvider(widget.jobId).notifier)
              .retry(),
          key: const ValueKey('networkError'),
        );
    }
  }

  Future<void> _animateThis(String? resultUrl) async {
    if (resultUrl == null) return;
    try {
      final tools = await ref.read(toolsListProvider.future);
      AiToolDef? animateTool;
      for (final t in tools) {
        if (t.name.toLowerCase().contains('animate')) { animateTool = t; break; }
      }
      if (animateTool == null || !mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ToolWorkScreen(tool: animateTool!, preloadedSourceUrl: resultUrl),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not load animation tool. Please try from the tools menu.'),
        ));
      }
    }
  }

  /// Re-fetches a fresh presigned URL from the backend right before sharing.
  Future<String> _freshUrl() async {
    final status = await ref.read(toolsRepositoryProvider).getToolStatus(widget.jobId);
    if (status.resultUrl == null) throw Exception('No result URL');
    return status.resultUrl!;
  }

  Future<File> _downloadFile(String url, {required bool isVideo}) async {
    final ext = isVideo ? 'mp4' : 'png';
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/tool_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ));
    await dio.download(url, path);
    return File(path);
  }

  Future<void> _share(bool isVideo) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final url = await _freshUrl();
      final file = await _downloadFile(url, isVideo: isVideo);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Made with Savi Nenapu AI Tools! ✨',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare image for sharing.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _save(bool isVideo) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final url = await _freshUrl();
      final file = await _downloadFile(url, isVideo: isVideo);
      if (isVideo) {
        await Gal.putVideo(file.path);
      } else {
        await Gal.putImage(file.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isVideo
                  ? 'Video saved to your gallery!'
                  : 'Saved to your photo gallery!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Polling body — animated gradient spinner matching order_status_screen
// ---------------------------------------------------------------------------
class _PollingBody extends StatefulWidget {
  const _PollingBody({super.key, this.messages = _kMessages});
  final List<String> messages;

  @override
  State<_PollingBody> createState() => _PollingBodyState();
}

class _PollingBodyState extends State<_PollingBody>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _msgCtrl;
  int _msgIdx = 0;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _msgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat();
    _msgCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _msgIdx = (_msgIdx + 1) % widget.messages.length);
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
    return Container(
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
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_spinCtrl, _pulseCtrl]),
                builder: (_, __) => CustomPaint(
                  size: const Size(260, 260),
                  painter: _SpinPainter(
                    spin: _spinCtrl.value,
                    pulse: _pulseCtrl.value,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
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
                      widget.messages[_msgIdx],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Processing…',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
            ),
            const Spacer(flex: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
              child: Text(
                'You can leave this screen — we\'ll keep working.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class _SpinPainter extends CustomPainter {
  const _SpinPainter({required this.spin, required this.pulse});
  final double spin;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    _rays(canvas, cx, cy, r);
    _orbit(canvas, cx, cy, r);
    _glow(canvas, cx, cy, r);
    _icon(canvas, cx, cy, r);
    _sparkles(canvas, cx, cy, r);
  }

  void _rays(Canvas canvas, double cx, double cy, double r) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = spin * 2 * math.pi + i * math.pi / 6;
      final inner = r * 0.52;
      final outer = r * (0.78 + 0.08 * math.sin(spin * math.pi * 4 + i));
      final op = (0.15 + 0.25 * math.sin(spin * math.pi * 2 + i * 0.5))
          .clamp(0.05, 0.4);
      p.color = Colors.white.withValues(alpha: op);
      canvas.drawLine(
        Offset(cx + math.cos(a) * inner, cy + math.sin(a) * inner),
        Offset(cx + math.cos(a) * outer, cy + math.sin(a) * outer),
        p,
      );
    }
  }

  void _orbit(Canvas canvas, double cx, double cy, double r) {
    final p = Paint()..style = PaintingStyle.fill;
    const n = 10;
    for (var i = 0; i < n; i++) {
      final a = -spin * 2 * math.pi * 1.3 + i * 2 * math.pi / n;
      final x = cx + math.cos(a) * r * 0.82;
      final y = cy + math.sin(a) * r * 0.82;
      final dr = 3.5 + 1.5 * math.sin(spin * math.pi * 3 + i);
      final op = (0.5 + 0.5 * math.sin(spin * math.pi * 2 + i * 0.8))
          .clamp(0.3, 1.0);
      p.color = _kGold.withValues(alpha: op);
      canvas.drawCircle(Offset(x, y), dr, p);
    }
  }

  void _glow(Canvas canvas, double cx, double cy, double r) {
    final gr = r * (0.44 + 0.04 * pulse);
    final s1 = RadialGradient(colors: [
      Colors.white.withValues(alpha: 0.25 + 0.1 * pulse),
      _kSaffron.withValues(alpha: 0.45),
      _kMagenta.withValues(alpha: 0.0),
    ], stops: const [
      0.0, 0.5, 1.0
    ]).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: gr * 1.5));
    canvas.drawCircle(
        Offset(cx, cy), gr * 1.5, Paint()..shader = s1);
    final s2 = const RadialGradient(
      colors: [Color(0xFFFF8C50), _kMagenta],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: gr));
    canvas.drawCircle(Offset(cx, cy), gr, Paint()..shader = s2);
  }

  void _icon(Canvas canvas, double cx, double cy, double r) {
    final sc = r / 130;
    final wp = Paint()..color = Colors.white;
    // Camera body
    final bw = 72 * sc;
    final bh = 52 * sc;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy + 4 * sc), width: bw, height: bh),
        Radius.circular(10 * sc),
      ),
      wp,
    );
    // Shutter bump
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 9 * sc, cy - bh / 2 - 5 * sc + 4 * sc,
            18 * sc, 10 * sc),
        Radius.circular(4 * sc),
      ),
      wp,
    );
    // Lens ring
    final lr = 17 * sc;
    canvas.drawCircle(Offset(cx, cy + 4 * sc), lr, wp);
    // Lens inner
    final ir = lr * 0.68;
    canvas.drawCircle(
      Offset(cx, cy + 4 * sc),
      ir,
      Paint()
        ..shader = const RadialGradient(colors: [_kSaffron, _kMagenta])
            .createShader(Rect.fromCircle(
                center: Offset(cx, cy + 4 * sc), radius: ir)),
    );
    // Star inside lens
    _star(canvas, cx, cy + 4 * sc, 9 * sc,
        Colors.white.withValues(alpha: 0.9));
  }

  void _star(Canvas canvas, double x, double y, double r, Color c) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final d = i.isEven ? r : r * 0.4;
      final px = x + math.cos(a) * d;
      final py = y + math.sin(a) * d;
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = c);
  }

  void _sparkles(Canvas canvas, double cx, double cy, double r) {
    final offsets = [
      const Offset(-0.60, -0.58),
      const Offset(0.62, -0.52),
      const Offset(-0.58, 0.56),
      const Offset(0.58, 0.62),
      const Offset(0.02, -0.78),
    ];
    final sizes = [10.0, 8.0, 7.0, 9.0, 6.0];
    for (var i = 0; i < offsets.length; i++) {
      final t = 0.5 + 0.5 * math.sin(spin * math.pi * 4 + i * 1.3);
      _star(
        canvas,
        cx + offsets[i].dx * r,
        cy + offsets[i].dy * r,
        sizes[i] * (0.7 + 0.3 * t),
        _kGold.withValues(alpha: 0.6 + 0.4 * t),
      );
    }
  }

  @override
  bool shouldRepaint(_SpinPainter old) =>
      old.spin != spin || old.pulse != pulse;
}

// ---------------------------------------------------------------------------
// Done body — full-screen image + compact share/save row
// ---------------------------------------------------------------------------
class _DoneBody extends StatelessWidget {
  const _DoneBody({
    super.key,
    required this.resultUrl,
    required this.isVideo,
    required this.costDisplay,
    required this.isDownloading,
    required this.onShare,
    required this.onSave,
    this.onAnimate,
  });

  final String? resultUrl;
  final bool isVideo;
  final String? costDisplay;
  final bool isDownloading;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback? onAnimate;

  bool get _isVideo => isVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (onAnimate != null)
          InkWell(
            onTap: onAnimate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('✨  Animate This',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        Expanded(
          child: resultUrl != null
              ? _isVideo
                  ? _VideoPlayer(url: resultUrl!)
                  : LayoutBuilder(builder: (ctx, c) {
                      final dpr = MediaQuery.devicePixelRatioOf(ctx);
                      final cacheWidth =
                          (c.maxWidth * dpr).clamp(1.0, 1080.0).toInt();
                      return CachedNetworkImage(
                        imageUrl: resultUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: cacheWidth,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 72)),
                      );
                    })
              : ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                      child: Icon(Icons.image_outlined, size: 72)),
                ),
        ),
        Container(
          decoration: const BoxDecoration(gradient: kBrandGradient),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                costDisplay != null
                    ? 'Done! $costDisplay deducted'
                    : 'Your creation is ready!',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionBtn(
                icon: isDownloading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.share_rounded,
                        size: 26, color: _kSaffron),
                label: 'WhatsApp',
                onTap: isDownloading ? null : onShare,
              ),
              _ActionBtn(
                icon: const Icon(Icons.save_alt_rounded,
                    size: 26, color: _kSaffron),
                label: 'Save',
                onTap: isDownloading ? null : onSave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Inline video player for animate-photo results
// ---------------------------------------------------------------------------
class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.url});
  final String url;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..setVolume(0);
    final prev = _ctrl;
    _ctrl = ctrl;
    await prev?.dispose();
    try {
      await ctrl.initialize();
      if (mounted && ctrl == _ctrl) {
        setState(() => _initialized = true);
        ctrl.play();
      }
    } catch (_) {
      if (mounted && ctrl == _ctrl) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Could not play video',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() { _hasError = false; _initialized = false; });
                _initPlayer();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final ctrl = _ctrl!;
    return GestureDetector(
      onTap: () {
        if (ctrl.value.isPlaying) {
          ctrl.pause();
        } else {
          ctrl.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: ctrl.value.size.width,
                height: ctrl.value.size.height,
                child: VideoPlayer(ctrl),
              ),
            ),
          ),
          if (!ctrl.value.isPlaying)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 48),
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.icon, required this.label, required this.onTap});
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic message body (failed / timeout / network error)
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
                  onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

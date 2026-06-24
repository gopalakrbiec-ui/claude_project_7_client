import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Order'),
        // Prevent accidental back-nav while result is loading.
        automaticallyImplyLeading: state.isTerminal,
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
        return _PollingBody(order: state.order, key: const ValueKey('polling'));

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
    await Dio().download(url, path);
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

class _PollingBody extends StatelessWidget {
  const _PollingBody({super.key, this.order});
  final Order? order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _progressLabel(order?.status);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingIcon(),
            const SizedBox(height: kSpaceLg),
            Text(label,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: kSpaceSm),
            Text(
              'This usually takes 1–2 minutes. You can leave this screen — '
              'we\'ll keep working.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _progressLabel(String? status) => switch (status) {
        'queued' => 'Your design is in the queue…',
        'moderating' => 'Reviewing your content…',
        'generating' => 'Creating your design…',
        _ => 'Processing your order…',
      };
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        Icons.auto_awesome,
        size: 80,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
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
        // Result image — takes ~60 % of screen
        Expanded(
          flex: 60,
          child: _ResultImage(url: displayUrl),
        ),

        // Action panel
        Expanded(
          flex: 40,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                kSpaceLg, kSpaceMd, kSpaceLg, kSpaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasCleanVersion
                      ? 'Watermark Removed!'
                      : 'Your design is ready!',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: kSpaceMd),

                // Primary CTA: WhatsApp (the growth loop)
                ElevatedButton.icon(
                  onPressed: isDownloading ? null : onShare,
                  icon: isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.share),
                  label: const Text('Share on WhatsApp'),
                ),
                const SizedBox(height: kSpaceSm),

                // Save to phone
                OutlinedButton.icon(
                  onPressed: isDownloading ? null : onSave,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save to Phone'),
                ),

                if (!hasCleanVersion) ...[
                  const SizedBox(height: kSpaceSm),
                  // Remove watermark (paid upgrade)
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: kSpaceXs),
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: isRemoving ? null : onRemoveWatermark,
                    icon: isRemoving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_fix_high_outlined),
                    label: Text(
                      isRemoving
                          ? 'Removing watermark…'
                          : 'Remove Watermark  •  $priceDisplay',
                    ),
                  ),
                ],
              ],
            ),
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
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.contain,
      placeholder: (_, __) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, size: 72)),
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
  const _RejectedBody({super.key, this.order, required this.onGoHome});
  final Order? order;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                'This request contains content we\'re unable to process — '
                'for example, real people, public figures, or unsupported '
                'themes. Your credits have been fully refunded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: kSpaceXl),
            ElevatedButton(
              onPressed: onGoHome,
              child: const Text('Try a Different Template'),
            ),
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

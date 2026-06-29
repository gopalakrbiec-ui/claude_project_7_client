import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_error.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../repositories/orders_repository.dart';
import '../../repositories/tools_repository.dart';
import '../../widgets/balance_chip.dart';
import '../../widgets/insufficient_credits_dialog.dart';

// ---------------------------------------------------------------------------
// Tool enum
// ---------------------------------------------------------------------------
enum AiTool { restore, bgRemove, upscale }

extension AiToolExt on AiTool {
  String get title => switch (this) {
        AiTool.restore   => 'Photo Restore',
        AiTool.bgRemove  => 'Remove Background',
        AiTool.upscale   => 'Upscale 4×',
      };

  String get subtitle => switch (this) {
        AiTool.restore   => 'Repair old, blurry or damaged photos',
        AiTool.bgRemove  => 'Remove background — get a transparent PNG',
        AiTool.upscale   => 'Enhance resolution by 4× — DSLR quality',
      };

  IconData get icon => switch (this) {
        AiTool.restore   => Icons.auto_fix_high,
        AiTool.bgRemove  => Icons.layers_clear_outlined,
        AiTool.upscale   => Icons.hd_outlined,
      };

  List<Color> get gradient => switch (this) {
        AiTool.restore   => [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
        AiTool.bgRemove  => [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
        AiTool.upscale   => [const Color(0xFF6A1B9A), const Color(0xFFCE93D8)],
      };
}

// ---------------------------------------------------------------------------
// Tools hub screen
// ---------------------------------------------------------------------------
class ToolsScreen extends StatelessWidget {
  const ToolsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tools'),
        actions: [const BalanceChip()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(kSpaceMd),
        children: [
          Text(
            'Instant AI Magic',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Results ready in ~10–30 seconds. Credits deducted on use.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: kSpaceLg),
          ...AiTool.values.map(
            (tool) => Padding(
              padding: const EdgeInsets.only(bottom: kSpaceMd),
              child: _ToolCard(tool: tool),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});
  final AiTool tool;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Coming soon — stay tuned!')),
          );
        },
        child: Row(
          children: [
            Container(
              width: 72,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: tool.gradient,
                ),
              ),
              child: Icon(tool.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: kSpaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpaceSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single tool work screen
// ---------------------------------------------------------------------------
class ToolWorkScreen extends ConsumerStatefulWidget {
  const ToolWorkScreen({super.key, required this.toolName});
  final String toolName;

  @override
  ConsumerState<ToolWorkScreen> createState() => _ToolWorkScreenState();
}

class _ToolWorkScreenState extends ConsumerState<ToolWorkScreen> {
  AiTool get tool => AiTool.values.firstWhere(
        (t) => t.name == widget.toolName,
        orElse: () => AiTool.restore,
      );

  File? _sourcePhoto;
  String? _sourcePhotoKey;
  bool _uploading = false;
  bool _processing = false;
  String? _resultUrl;
  String? _error;

  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(tool.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo picker card
            _PhotoCard(
              photo: _sourcePhoto,
              uploading: _uploading,
              onPick: _pickPhoto,
              onClear: () => setState(() {
                _sourcePhoto = null;
                _sourcePhotoKey = null;
                _resultUrl = null;
                _error = null;
              }),
            ),
            const SizedBox(height: kSpaceLg),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: kSpaceMd),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            // Run button
            ElevatedButton.icon(
              onPressed: (_sourcePhotoKey == null || _uploading || _processing)
                  ? null
                  : _runTool,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(tool.icon),
              label: Text(_processing ? 'Processing…' : tool.title),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),

            // Result
            if (_resultUrl != null) ...[
              const SizedBox(height: kSpaceLg),
              _ResultCard(
                resultUrl: _resultUrl!,
                onShare: () => _share(_resultUrl!),
                onSave: () => _save(_resultUrl!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    setState(() {
      _sourcePhoto = file;
      _sourcePhotoKey = null;
      _resultUrl = null;
      _error = null;
      _uploading = true;
    });
    try {
      final key = await ref.read(ordersRepositoryProvider).uploadPhoto(file);
      if (mounted) setState(() { _sourcePhotoKey = key; _uploading = false; });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() { _uploading = false; _error = _apiMessage(e); });
    }
  }

  Future<void> _runTool() async {
    setState(() { _processing = true; _error = null; _resultUrl = null; });
    try {
      final repo = ref.read(toolsRepositoryProvider);
      final ToolResult result;

      switch (tool) {
        case AiTool.restore:
          result = await repo.restorePhoto(_sourcePhotoKey!);
        case AiTool.bgRemove:
          result = await repo.removeBackground(_sourcePhotoKey!);
        case AiTool.upscale:
          result = await repo.upscale(_sourcePhotoKey!);
      }

      if (mounted) setState(() { _resultUrl = result.resultUrl; _processing = false; });
    } on InsufficientCreditsError catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      InsufficientCreditsDialog.show(context, e);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() { _processing = false; _error = _apiMessage(e); });
    }
  }

  String _apiMessage(ApiError e) => switch (e) {
        NetworkError() => 'No internet connection. Try again.',
        ServerError(:final message) => message,
        _ => 'Something went wrong. Please try again.',
      };

  Future<void> _share(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/result_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Dio().download(url, path);
      await Share.shareXFiles([XFile(path)]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share image.')));
      }
    }
  }

  Future<void> _save(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/result_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Dio().download(url, path);
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to gallery!')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save image.')));
      }
    }
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  final File? photo;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: photo == null ? onPick : null,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: photo != null
                ? kSaffron
                : theme.colorScheme.outline,
            width: photo != null ? 2 : 1,
          ),
        ),
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 48, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to pick a photo',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(photo!, fit: BoxFit.cover),
                  ),
                  if (uploading)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: onClear,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.resultUrl,
    required this.onShare,
    required this.onSave,
  });

  final String resultUrl;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: resultUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        const SizedBox(height: kSpaceMd),
        ElevatedButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.share_rounded),
          label: const Text('Share on WhatsApp'),
        ),
        const SizedBox(height: kSpaceSm),
        OutlinedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_alt_rounded),
          label: const Text('Save to Phone'),
        ),
      ],
    );
  }
}

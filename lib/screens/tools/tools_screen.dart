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
import '../../repositories/tools_repository.dart';
import '../../widgets/balance_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/insufficient_credits_dialog.dart';

// ---------------------------------------------------------------------------
// Provider — fetches the tool list from GET /tools
// ---------------------------------------------------------------------------
final _toolsListProvider = FutureProvider.autoDispose<List<AiToolDef>>((ref) {
  return ref.read(toolsRepositoryProvider).getTools();
});

// ---------------------------------------------------------------------------
// Icon / gradient helpers keyed by tool name
// ---------------------------------------------------------------------------
IconData _iconFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('face')) return Icons.face_retouching_natural;
  if (n.contains('filter')) return Icons.auto_fix_high;
  if (n.contains('bg remove') || n.contains('bg_remove') || n.contains('background remove')) return Icons.layers_clear_outlined;
  if (n.contains('background')) return Icons.wallpaper_rounded;
  if (n.contains('upscale') || n.contains('hd')) return Icons.hd_outlined;
  if (n.contains('restore')) return Icons.auto_fix_high_outlined;
  if (n.contains('outfit')) return Icons.checkroom_outlined;
  if (n.contains('hair')) return Icons.content_cut_outlined;
  if (n.contains('remix')) return Icons.shuffle_rounded;
  if (n.contains('text')) return Icons.text_fields_rounded;
  return Icons.auto_awesome;
}

List<Color> _gradientFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('face')) return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
  if (n.contains('filter')) return [const Color(0xFF6A1B9A), const Color(0xFFCE93D8)];
  if (n.contains('bg remove') || n.contains('background remove') || n.contains('bg_remove')) {
    return [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];
  }
  if (n.contains('background')) return [const Color(0xFF00695C), const Color(0xFF4DB6AC)];
  if (n.contains('upscale') || n.contains('hd')) return [const Color(0xFF00838F), const Color(0xFF4DD0E1)];
  if (n.contains('restore')) return [const Color(0xFFBF360C), const Color(0xFFFF8A65)];
  if (n.contains('outfit')) return [const Color(0xFF880E4F), const Color(0xFFF48FB1)];
  if (n.contains('hair')) return [const Color(0xFF4A148C), const Color(0xFFBA68C8)];
  if (n.contains('remix')) return [const Color(0xFFE65100), const Color(0xFFFFB74D)];
  if (n.contains('text')) return [const Color(0xFF1B5E20), const Color(0xFF81C784)];
  return [kSaffron, kMagenta];
}

// ---------------------------------------------------------------------------
// Hub screen — grid fetched from GET /tools
// ---------------------------------------------------------------------------
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(_toolsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tools'),
        actions: [const BalanceChip()],
      ),
      body: toolsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Could not load tools.',
          onRetry: () => ref.invalidate(_toolsListProvider),
        ),
        data: (tools) => tools.isEmpty
            ? const Center(child: Text('No tools available yet.'))
            : _ToolGrid(tools: tools),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools});
  final List<AiToolDef> tools;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(kSpaceMd),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: kSpaceMd,
        crossAxisSpacing: kSpaceMd,
        childAspectRatio: 1.0,
      ),
      itemCount: tools.length,
      itemBuilder: (_, i) => _ToolCard(tool: tools[i]),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});
  final AiToolDef tool;

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientFor(tool.name);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ToolWorkScreen(tool: tool)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
                child: Center(
                  child: Icon(_iconFor(tool.name), color: Colors.white, size: 40),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tool.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_rounded,
                            size: 13, color: Color(0xFFFFD700)),
                        const SizedBox(width: 3),
                        Text(
                          tool.costDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
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
// Tool work screen — photo upload + optional prompt → POST /tools/{id}
// ---------------------------------------------------------------------------
class ToolWorkScreen extends ConsumerStatefulWidget {
  const ToolWorkScreen({super.key, required this.tool});
  final AiToolDef tool;

  @override
  ConsumerState<ToolWorkScreen> createState() => _ToolWorkScreenState();
}

class _ToolWorkScreenState extends ConsumerState<ToolWorkScreen> {
  final _picker = ImagePicker();
  final _promptCtrl = TextEditingController();

  File? _sourcePhoto;
  String? _sourcePhotoKey;
  bool _uploadingSource = false;

  File? _targetPhoto;
  String? _targetPhotoKey;
  bool _uploadingTarget = false;

  bool _processing = false;
  String? _resultUrl;
  String? _resultCostDisplay;
  String? _error;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  bool get _canRun =>
      !_uploadingSource &&
      !_uploadingTarget &&
      !_processing &&
      (!widget.tool.needsPhoto || _sourcePhotoKey != null) &&
      (!widget.tool.needsTargetPhoto || _targetPhotoKey != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tool.name),
        actions: [const BalanceChip()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.tool.needsPhoto) ...[
              Text('Your Photo',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: kSpaceSm),
              _PhotoPicker(
                photo: _sourcePhoto,
                uploading: _uploadingSource,
                hint: 'Tap to pick your photo',
                onPick: () => _pickPhoto(isTarget: false),
                onClear: () => setState(() {
                  _sourcePhoto = null;
                  _sourcePhotoKey = null;
                  _resultUrl = null;
                  _error = null;
                }),
              ),
              const SizedBox(height: kSpaceMd),
            ],

            if (widget.tool.needsTargetPhoto) ...[
              Text('Style / Target Photo',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: kSpaceSm),
              _PhotoPicker(
                photo: _targetPhoto,
                uploading: _uploadingTarget,
                hint: 'Tap to pick style / target photo',
                onPick: () => _pickPhoto(isTarget: true),
                onClear: () => setState(() {
                  _targetPhoto = null;
                  _targetPhotoKey = null;
                }),
              ),
              const SizedBox(height: kSpaceMd),
            ],

            if (widget.tool.needsPrompt) ...[
              Text('Describe what you want',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: kSpaceSm),
              TextField(
                controller: _promptCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. A beautiful sunset over mountains…',
                ),
              ),
              const SizedBox(height: kSpaceMd),
            ],

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: kSpaceMd),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            // Cost badge
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      size: 16, color: Color(0xFFFFD700)),
                  const SizedBox(width: 4),
                  Text('Cost: ${widget.tool.costDisplay}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: kSpaceMd),

            ElevatedButton.icon(
              onPressed: _canRun ? _run : null,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(_iconFor(widget.tool.name)),
              label: Text(_processing
                  ? 'Processing…'
                  : 'Run ${widget.tool.name}'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),

            if (_resultUrl != null) ...[
              const SizedBox(height: kSpaceLg),
              _ResultCard(
                resultUrl: _resultUrl!,
                costDisplay: _resultCostDisplay,
                onShare: () => _share(_resultUrl!),
                onSave: () => _save(_resultUrl!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto({required bool isTarget}) async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    final file = File(picked.path);

    setState(() {
      if (isTarget) {
        _targetPhoto = file;
        _targetPhotoKey = null;
        _uploadingTarget = true;
      } else {
        _sourcePhoto = file;
        _sourcePhotoKey = null;
        _resultUrl = null;
        _uploadingSource = true;
      }
      _error = null;
    });

    try {
      final key = await ref.read(toolsRepositoryProvider).uploadPhoto(file);
      if (!mounted) return;
      setState(() {
        if (isTarget) {
          _targetPhotoKey = key;
          _uploadingTarget = false;
        } else {
          _sourcePhotoKey = key;
          _uploadingSource = false;
        }
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingSource = false;
        _uploadingTarget = false;
        _error = _msg(e);
      });
    }
  }

  Future<void> _run() async {
    setState(() {
      _processing = true;
      _error = null;
      _resultUrl = null;
    });
    try {
      final result = await ref.read(toolsRepositoryProvider).runTool(
            widget.tool.id,
            photoKey: _sourcePhotoKey,
            targetPhotoKey: _targetPhotoKey,
            prompt: widget.tool.needsPrompt ? _promptCtrl.text : null,
          );
      if (mounted) {
        setState(() {
          _resultUrl = result.resultUrl;
          _resultCostDisplay = result.costDisplay;
          _processing = false;
        });
      }
    } on InsufficientCreditsError catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      InsufficientCreditsDialog.show(context, e);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = _msg(e);
      });
    }
  }

  String _msg(ApiError e) => switch (e) {
        NetworkError() => 'No internet connection. Try again.',
        ServerError(:final message) => message,
        _ => 'Something went wrong. Please try again.',
      };

  Future<void> _share(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/tool_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60)))
          .download(url, path);
      await Share.shareXFiles([XFile(path)],
          text: 'Made with Yaadein AI Tools! ✨');
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
      final path =
          '${dir.path}/tool_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60)))
          .download(url, path);
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved to gallery!')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save image.')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.uploading,
    required this.hint,
    required this.onPick,
    required this.onClear,
  });

  final File? photo;
  final bool uploading;
  final String hint;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: photo == null ? onPick : null,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: photo != null ? kSaffron : theme.colorScheme.outline,
            width: photo != null ? 2 : 1,
          ),
        ),
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 44,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(hint,
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13)),
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
                          child: CircularProgressIndicator(
                              color: Colors.white)),
                    )
                  else
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onClear,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle),
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
    this.costDisplay,
  });

  final String resultUrl;
  final String? costDisplay;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(gradient: kBrandGradient),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                costDisplay != null
                    ? 'Done! $costDisplay deducted'
                    : 'Your result is ready!',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpaceMd),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: resultUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator())),
            errorWidget: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image_outlined, size: 72)),
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

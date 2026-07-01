import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../controllers/background_tool_jobs_controller.dart';
import '../../controllers/tool_job_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../repositories/tools_repository.dart';
import '../../widgets/balance_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/insufficient_credits_dialog.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final toolsListProvider = FutureProvider.autoDispose<List<AiToolDef>>((ref) {
  return ref.read(toolsRepositoryProvider).getTools();
});

// ---------------------------------------------------------------------------
// Per-tool configuration — all inputs and field names hardcoded because
// the backend's needs_* flags are unreliable.
// ---------------------------------------------------------------------------
class _ToolInputConfig {
  const _ToolInputConfig({
    required this.needsPhoto,
    required this.needsTargetPhoto,
    required this.needsPrompt,
    this.photoLabel = 'Your Photo',
    this.targetLabel = 'Style / Target Photo',
    this.promptLabel = 'Describe what you want',
    this.promptHint = 'Describe the result you want…',
    this.promptFieldName = 'prompt',
    // Field name for the source/person photo (default: photo_key).
    this.sourcePhotoFieldName = 'photo_key',
    // Field name for the target/garment photo.
    this.targetPhotoFieldName = 'target_photo_key',
    this.thumbnailUrl = '',
    // Whether this tool produces a video result.
    this.isVideo = false,
    // Whether the UI should show a duration picker (animate-photo).
    this.hasVideoDuration = false,
  });

  final bool needsPhoto;
  final bool needsTargetPhoto;
  final bool needsPrompt;
  final String photoLabel;
  final String targetLabel;
  final String promptLabel;
  final String promptHint;
  final String promptFieldName;
  final String sourcePhotoFieldName;
  final String targetPhotoFieldName;
  final String thumbnailUrl;
  final bool isVideo;
  final bool hasVideoDuration;
}

_ToolInputConfig _configFor(AiToolDef tool) {
  final n = tool.name.toLowerCase();

  if (n.contains('ai filter') || (n.contains('filter') && !n.contains('hair'))) {
    return const _ToolInputConfig(
      needsPhoto: true,
      needsTargetPhoto: false,
      needsPrompt: true,
      promptLabel: 'Filter Style',
      promptHint: 'e.g. oil painting, anime, watercolor, vintage…',
      promptFieldName: 'style',
      thumbnailUrl: 'https://picsum.photos/seed/aifilter87/400/400',
    );
  }
  if (n.contains('ai background') || n.contains('background')) {
    return const _ToolInputConfig(
      needsPhoto: true,
      needsTargetPhoto: false,
      needsPrompt: true,
      promptLabel: 'New Background',
      promptHint: 'e.g. beach at sunset, mountain forest, Taj Mahal…',
      thumbnailUrl: 'https://picsum.photos/seed/aibg55/400/400',
    );
  }
  if (n.contains('outfit')) {
    return const _ToolInputConfig(
      needsPhoto: true,
      needsTargetPhoto: true,
      needsPrompt: false,
      photoLabel: 'Your Photo',
      targetLabel: 'Outfit / Clothing Photo',
      sourcePhotoFieldName: 'person_photo_key',
      targetPhotoFieldName: 'outfit_photo_key',
      thumbnailUrl: 'https://picsum.photos/seed/outfit77/400/400',
    );
  }
  if (n.contains('animate')) {
    return const _ToolInputConfig(
      needsPhoto: true,
      needsTargetPhoto: false,
      needsPrompt: true,
      photoLabel: 'Photo to Animate',
      promptLabel: 'Animation Style',
      promptHint: 'e.g. gentle breeze, slow zoom, falling leaves…',
      promptFieldName: 'prompt',
      thumbnailUrl: 'https://picsum.photos/seed/animatephoto42/400/400',
      isVideo: true,
      hasVideoDuration: true,
    );
  }
  if (n.contains('hair')) {
    return const _ToolInputConfig(
      needsPhoto: true,
      needsTargetPhoto: false,
      needsPrompt: true,
      promptLabel: 'Hair Colour / Style',
      promptHint: 'e.g. black wavy, blonde straight, short curly brown…',
      promptFieldName: 'hair_colour',
      thumbnailUrl: 'https://picsum.photos/seed/hairsalon28/400/400',
    );
  }
  if (n.contains('remix')) {
    return const _ToolInputConfig(
      needsPhoto: true,
      needsTargetPhoto: false,
      needsPrompt: true,
      promptLabel: 'Remix Style',
      promptHint: 'Describe how you want to transform the photo…',
      thumbnailUrl: 'https://picsum.photos/seed/remix91/400/400',
    );
  }
  if (n.contains('text to image') || n.contains('text-to-image') || n.contains('text2image')) {
    return const _ToolInputConfig(
      needsPhoto: false,
      needsTargetPhoto: false,
      needsPrompt: true,
      promptLabel: 'Describe the image',
      promptHint: 'e.g. A beautiful sunset over the Himalayas with golden light…',
      thumbnailUrl: 'https://picsum.photos/seed/textimg14/400/400',
    );
  }
  // Video generation tools
  if (n.contains('veo')) {
    return const _ToolInputConfig(
      needsPhoto: false,
      needsTargetPhoto: false,
      needsPrompt: true,
      promptLabel: 'Describe your video',
      promptHint: 'e.g. A bride walking through a garden of marigolds at golden hour…',
      promptFieldName: 'prompt',
      thumbnailUrl: 'https://picsum.photos/seed/veo33/400/400',
      isVideo: true,
      hasVideoDuration: true,
    );
  }
  if (n.contains('seedance') || n.contains('seed dance')) {
    return const _ToolInputConfig(
      needsPhoto: true,
      needsTargetPhoto: false,
      needsPrompt: true,
      photoLabel: 'Reference Photo',
      promptLabel: 'Describe the motion / scene',
      promptHint: 'e.g. Person dancing gracefully, slow cinematic zoom…',
      promptFieldName: 'prompt',
      thumbnailUrl: 'https://picsum.photos/seed/seedance21/400/400',
      isVideo: true,
      hasVideoDuration: true,
    );
  }
  if (n.contains('kling')) {
    return const _ToolInputConfig(
      needsPhoto: true,
      needsTargetPhoto: false,
      needsPrompt: true,
      photoLabel: 'Starting Frame Photo',
      promptLabel: 'Motion description',
      promptHint: 'e.g. Camera slowly pans right, subject smiles and waves…',
      promptFieldName: 'prompt',
      thumbnailUrl: 'https://picsum.photos/seed/kling67/400/400',
      isVideo: true,
      hasVideoDuration: true,
    );
  }
  if (n.contains('wan') || n.contains('wanx')) {
    return const _ToolInputConfig(
      needsPhoto: false,
      needsTargetPhoto: false,
      needsPrompt: true,
      promptLabel: 'Describe the video',
      promptHint: 'e.g. Bride in red lehenga walking through rose petals…',
      promptFieldName: 'prompt',
      thumbnailUrl: 'https://picsum.photos/seed/wan49/400/400',
      isVideo: true,
      hasVideoDuration: true,
    );
  }
  if (n.contains('video') || n.contains('text to video') || n.contains('text-to-video')) {
    return const _ToolInputConfig(
      needsPhoto: false,
      needsTargetPhoto: false,
      needsPrompt: true,
      promptLabel: 'Describe your video',
      promptHint: 'e.g. Wedding couple dancing under string lights at night…',
      promptFieldName: 'prompt',
      thumbnailUrl: 'https://picsum.photos/seed/videogen58/400/400',
      isVideo: true,
      hasVideoDuration: true,
    );
  }
  // Fallback: honour server flags, generic field name
  return _ToolInputConfig(
    needsPhoto: tool.needsPhoto,
    needsTargetPhoto: tool.needsTargetPhoto,
    needsPrompt: tool.needsPrompt,
    thumbnailUrl: 'https://picsum.photos/seed/${tool.id}/400/400',
  );
}

// ---------------------------------------------------------------------------
// Gradient palette per tool
// ---------------------------------------------------------------------------
List<Color> _gradientFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('filter')) return [const Color(0xFF6A1B9A), const Color(0xFFCE93D8)];
  if (n.contains('background')) return [const Color(0xFF00695C), const Color(0xFF4DB6AC)];
  if (n.contains('outfit')) return [const Color(0xFF880E4F), const Color(0xFFF48FB1)];
  if (n.contains('hair')) return [const Color(0xFF4A148C), const Color(0xFFBA68C8)];
  if (n.contains('remix')) return [const Color(0xFFE65100), const Color(0xFFFFB74D)];
  if (n.contains('text')) return [const Color(0xFF1B5E20), const Color(0xFF81C784)];
  if (n.contains('animate')) return [const Color(0xFF0D47A1), const Color(0xFF42A5F5)];
  if (n.contains('veo')) return [const Color(0xFF1A237E), const Color(0xFF7986CB)];
  if (n.contains('seedance') || n.contains('seed dance')) return [const Color(0xFF880E4F), const Color(0xFFFF80AB)];
  if (n.contains('kling')) return [const Color(0xFF004D40), const Color(0xFF80CBC4)];
  if (n.contains('wan') || n.contains('wanx')) return [const Color(0xFF37474F), const Color(0xFF90A4AE)];
  if (n.contains('video')) return [const Color(0xFF311B92), const Color(0xFF9575CD)];
  return [kSaffron, kMagenta];
}

IconData _iconFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('filter')) return Icons.auto_fix_high;
  if (n.contains('background')) return Icons.wallpaper_rounded;
  if (n.contains('outfit')) return Icons.checkroom_outlined;
  if (n.contains('hair')) return Icons.content_cut_outlined;
  if (n.contains('remix')) return Icons.shuffle_rounded;
  if (n.contains('text')) return Icons.text_fields_rounded;
  if (n.contains('animate')) return Icons.play_circle_outline_rounded;
  if (n.contains('veo') || n.contains('seedance') || n.contains('kling') ||
      n.contains('wan') || n.contains('video')) return Icons.videocam_rounded;
  return Icons.auto_awesome;
}

// ---------------------------------------------------------------------------
// Hub screen
// ---------------------------------------------------------------------------
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(toolsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tools'),
        actions: [const BalanceChip()],
      ),
      body: toolsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Could not load tools.',
          onRetry: () => ref.invalidate(toolsListProvider),
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
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: tools.length,
      itemBuilder: (_, i) => _ToolCard(tool: tools[i]),
    );
  }
}

// ---------------------------------------------------------------------------
// Glamorous tool card — image background + gradient overlay + icon badge
// ---------------------------------------------------------------------------
class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});
  final AiToolDef tool;

  @override
  Widget build(BuildContext context) {
    final cfg = _configFor(tool);
    final gradient = _gradientFor(tool.name);
    final icon = _iconFor(tool.name);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ToolWorkScreen(tool: tool)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (cfg.thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: cfg.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
              ),

            // Gradient overlay for readability and brand colour
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    gradient[0].withValues(alpha: 0.55),
                    gradient[1].withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),

            // Icon badge + name + price
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                // Floating icon badge
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.50), width: 1.5),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(height: 10),
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    tool.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                // Price chip
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded,
                            size: 12, color: Color(0xFFFFD700)),
                        const SizedBox(width: 3),
                        Text(
                          tool.costDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tool work screen
// ---------------------------------------------------------------------------
class ToolWorkScreen extends ConsumerStatefulWidget {
  const ToolWorkScreen({super.key, required this.tool});
  final AiToolDef tool;

  @override
  ConsumerState<ToolWorkScreen> createState() => _ToolWorkScreenState();
}

class _ToolWorkScreenState extends ConsumerState<ToolWorkScreen> {
  late final _ToolInputConfig _cfg = _configFor(widget.tool);

  final _picker = ImagePicker();
  final _promptCtrl = TextEditingController();

  File? _sourcePhoto;
  String? _sourcePhotoKey;
  bool _uploadingSource = false;

  File? _targetPhoto;
  String? _targetPhotoKey;
  bool _uploadingTarget = false;

  // Duration selection for animate-photo: "5" or "10" seconds.
  String _animateDuration = '5';

  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  bool get _canRun {
    if (_uploadingSource || _uploadingTarget || _processing) return false;
    if (_cfg.needsPhoto && _sourcePhotoKey == null) return false;
    if (_cfg.needsTargetPhoto && _targetPhotoKey == null) return false;
    if (_cfg.needsPrompt && _promptCtrl.text.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = _gradientFor(widget.tool.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tool.name),
        actions: [const BalanceChip()],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: gradient,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_cfg.needsPhoto) ...[
              _SectionLabel(_cfg.photoLabel),
              const SizedBox(height: kSpaceSm),
              _PhotoPicker(
                photo: _sourcePhoto,
                uploading: _uploadingSource,
                hint: 'Tap to pick photo',
                onPick: () => _pickPhoto(isTarget: false),
                onClear: () => setState(() {
                  _sourcePhoto = null;
                  _sourcePhotoKey = null;
                  _error = null;
                }),
              ),
              const SizedBox(height: kSpaceMd),
            ],

            if (_cfg.needsTargetPhoto) ...[
              _SectionLabel(_cfg.targetLabel),
              const SizedBox(height: kSpaceSm),
              _PhotoPicker(
                photo: _targetPhoto,
                uploading: _uploadingTarget,
                hint: 'Tap to pick photo',
                onPick: () => _pickPhoto(isTarget: true),
                onClear: () => setState(() {
                  _targetPhoto = null;
                  _targetPhotoKey = null;
                }),
              ),
              const SizedBox(height: kSpaceMd),
            ],

            if (_cfg.needsPrompt) ...[
              _SectionLabel(_cfg.promptLabel),
              const SizedBox(height: kSpaceSm),
              TextField(
                controller: _promptCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _cfg.promptHint,
                ),
              ),
              const SizedBox(height: kSpaceMd),
            ],

            if (_cfg.hasVideoDuration) ...[
              _SectionLabel('Duration'),
              const SizedBox(height: kSpaceSm),
              Row(
                children: [
                  _DurationChip(
                    label: '5 seconds',
                    selected: _animateDuration == '5',
                    onTap: () => setState(() => _animateDuration = '5'),
                  ),
                  const SizedBox(width: 12),
                  _DurationChip(
                    label: '10 seconds',
                    selected: _animateDuration == '10',
                    onTap: () => setState(() => _animateDuration = '10'),
                  ),
                ],
              ),
              const SizedBox(height: kSpaceMd),
            ],

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: kSpaceMd),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                      color: theme.colorScheme.onErrorContainer, fontSize: 13),
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
              label: Text(_processing ? 'Submitting…' : 'Run ${widget.tool.name}'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),

          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto({required bool isTarget}) async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
    });
    try {
      final allFields = <String, String>{
        if (_cfg.needsPrompt && _promptCtrl.text.trim().isNotEmpty)
          _cfg.promptFieldName: _promptCtrl.text.trim(),
        if (_cfg.needsTargetPhoto && _targetPhotoKey != null)
          _cfg.targetPhotoFieldName: _targetPhotoKey!,
        if (_cfg.hasVideoDuration) ...{
          'duration': _animateDuration,
          'aspect_ratio': '9:16',
        },
      };

      final job = await ref.read(toolsRepositoryProvider).runTool(
            widget.tool.id,
            photoKey: _cfg.needsPhoto ? _sourcePhotoKey : null,
            sourceFieldName: _cfg.sourcePhotoFieldName,
            extraFields: allFields.isEmpty ? null : allFields,
          );

      if (!mounted) return;

      // Start background polling and register with the badge tracker.
      ref.read(toolJobControllerProvider(job.jobId));
      ref.read(backgroundToolJobsProvider.notifier).trackJob(
            job.jobId,
            toolName: widget.tool.name,
            isVideo: _cfg.isVideo,
          );

      // Navigate to the status screen — user can browse from there.
      context.push(
        '/home/tools/job/${job.jobId}',
        extra: {
          'toolName': widget.tool.name,
          'costDisplay': widget.tool.costDisplay,
        },
      );
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
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _msg(ApiError e) => switch (e) {
        NetworkError() =>
          'Could not reach the server. Check your connection and try again.',
        ServerError(:final statusCode) when statusCode == 422 =>
          'Please check your photos and try again.',
        ServerError(:final message) => message,
        _ => 'Something went wrong. Please try again.',
      };

}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kSaffron : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? kSaffron : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

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
                      size: 44, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(hint,
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
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
                          child: CircularProgressIndicator(color: Colors.white)),
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
                              color: Colors.black54, shape: BoxShape.circle),
                          child:
                              const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

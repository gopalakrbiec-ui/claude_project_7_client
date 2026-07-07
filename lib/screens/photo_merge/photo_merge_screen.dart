import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_error.dart';
import '../../controllers/background_tool_jobs_controller.dart';
import '../../controllers/tool_job_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../repositories/currency_repository.dart';
import '../../repositories/tools_repository.dart';
import '../../widgets/balance_chip.dart';
import '../../widgets/insufficient_credits_dialog.dart';

const _kMaxPhotos = 4;
const _kMinPhotos = 2;

class PhotoMergeScreen extends ConsumerStatefulWidget {
  const PhotoMergeScreen({super.key, required this.tool});
  final AiToolDef tool;

  @override
  ConsumerState<PhotoMergeScreen> createState() => _PhotoMergeScreenState();
}

class _PhotoMergeScreenState extends ConsumerState<PhotoMergeScreen> {
  final _promptCtrl = TextEditingController();
  final _picker = ImagePicker();

  // Slots: null means empty, File means picked
  final List<File?> _photos = [null, null];
  final Set<String> _selectedChips = {};

  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  List<String> get _keywords => widget.tool.keywords.isNotEmpty
      ? widget.tool.keywords
      : const [
          'together',
          'hugging',
          'kissing',
          'collage',
          'side by side',
          'wedding',
          'romantic',
          'friends',
        ];

  int get _filledCount => _photos.where((f) => f != null).length;
  bool get _canRun => _filledCount >= _kMinPhotos && !_processing;

  void _toggleChip(String chip) {
    setState(() {
      if (_selectedChips.contains(chip)) {
        _selectedChips.remove(chip);
      } else {
        _selectedChips.add(chip);
      }
      // Rebuild prompt from selected chips, preserve any trailing user text
      _promptCtrl.text = _selectedChips.join(', ');
      _promptCtrl.selection = TextSelection.collapsed(
          offset: _promptCtrl.text.length);
    });
  }

  Future<void> _pickPhoto(int index) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null) return;
    setState(() => _photos[index] = File(picked.path));
  }

  void _removePhoto(int index) {
    setState(() {
      _photos[index] = null;
      // Compact: shift remaining down so empties are at end
      final filled = _photos.where((f) => f != null).toList();
      while (_photos.length > _kMinPhotos &&
          _photos.last == null &&
          filled.length < _photos.length) {
        _photos.removeLast();
      }
    });
  }

  void _addSlot() {
    if (_photos.length < _kMaxPhotos) {
      setState(() => _photos.add(null));
    }
  }

  Future<void> _submit() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final repo = ref.read(toolsRepositoryProvider);

      // Upload all filled photos in parallel
      final filledPhotos = _photos
          .asMap()
          .entries
          .where((e) => e.value != null)
          .map((e) => e.value!)
          .toList();

      final keys = await Future.wait(
        filledPhotos.map((f) => repo.uploadPhoto(f)),
      );

      if (!mounted) return;

      final job = await repo.runPhotoMerge(
        photoKeys: keys,
        keywords: _selectedChips.toList(),
        prompt: _promptCtrl.text.trim(),
      );

      if (!mounted) return;

      // Start background tracking
      ref.read(toolJobControllerProvider(job.jobId));
      ref.read(backgroundToolJobsProvider.notifier).trackJob(
            job.jobId,
            toolName: widget.tool.name,
            isVideo: false,
          );

      final symbol = currencyOrFallback(
              ref.read(currencyInfoProvider))
          .symbol;
      context.push(
        '/home/tools/job/${job.jobId}',
        extra: {
          'toolName': widget.tool.name,
          'costDisplay': widget.tool.coinsDisplay(symbol),
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  String _msg(ApiError e) => switch (e) {
        NetworkError() =>
          'Could not reach the server. Check your connection.',
        ServerError(:final message) => message,
        _ => 'Something went wrong. Please try again.',
      };

  @override
  Widget build(BuildContext context) {
    final currency = currencyOrFallback(ref.watch(currencyInfoProvider));
    final theme = Theme.of(context);
    final canAddSlot = _photos.length < _kMaxPhotos;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tool.name),
        actions: const [BalanceChip(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(kSpaceMd),
        children: [
          // Cost banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Merge up to 4 photos with AI · ${widget.tool.coinsDisplay(currency.symbol)} per creation',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: kSpaceLg),

          // Photo grid
          Text('Photos',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: kSpaceSm),
          Text(
            _filledCount < _kMinPhotos
                ? 'Add at least 2 photos'
                : '$_filledCount photo${_filledCount > 1 ? 's' : ''} selected',
            style: TextStyle(
              fontSize: 12,
              color: _filledCount < _kMinPhotos
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpaceSm),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _photos.length; i++)
                _PhotoSlot(
                  file: _photos[i],
                  index: i,
                  onPick: () => _pickPhoto(i),
                  onRemove: () => _removePhoto(i),
                ),
              if (canAddSlot)
                _AddSlotButton(onTap: _addSlot),
            ],
          ),

          const SizedBox(height: kSpaceLg),

          // Keyword chips
          if (_keywords.isNotEmpty) ...[
            Text('Style Keywords',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: kSpaceSm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _keywords
                  .map((chip) => _KeywordChip(
                        label: chip,
                        selected: _selectedChips.contains(chip),
                        onToggle: () => _toggleChip(chip),
                      ))
                  .toList(),
            ),
            const SizedBox(height: kSpaceLg),
          ],

          // Prompt box
          Text('Prompt (optional)',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: kSpaceSm),
          TextField(
            controller: _promptCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'e.g. in front of the Taj Mahal, golden hour lighting…',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),

          if (_error != null) ...[
            const SizedBox(height: kSpaceMd),
            Container(
              padding: const EdgeInsets.all(kSpaceMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],

          const SizedBox(height: kSpaceXl),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpaceMd, kSpaceSm, kSpaceMd, kSpaceMd),
          child: FilledButton.icon(
            onPressed: _canRun ? _submit : null,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.merge_type_rounded),
            label: Text(_processing
                ? 'Uploading & Merging…'
                : _filledCount < _kMinPhotos
                    ? 'Add at least 2 photos'
                    : 'Run Photo Merge · ${widget.tool.coinsDisplay(currency.symbol)}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: kSaffron,
              disabledBackgroundColor:
                  kSaffron.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo slot widget
// ---------------------------------------------------------------------------
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.file,
    required this.index,
    required this.onPick,
    required this.onRemove,
  });

  final File? file;
  final int index;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = (MediaQuery.sizeOf(context).width - kSpaceMd * 2 - 10) / 2;

    if (file != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Photo ${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 36,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              'Photo ${index + 1}',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add slot button
// ---------------------------------------------------------------------------
class _AddSlotButton extends StatelessWidget {
  const _AddSlotButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = (MediaQuery.sizeOf(context).width - kSpaceMd * 2 - 10) / 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kSaffron.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 36, color: kSaffron.withValues(alpha: 0.7)),
            const SizedBox(height: 6),
            Text(
              'Add Photo',
              style: TextStyle(
                  color: kSaffron.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Keyword chip
// ---------------------------------------------------------------------------
class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? kSaffron
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? kSaffron
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

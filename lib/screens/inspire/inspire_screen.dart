import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../repositories/inspire_repository.dart';
import '../../repositories/tools_repository.dart';
import '../../screens/tools/tools_screen.dart' show toolsListProvider, ToolWorkScreen;

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final _keywordsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ref.read(inspireRepositoryProvider).getKeywords();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class InspireScreen extends ConsumerStatefulWidget {
  const InspireScreen({super.key});

  @override
  ConsumerState<InspireScreen> createState() => _InspireScreenState();
}

class _InspireScreenState extends ConsumerState<InspireScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  String _query = '';
  List<InspirePhoto> _photos = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onMicTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice search coming soon')),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (value != _query) {
        _query = value;
        _fetch(reset: true);
      }
    });
  }

  void _onChipTap(String chip) {
    _searchCtrl.text = chip;
    _query = chip;
    _fetch(reset: true);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _photos = [];
        _page = 1;
        _hasMore = true;
      }
    });

    try {
      final result = await ref
          .read(inspireRepositoryProvider)
          .search(query: _query, page: reset ? 1 : _page);
      if (!mounted) return;
      setState(() {
        _photos = reset ? result.photos : [..._photos, ...result.photos];
        _page = result.page + 1;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load photos. Tap to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keywordsAsync = ref.watch(_keywordsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Inspire'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kSpaceMd, 0, kSpaceMd, kSpaceSm),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search photos…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.mic_outlined),
                        onPressed: _onMicTap,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Sticky keyword chips — stays fixed while content scrolls
          keywordsAsync.when(
            loading: () => const SizedBox(
                height: 48,
                child: Center(child: LinearProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (chips) => _ChipRow(
              chips: chips,
              selected: _query,
              onTap: _onChipTap,
            ),
          ),
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
          // Error state
          if (_error != null && _photos.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: GestureDetector(
                  onTap: () => _fetch(reset: true),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_outlined,
                          size: 56,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            )
          else if (!_loading && _photos.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_search_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('No photos found',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          else
            // 2-column photo grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  kSpaceSm, kSpaceSm, kSpaceSm, 0),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _PhotoCard(
                    photo: _photos[i],
                    onTap: () => _openPreview(context, _photos[i]),
                  ),
                  childCount: _photos.length,
                ),
              ),
            ),

          // Loading indicator / load-more spinner
          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox(height: 16),
          ),

          // Pexels attribution (required by Pexels API terms)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  kSpaceMd, 0, kSpaceMd, kSpaceLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Photos provided by Pexels',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openPreview(BuildContext context, InspirePhoto photo) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreviewSheet(photo: photo),
    );
  }
}

// ---------------------------------------------------------------------------
// Keyword chip row
// ---------------------------------------------------------------------------
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.chips,
    required this.selected,
    required this.onTap,
  });

  final List<String> chips;
  final String selected;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isSelected = selected == chips[i];
          return GestureDetector(
            onTap: () => onTap(chips[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? kSaffron
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                chips[i],
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo card
// ---------------------------------------------------------------------------
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.onTap});
  final InspirePhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: photo.thumbUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (_, __, ___) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined,
                    color: Colors.white38),
              ),
            ),
            // Author credit overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Text(
                  photo.author,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
// Tool picker bottom sheet
// ---------------------------------------------------------------------------
class _ToolPickerSheet extends StatelessWidget {
  const _ToolPickerSheet({required this.tools});
  final List<AiToolDef> tools;

  static List<Color> _colorsFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('background')) return [const Color(0xFF00695C), const Color(0xFF4DB6AC)];
    if (n.contains('photo merge') || n.contains('photo-merge')) return [const Color(0xFFE65100), const Color(0xFFFFB74D)];
    if (n.contains('outfit')) return [const Color(0xFF880E4F), const Color(0xFFF06292)];
    if (n.contains('filter')) return [const Color(0xFF7B1FA2), const Color(0xFFCE93D8)];
    if (n.contains('hair')) return [const Color(0xFF4A148C), const Color(0xFFBA68C8)];
    if (n.contains('remix')) return [const Color(0xFFBF360C), const Color(0xFFFF8A65)];
    if (n.contains('animate')) return [const Color(0xFF0D47A1), const Color(0xFF42A5F5)];
    if (n.contains('veo')) return [const Color(0xFF1A237E), const Color(0xFF7986CB)];
    if (n.contains('seedance')) return [const Color(0xFF880E4F), const Color(0xFFFF80AB)];
    if (n.contains('kling')) return [const Color(0xFF004D40), const Color(0xFF80CBC4)];
    if (n.contains('wan')) return [const Color(0xFF37474F), const Color(0xFF90A4AE)];
    if (n.contains('video')) return [const Color(0xFF311B92), const Color(0xFF9575CD)];
    return [kSaffron, kMagenta];
  }

  static IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('background')) return Icons.wallpaper_rounded;
    if (n.contains('photo merge') || n.contains('photo-merge')) return Icons.merge_type_rounded;
    if (n.contains('outfit')) return Icons.checkroom_outlined;
    if (n.contains('filter')) return Icons.auto_fix_high;
    if (n.contains('animate')) return Icons.play_circle_outline_rounded;
    if (n.contains('hair')) return Icons.content_cut_outlined;
    if (n.contains('remix')) return Icons.shuffle_rounded;
    if (n.contains('veo') || n.contains('seedance') || n.contains('kling') ||
        n.contains('wan') || n.contains('video')) return Icons.videocam_rounded;
    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Choose an AI Tool',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
            child: Text(
              'The selected photo will be used as input',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                  kSpaceMd, 0, kSpaceMd, kSpaceMd),
              itemCount: tools.length,
              itemBuilder: (ctx, i) {
                final tool = tools[i];
                final colors = _colorsFor(tool.name);
                final icon = _iconFor(tool.name);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  title: Text(tool.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: tool.costDisplay.isNotEmpty
                      ? Text(tool.costDisplay,
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12))
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(ctx).pop(tool),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen preview bottom sheet
// ---------------------------------------------------------------------------
class _PreviewSheet extends ConsumerStatefulWidget {
  const _PreviewSheet({required this.photo});
  final InspirePhoto photo;

  @override
  ConsumerState<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends ConsumerState<_PreviewSheet> {
  bool _saving = false;

  Future<void> _saveToGallery() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/inspire_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
      ));
      await dio.download(widget.photo.fullUrl, path);
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to your gallery!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save image. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showToolPicker() async {
    List<AiToolDef> tools;
    try {
      tools = await ref.read(toolsListProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load tools. Please try again.')),
        );
      }
      return;
    }
    if (!mounted) return;

    final selectedTool = await showModalBottomSheet<AiToolDef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ToolPickerSheet(tools: tools),
    );

    if (selectedTool == null || !mounted) return;

    // Capture navigator BEFORE popping — after pop the widget is disposed
    // so context is no longer valid for navigation.
    final nav = Navigator.of(context);
    nav.pop(); // close preview sheet
    nav.push(MaterialPageRoute(
      builder: (_) => ToolWorkScreen(
        tool: selectedTool,
        preloadedSourceUrl: widget.photo.fullUrl,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenH = MediaQuery.sizeOf(context).height;

    return Container(
      height: screenH * 0.88,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Full-screen preview image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: widget.photo.previewUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined,
                        size: 64, color: Colors.white38),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: kSpaceMd),

          // Author & source
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
            child: Row(
              children: [
                const Icon(Icons.camera_alt_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${widget.photo.author} · ${widget.photo.source}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: kSpaceMd),

          // Action buttons
          Padding(
            padding: EdgeInsets.fromLTRB(kSpaceMd, 0, kSpaceMd,
                kSpaceMd + MediaQuery.viewPaddingOf(context).bottom),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _saveToGallery,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_alt_rounded),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: kSpaceMd),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _showToolPicker,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Use in AI Tools'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: kSaffron,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

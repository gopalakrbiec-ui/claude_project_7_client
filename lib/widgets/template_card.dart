import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/template.dart';

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.onTap,
    this.isHot = false,
  });

  final Template template;
  final VoidCallback onTap;
  final bool isHot;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image / placeholder
            _Thumbnail(
              assetKey: template.thumbnailKey,
              templateName: template.name,
              theme: template.theme,
            ),
            // Gradient scrim — bottom third
            const Align(
              alignment: Alignment.bottomCenter,
              child: _BottomScrim(),
            ),
            // Name overlay
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                template.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
            ),
            // HOT badge — top left
            if (isHot)
              Positioned(
                top: 8,
                left: 8,
                child: _HotBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
    );
  }
}

class _HotBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3D00),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: 10)),
          SizedBox(width: 2),
          Text(
            'HOT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.assetKey,
    required this.templateName,
    required this.theme,
  });
  final String? assetKey;
  final String templateName;
  final String theme;

  @override
  Widget build(BuildContext context) {
    if (assetKey == null || assetKey!.isEmpty) {
      return _PlaceholderTile(name: templateName, theme: theme);
    }

    return CachedNetworkImage(
      imageUrl: assetKey!,
      fit: BoxFit.cover,
      memCacheWidth: 300,
      memCacheHeight: 400,
      placeholder: (_, __) => _PlaceholderTile(
        name: templateName,
        theme: theme,
      ),
      errorWidget: (_, __, ___) => _PlaceholderTile(
        name: templateName,
        theme: theme,
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.name, required this.theme});
  final String name;
  final String theme;

  static const _palettes = <String, List<Color>>{
    'floral':   [Color(0xFFD4145A), Color(0xFFFBB03B)],
    'bridal':   [Color(0xFFE91E8C), Color(0xFFFF6B23)],
    'wedding':  [Color(0xFF8B0057), Color(0xFFFF6B23)],
    'royal':    [Color(0xFF4A0080), Color(0xFFE91E8C)],
    'garden':   [Color(0xFF1B5E20), Color(0xFF66BB6A)],
    'birthday': [Color(0xFF1565C0), Color(0xFFAB47BC)],
    'business': [Color(0xFF1A237E), Color(0xFF37474F)],
  };

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[theme.toLowerCase()] ?? [kSaffron, kMagenta];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '✦';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(blurRadius: 12, color: Colors.black38)],
          ),
        ),
      ),
    );
  }
}

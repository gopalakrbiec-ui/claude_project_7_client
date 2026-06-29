import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/template.dart';

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.onTap,
  });

  final Template template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _Thumbnail(
                assetKey: template.thumbnailKey,
                templateName: template.name,
                theme: template.theme,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  kSpaceSm, kSpaceSm, kSpaceSm, kSpaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _ThemeTag(label: template.theme),
                      const Spacer(),
                      Text(
                        template.priceDisplay,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
      placeholder: (_, __) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => _PlaceholderTile(
        name: templateName,
        theme: theme,
      ),
    );
  }
}

// Shown when no image URL is available yet — gradient + initials.
class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.name, required this.theme});
  final String name;
  final String theme;

  // Deterministic gradient per theme so each category has a consistent colour.
  static const _palettes = <String, List<Color>>{
    'floral':   [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
    'bridal':   [Color(0xFFE91E8C), Color(0xFFFF6B23)],
    'wedding':  [Color(0xFFFFD700), Color(0xFFFF6B23)],
    'royal':    [Color(0xFF6A1B9A), Color(0xFFE91E8C)],
    'garden':   [Color(0xFF43A047), Color(0xFFAED581)],
    'birthday': [Color(0xFF42A5F5), Color(0xFFCE93D8)],
    'business': [Color(0xFF37474F), Color(0xFF78909C)],
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
            fontSize: 48,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(blurRadius: 8, color: Colors.black26)],
          ),
        ),
      ),
    );
  }
}

class _ThemeTag extends StatelessWidget {
  const _ThemeTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

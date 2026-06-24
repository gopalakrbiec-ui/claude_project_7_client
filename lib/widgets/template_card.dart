import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
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
              child: _Thumbnail(assetKey: template.thumbnailKey),
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
  const _Thumbnail({required this.assetKey});
  final String? assetKey;

  @override
  Widget build(BuildContext context) {
    if (assetKey == null || assetKey!.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_outlined, size: 40)),
      );
    }

    // asset_keys may be full URLs or bare keys; treat as URL directly.
    return CachedNetworkImage(
      imageUrl: assetKey!,
      fit: BoxFit.cover,
      // Decode at thumbnail size — avoids holding full-res bitmaps in RAM for
      // a grid of small cards.  300 px covers ~2× a 150-dp card at 1× density.
      memCacheWidth: 300,
      memCacheHeight: 400,
      placeholder: (_, __) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 40),
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

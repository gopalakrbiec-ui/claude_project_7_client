import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/credits_controller.dart';
import '../../controllers/templates_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/template.dart';
import '../../repositories/currency_repository.dart';
import '../../repositories/templates_repository.dart';
import '../../widgets/error_view.dart';

class TemplateDetailScreen extends ConsumerWidget {
  const TemplateDetailScreen({
    super.key,
    required this.templateId,
    this.preloaded, // passed via GoRouter extra when navigating from grid
  });

  final String templateId;
  /// Template already in memory from the grid — avoids a round-trip.
  final Template? preloaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the template passed directly from the grid navigation.
    // Fall back to the repository's in-memory cache (survives push/pop).
    final template = preloaded ??
        ref.read(templatesRepositoryProvider).getCached(templateId);

    if (template != null) {
      return _DetailContent(template: template);
    }

    // Cache miss (e.g. deep-linked directly to this route):
    // wait for the templates list to load and scan it.
    final templatesAsync = ref.watch(templatesControllerProvider);
    return templatesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Could not load template.',
          onRetry: () =>
              ref.read(templatesControllerProvider.notifier).refresh(),
        ),
      ),
      data: (templates) {
        final matches = templates.where((t) => t.id == templateId);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Template not found.')),
          );
        }
        return _DetailContent(template: matches.first);
      },
    );
  }
}

// ---------------------------------------------------------------------------
class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.template});
  final Template template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = currencyOrFallback(ref.watch(currencyInfoProvider));
    final balanceAsync = ref.watch(creditsControllerProvider);
    final canAfford =
        balanceAsync.valueOrNull?.canAfford(template.basePricePaise) ?? true;

    return Scaffold(
      appBar: AppBar(title: Text(template.name)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Large preview ~55 % of screen height
          Expanded(
            flex: 55,
            child: _LargePreview(template: template),
          ),

          Expanded(
            flex: 45,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kSpaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + theme tag
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: kSpaceSm),
                      _Tag(template.theme),
                    ],
                  ),
                  const SizedBox(height: kSpaceMd),

                  // Price — formatted by the model from base_price_paise.
                  // CLAUDE.md: client never computes price; this is display-only.
                  // The actual charge is confirmed by POST /orders response.
                  Row(
                    children: [
                      Text('Price  ', style: theme.textTheme.bodyMedium),
                      Text(
                        template.priceCoins(currency.symbol),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  if (balanceAsync.hasValue && !canAfford) ...[
                    const SizedBox(height: kSpaceSm),
                    _AffordabilityWarning(theme: theme),
                  ],

                  const SizedBox(height: kSpaceLg),

                  ElevatedButton(
                    onPressed: () => context.push(
                      '/home/create-order/${template.id}',
                      extra: template,
                    ),
                    child: const Text('Create'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargePreview extends StatelessWidget {
  const _LargePreview({required this.template});
  final Template template;

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
    final key = template.thumbnailKey;
    if (key == null) {
      final themeKey = template.theme.toLowerCase();
      final colors = _palettes[themeKey] ?? [kSaffron, kMagenta];
      final initial = template.name.isNotEmpty
          ? template.name[0].toUpperCase()
          : '?';
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
              fontSize: 96,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black38, blurRadius: 12, offset: Offset(2, 4)),
              ],
            ),
          ),
        ),
      );
    }
    // Decode at a reasonable preview size — this is a detail image, not a
    // thumbnail, so we allow more pixels but still cap to avoid OOM on cheap
    // phones with large source assets.
    return CachedNetworkImage(
      imageUrl: key,
      fit: BoxFit.contain,
      memCacheWidth: 800,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image_outlined, size: 64)),
    );
  }
}

class _AffordabilityWarning extends StatelessWidget {
  const _AffordabilityWarning({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpaceSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: kSpaceXs),
          Expanded(
            child: Text(
              'Insufficient credits. Top up to create this design.',
              style: TextStyle(
                  color: theme.colorScheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

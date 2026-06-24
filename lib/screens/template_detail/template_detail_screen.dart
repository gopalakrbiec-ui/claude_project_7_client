import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/credits_controller.dart';
import '../../controllers/templates_controller.dart';
import '../../core/constants.dart';
import '../../models/template.dart';
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
                        template.priceDisplay,
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
                    onPressed: () => context.go(
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

  @override
  Widget build(BuildContext context) {
    final key = template.thumbnailKey;
    if (key == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_outlined, size: 64)),
      );
    }
    return CachedNetworkImage(
      imageUrl: key,
      fit: BoxFit.contain,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/templates_controller.dart';
import '../../core/constants.dart';
import '../../models/template.dart';
import '../../widgets/balance_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton_card.dart';
import '../../widgets/template_card.dart';
import '../../widgets/theme_filter_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isAgent = authState is AuthAuthenticated && authState.profile.isAgent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Template'),
        actions: [
          if (isAgent)
            IconButton(
              icon: const Icon(Icons.store),
              tooltip: 'My Earnings',
              onPressed: () => context.go('/home/agent-earnings'),
            ),
          const BalanceChip(),
        ],
      ),
      body: const _TemplateBody(),
      floatingActionButton: isAgent
          ? FloatingActionButton.extended(
              onPressed: () => _showAgentHint(context),
              icon: const Icon(Icons.person_add),
              label: const Text('For Customer'),
            )
          : null,
    );
  }

  void _showAgentHint(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Place Order for Customer',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select any template from the grid above. During order creation '
                'you can optionally enter the customer\'s phone number.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — owns the pull-to-refresh and maps async state to child widgets.
// ---------------------------------------------------------------------------
class _TemplateBody extends ConsumerWidget {
  const _TemplateBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(templatesControllerProvider.notifier);
    final templatesAsync = ref.watch(templatesControllerProvider);
    final selectedTheme = controller.selectedTheme;
    final availableThemes = controller.availableThemes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar — shown only when we have data or themes to display.
        if (availableThemes.isNotEmpty || selectedTheme != null)
          ThemeFilterBar(
            themes: availableThemes,
            selected: selectedTheme,
            onSelected: controller.setTheme,
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: templatesAsync.when(
              loading: () => const _SkeletonGrid(),
              error: (e, _) => _ErrorBody(
                message: e.toString(),
                onRetry: controller.refresh,
              ),
              data: (templates) => templates.isEmpty
                  ? _EmptyBody(
                      hasFilter: selectedTheme != null,
                      onClear: () => controller.setTheme(null),
                    )
                  : _TemplateGrid(templates: templates),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grid states
// ---------------------------------------------------------------------------
class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({required this.templates});
  final List<Template> templates;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = _crossAxisCount(context);

    return GridView.builder(
      padding: const EdgeInsets.all(kSpaceMd),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: kSpaceSm,
        mainAxisSpacing: kSpaceSm,
        // 3:4 card aspect ratio (portrait) — taller card shows more of the image.
        childAspectRatio: 3 / 4,
      ),
      itemCount: templates.length,
      itemBuilder: (context, i) {
        final t = templates[i];
        return TemplateCard(
          template: t,
          onTap: () => context.go(
            '/home/template/${t.id}',
            extra: t,
          ),
        );
      },
    );
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 4; // tablets landscape
    if (width >= 600) return 3; // tablets portrait / large phones landscape
    return 2; // standard phone portrait
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final crossAxisCount =
        MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;

    return SkeletonScope(
      child: GridView.builder(
        padding: const EdgeInsets.all(kSpaceMd),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: kSpaceSm,
          mainAxisSpacing: kSpaceSm,
          childAspectRatio: 3 / 4,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const SkeletonCard(),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Wrap in a scroll view so RefreshIndicator can still be triggered.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: ErrorView(
          message: _friendlyMessage(message),
          onRetry: onRetry,
        ),
      ),
    );
  }

  String _friendlyMessage(String raw) {
    if (raw.contains('NetworkError') || raw.contains('SocketException')) {
      return 'No internet connection.\nPull down to retry when you\'re back online.';
    }
    return 'Error: $raw';
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.hasFilter, required this.onClear});
  final bool hasFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(kSpaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_search,
                    size: 72, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: kSpaceLg),
                Text(
                  hasFilter
                      ? 'No templates for this theme'
                      : 'No templates available',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                if (hasFilter) ...[
                  const SizedBox(height: kSpaceMd),
                  OutlinedButton(
                    onPressed: onClear,
                    child: const Text('Clear filter'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

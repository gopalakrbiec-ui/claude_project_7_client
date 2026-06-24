import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).valueOrNull ?? 'user';
    final isAgent = role == 'agent';

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
          // Balance chip — always visible; value comes from credits repository.
          // TODO: wire to CreditsController once implemented.
          Padding(
            padding: const EdgeInsets.only(right: kSpaceMd),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceSm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('₹ —', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
      body: const _TemplatePlaceholder(),
      floatingActionButton: isAgent
          ? FloatingActionButton.extended(
              onPressed: () {/* TODO: agent create order flow */},
              icon: const Icon(Icons.person_add),
              label: const Text('For Customer'),
            )
          : null,
    );
  }
}

class _TemplatePlaceholder extends StatelessWidget {
  const _TemplatePlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // TODO: replace with TemplatesController + GridView of real templates.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search, size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: kSpaceLg),
          Text(
            'Templates load here',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: kSpaceSm),
          Text(
            'Run make gen-api then wire the\nTemplatesController to this screen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpaceLg),
          OutlinedButton(
            onPressed: () => context.go('/home/template/demo-id'),
            child: const Text('Open demo template →'),
          ),
        ],
      ),
    );
  }
}

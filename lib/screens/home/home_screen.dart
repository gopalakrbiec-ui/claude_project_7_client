import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/templates_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/template.dart';
import '../../widgets/balance_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton_card.dart';
import '../../widgets/template_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isAgent = authState is AuthAuthenticated && authState.profile.isAgent;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _DiscoverTab(isAgent: isAgent),
          _AllTemplatesTab(isAgent: isAgent),
          const _MyOrdersTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Templates',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'My Orders',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discover tab — hero banner + grouped category rows
// ---------------------------------------------------------------------------
class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab({required this.isAgent});
  final bool isAgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesControllerProvider);
    final controller = ref.read(templatesControllerProvider.notifier);

    return RefreshIndicator(
      color: kSaffron,
      onRefresh: controller.refresh,
      child: CustomScrollView(
        slivers: [
          _HeroBanner(isAgent: isAgent),
          templatesAsync.when(
            loading: () => const SliverToBoxAdapter(child: _CategorySkeleton()),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(kSpaceLg),
                child: ErrorView(
                  message: 'Could not load templates.',
                  onRetry: controller.refresh,
                ),
              ),
            ),
            data: (templates) => _CategoryRows(templates: templates),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: kSpaceLg)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero banner
// ---------------------------------------------------------------------------
class _HeroBanner extends ConsumerWidget {
  const _HeroBanner({required this.isAgent});
  final bool isAgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = MediaQuery.sizeOf(context).height * 0.40;
    final authState = ref.watch(authControllerProvider);

    return SliverToBoxAdapter(
      child: SizedBox(
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background — brand gradient (same saffron→magenta used in splash)
            Container(
              decoration: const BoxDecoration(gradient: kBrandGradient),
            ),
            // Decorative sparkle circles
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -60, left: -30,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceLg,
                  vertical: kSpaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar: app name + actions
                    Row(
                      children: [
                        const Text(
                          'Yaadein',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        if (isAgent)
                          IconButton(
                            icon: const Icon(Icons.storefront_outlined,
                                color: Colors.white70),
                            onPressed: () => context.go('/home/agent-earnings'),
                          ),
                        const BalanceChip(),
                      ],
                    ),
                    const Spacer(),
                    // Headline
                    const Text(
                      'AI Posters of\nYour Moments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: kSpaceSm),
                    Text(
                      'Upload your photo • pick a style • done in seconds',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: kSpaceMd),
                    // CTA button
                    GestureDetector(
                      onTap: () {
                        // Navigate to the All Templates tab by triggering rebuild
                        // The parent IndexedStack handles it via bottom nav;
                        // here we scroll to first template category instead.
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Try  ',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Icon(Icons.auto_awesome,
                                size: 16, color: kSaffron),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpaceMd),
                  ],
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
// Category rows
// ---------------------------------------------------------------------------
class _CategoryRows extends StatelessWidget {
  const _CategoryRows({required this.templates});
  final List<Template> templates;

  @override
  Widget build(BuildContext context) {
    // Group templates by theme, preserving insertion order.
    final groups = <String, List<Template>>{};
    for (final t in templates) {
      groups.putIfAbsent(t.theme, () => []).add(t);
    }

    return SliverList.builder(
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final theme = groups.keys.elementAt(i);
        final items = groups[theme]!;
        return _CategorySection(theme: theme, items: items);
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.theme, required this.items});
  final String theme;
  final List<Template> items;

  static const _themeEmoji = <String, String>{
    'wedding':  '💍',
    'bridal':   '👰',
    'floral':   '🌸',
    'royal':    '👑',
    'garden':   '🌿',
    'birthday': '🎂',
    'business': '💼',
  };

  @override
  Widget build(BuildContext context) {
    final label = theme[0].toUpperCase() + theme.substring(1);
    final emoji = _themeEmoji[theme.toLowerCase()] ?? '✦';
    final cardW = MediaQuery.sizeOf(context).width * 0.42;

    return Padding(
      padding: const EdgeInsets.only(top: kSpaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
            child: Row(
              children: [
                Text(
                  '$label $emoji',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (items.length > 3)
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'More >',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: kSpaceSm),
          // Horizontal scroll row
          SizedBox(
            height: cardW * (4 / 3),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: kSpaceSm),
              itemBuilder: (ctx, idx) {
                final t = items[idx];
                return SizedBox(
                  width: cardW,
                  child: TemplateCard(
                    template: t,
                    isHot: idx < 2,
                    onTap: () => ctx.go('/home/template/${t.id}', extra: t),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    final cardW = MediaQuery.sizeOf(context).width * 0.42;
    return SkeletonScope(
      child: Padding(
        padding: const EdgeInsets.only(top: kSpaceLg, left: kSpaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: kSpaceSm),
            SizedBox(
              height: cardW * (4 / 3),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: kSpaceSm),
                itemBuilder: (_, __) => SizedBox(
                  width: cardW,
                  child: const SkeletonCard(),
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
// All Templates tab — full grid
// ---------------------------------------------------------------------------
class _AllTemplatesTab extends ConsumerWidget {
  const _AllTemplatesTab({required this.isAgent});
  final bool isAgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(templatesControllerProvider.notifier);
    final templatesAsync = ref.watch(templatesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Templates'),
        actions: [const BalanceChip()],
      ),
      body: RefreshIndicator(
        color: kSaffron,
        onRefresh: controller.refresh,
        child: templatesAsync.when(
          loading: () => const _SkeletonGrid(),
          error: (e, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.7,
              child: ErrorView(
                message: 'Could not load templates.',
                onRetry: controller.refresh,
              ),
            ),
          ),
          data: (templates) => templates.isEmpty
              ? const Center(child: Text('No templates available.'))
              : _TemplateGrid(templates: templates),
        ),
      ),
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({required this.templates});
  final List<Template> templates;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final crossAxisCount = w >= 900 ? 4 : w >= 600 ? 3 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(kSpaceMd),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: kSpaceSm,
        mainAxisSpacing: kSpaceSm,
        childAspectRatio: 3 / 4,
      ),
      itemCount: templates.length,
      itemBuilder: (context, i) {
        final t = templates[i];
        return TemplateCard(
          template: t,
          isHot: i < 4,
          onTap: () => context.go('/home/template/${t.id}', extra: t),
        );
      },
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
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

// ---------------------------------------------------------------------------
// My Orders tab — placeholder (order history)
// ---------------------------------------------------------------------------
class _MyOrdersTab extends StatelessWidget {
  const _MyOrdersTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: kSpaceMd),
            Text(
              'No orders yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: kSpaceSm),
            Text(
              'Your generated posters will appear here.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

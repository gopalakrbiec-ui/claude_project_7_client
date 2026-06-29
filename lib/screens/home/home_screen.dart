import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/templates_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order_summary.dart';
import '../../models/template.dart';
import '../../repositories/orders_repository.dart';
import '../../widgets/balance_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton_card.dart';
import '../../widgets/template_card.dart';

// ---------------------------------------------------------------------------
// My Orders state — simple local provider
// ---------------------------------------------------------------------------
final _myOrdersProvider = FutureProvider.autoDispose<OrderListPage>((ref) {
  return ref.read(ordersRepositoryProvider).getOrders();
});

// ---------------------------------------------------------------------------
// Root shell — bottom nav
// ---------------------------------------------------------------------------
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
// Discover tab — hero + grouped category rows
// ---------------------------------------------------------------------------
class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab({required this.isAgent});
  final bool isAgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(groupedTemplatesProvider);
    final controller = ref.read(groupedTemplatesProvider.notifier);

    return RefreshIndicator(
      color: kSaffron,
      onRefresh: controller.refresh,
      child: CustomScrollView(
        slivers: [
          _HeroBanner(isAgent: isAgent),
          groupedAsync.when(
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
            data: (groups) => _CategoryRows(groups: groups),
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

    return SliverToBoxAdapter(
      child: SizedBox(
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: const BoxDecoration(gradient: kBrandGradient)),
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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceLg, vertical: kSpaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Yaadein',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const Spacer(),
                        if (isAgent)
                          IconButton(
                            icon: const Icon(Icons.storefront_outlined,
                                color: Colors.white70),
                            onPressed: () =>
                                context.go('/home/agent-earnings'),
                          ),
                        const BalanceChip(),
                      ],
                    ),
                    const Spacer(),
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
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: kSpaceMd),
                    Container(
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
                          Icon(Icons.auto_awesome, size: 16, color: kSaffron),
                        ],
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
// Category rows — uses TemplateCategoryGroup list from grouped API
// ---------------------------------------------------------------------------
class _CategoryRows extends StatelessWidget {
  const _CategoryRows({required this.groups});
  final List<TemplateCategoryGroup> groups;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        return _CategorySection(group: group);
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.group});
  final TemplateCategoryGroup group;

  static const _themeEmoji = <String, String>{
    'wedding':    '💍',
    'bridal':     '👰',
    'floral':     '🌸',
    'royal':      '👑',
    'garden':     '🌿',
    'birthday':   '🎂',
    'business':   '💼',
    'bollywood':  '🎬',
    'cricket':    '🏏',
    'festival':   '🪔',
  };

  @override
  Widget build(BuildContext context) {
    final emoji = _themeEmoji[group.category.toLowerCase()] ?? '✦';
    final cardW = MediaQuery.sizeOf(context).width * 0.42;

    return Padding(
      padding: const EdgeInsets.only(top: kSpaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
            child: Row(
              children: [
                Text(
                  '${group.label} $emoji',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (group.templates.length > 3)
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
          SizedBox(
            height: cardW * (4 / 3),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
              itemCount: group.templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: kSpaceSm),
              itemBuilder: (ctx, idx) {
                final t = group.templates[idx];
                return SizedBox(
                  width: cardW,
                  child: TemplateCard(
                    template: t,
                    isHot: t.isFeatured,
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
// All Templates tab
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
          isHot: t.isFeatured,
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
// My Orders tab — paginated list, tap to view order status
// ---------------------------------------------------------------------------
class _MyOrdersTab extends ConsumerWidget {
  const _MyOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_myOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_myOrdersProvider),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorView(
            message: 'Could not load orders.',
            onRetry: () => ref.invalidate(_myOrdersProvider),
          ),
        ),
        data: (page) => page.orders.isEmpty
            ? _EmptyOrders()
            : _OrdersList(page: page),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
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
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.page});
  final OrderListPage page;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(kSpaceMd),
      itemCount: page.orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: kSpaceSm),
      itemBuilder: (ctx, i) => _OrderCard(order: page.orders[i]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = order.isDone
        ? Colors.green
        : order.isFailed
            ? theme.colorScheme.error
            : kSaffron;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/home/order-status/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(kSpaceMd),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 60,
                  height: 80,
                  child: order.resultUrl != null
                      ? CachedNetworkImage(
                          imageUrl: order.resultUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const _FallbackThumb(),
                        )
                      : const _FallbackThumb(),
                ),
              ),
              const SizedBox(width: kSpaceMd),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.templateName ?? 'Poster',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.priceDisplay,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (order.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: Colors.white54),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/background_orders_controller.dart';
import '../../controllers/background_tool_jobs_controller.dart';
import '../../controllers/templates_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/token_storage.dart';
import '../../models/order_summary.dart';
import '../../models/template.dart';
import '../../repositories/orders_repository.dart';
import '../../repositories/tools_repository.dart';
import '../../screens/tools/tools_screen.dart'
    show toolsListProvider, ToolWorkScreen;
import '../../widgets/balance_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton_card.dart';
import '../../widgets/template_card.dart';

// ---------------------------------------------------------------------------
// My Orders provider
// ---------------------------------------------------------------------------
final _myOrdersProvider = FutureProvider.autoDispose<OrderListPage>((ref) {
  return ref.read(ordersRepositoryProvider).getOrders();
});

// ---------------------------------------------------------------------------
// Root shell — bottom nav with centre AI FAB
// ---------------------------------------------------------------------------
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  bool _showToolsMenu = false;

  void _toggleToolsMenu() =>
      setState(() => _showToolsMenu = !_showToolsMenu);

  void _closeToolsMenu() {
    if (_showToolsMenu) setState(() => _showToolsMenu = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isAgent = authState is AuthAuthenticated && authState.profile.isAgent;
    final toolsAsync = ref.watch(toolsListProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: _HomeAppBar(isAgent: isAgent),
          body: IndexedStack(
            index: _tab,
            children: [
              _HomeTab(isAgent: isAgent),
              const _VideoTab(),
            ],
          ),
          floatingActionButton: Container(
            decoration: _showToolsMenu
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: kSaffron.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 4),
                      BoxShadow(
                          color: kMagenta.withValues(alpha: 0.4),
                          blurRadius: 36,
                          spreadRadius: 6),
                    ],
                  )
                : null,
            child: FloatingActionButton(
              onPressed: _toggleToolsMenu,
              backgroundColor: _showToolsMenu ? Colors.white : kSaffron,
              foregroundColor: _showToolsMenu ? kSaffron : Colors.white,
              elevation: _showToolsMenu ? 0 : 6,
              shape: const CircleBorder(),
              child: AnimatedRotation(
                turns: _showToolsMenu ? 0.125 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                    _showToolsMenu ? Icons.close : Icons.auto_awesome,
                    size: 28),
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            color: kDarkSurface,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            height: 72,
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Home',
                    selected: _tab == 0,
                    onTap: () {
                      _closeToolsMenu();
                      setState(() => _tab = 0);
                    },
                  ),
                ),
                const Expanded(child: SizedBox()),
                Expanded(
                  child: _NavItem(
                    icon: Icons.video_library_outlined,
                    selectedIcon: Icons.video_library,
                    label: 'Video',
                    selected: _tab == 1,
                    onTap: () {
                      _closeToolsMenu();
                      setState(() => _tab = 1);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Radial tools overlay
        if (_showToolsMenu)
          _RadialToolsMenu(
            toolsAsync: toolsAsync,
            onClose: _closeToolsMenu,
            onToolTap: (tool) {
              _closeToolsMenu();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => ToolWorkScreen(tool: tool)),
              );
            },
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Nav sits on dark ribbon — use white for unselected, saffron for selected.
    final color = selected ? kSaffron : Colors.white60;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App bar with icon + welcome + profile button
// ---------------------------------------------------------------------------
class _HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _HomeAppBar({this.isAgent = false});
  final bool isAgent;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final storage = ref.read(tokenStorageProvider);

    String displayName = '';
    if (authState is AuthAuthenticated) {
      final storedName = storage.name;
      final firstName = storage.firstName;
      displayName = storedName ??
          authState.profile.name ??
          (firstName != null && firstName.isNotEmpty
              ? firstName
              : authState.profile.phone);
    }

    return AppBar(
      backgroundColor: kDarkSurface,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      toolbarHeight: 64,
      titleSpacing: kSpaceSm,
      title: Row(
        children: [
          // App icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kSaffron, kMagenta],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Yaadein',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  displayName.isNotEmpty
                      ? 'Welcome, $displayName'
                      : 'Welcome',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (isAgent)
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push('/home/agent-earnings'),
          ),
        const BalanceChip(),
        _ProfileBadgeButton(onTap: () {
          ref.read(backgroundOrdersProvider.notifier).clearCompleted();
          ref.read(backgroundToolJobsProvider.notifier).clearCompleted();
          context.push('/home/profile');
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile button with completed-orders badge
// ---------------------------------------------------------------------------
class _ProfileBadgeButton extends ConsumerWidget {
  const _ProfileBadgeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCompleted = ref.watch(
          backgroundOrdersProvider.select((s) => s.hasCompleted)) ||
        ref.watch(
            backgroundToolJobsProvider.select((s) => s.hasCompleted));
    return IconButton(
      onPressed: onTap,
      iconSize: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      icon: Badge(
        isLabelVisible: hasCompleted,
        backgroundColor: Colors.red,
        child: const Icon(Icons.account_circle_outlined, size: 36),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home tab — grouped templates by theme with horizontal scroll
// ---------------------------------------------------------------------------
class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.isAgent});
  final bool isAgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(groupedTemplatesProvider);
    final controller = ref.read(groupedTemplatesProvider.notifier);

    return Scaffold(
      body: RefreshIndicator(
        color: kSaffron,
        onRefresh: controller.refresh,
        child: groupedAsync.when(
          loading: () => const _CategorySkeleton(),
          error: (e, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: ErrorView(
                message: 'Could not load templates.',
                onRetry: controller.refresh,
              ),
            ),
          ),
          data: (groups) => groups.isEmpty
              ? const Center(child: Text('No templates available.'))
              : _CategoryRows(groups: groups),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category rows — horizontal scroll per group
// ---------------------------------------------------------------------------
class _CategoryRows extends StatelessWidget {
  const _CategoryRows({required this.groups});
  final List<TemplateCategoryGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: kSpaceSm, bottom: kSpaceXl),
      itemCount: groups.length,
      itemBuilder: (context, i) => _CategorySection(group: groups[i]),
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
                        'More →',
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
      child: ListView.builder(
        padding: const EdgeInsets.only(top: kSpaceLg),
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: kSpaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
                child: Container(
                  width: 140,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: kSpaceSm),
              SizedBox(
                height: cardW * (4 / 3),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: kSpaceSm),
                  itemBuilder: (_, __) =>
                      SizedBox(width: cardW, child: const SkeletonCard()),
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
// Video tab — placeholder
// ---------------------------------------------------------------------------
class _VideoTab extends StatelessWidget {
  const _VideoTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kSaffron, kMagenta],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.video_library_outlined,
                color: Colors.white, size: 44),
          ),
          const SizedBox(height: 24),
          Text(
            'Video Generation',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon! Create beautiful\nvideo memories with AI.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Orders screen — navigated to from Profile
// ---------------------------------------------------------------------------
class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

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
          Icon(Icons.inbox_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: kSpaceMd),
          Text('No orders yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 18)),
          const SizedBox(height: kSpaceSm),
          Text(
            'Your generated posters will appear here.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 60,
                  height: 80,
                  child: order.resultUrl != null
                      ? CachedNetworkImage(
                          imageUrl: order.resultUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const _FallbackThumb(),
                        )
                      : const _FallbackThumb(),
                ),
              ),
              const SizedBox(width: kSpaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.templateName ?? 'Poster',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.priceDisplay,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (order.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(order.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11),
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
    final diff = DateTime.now().difference(dt);
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

// ---------------------------------------------------------------------------
// Glamorous radial tools menu — animated arc overlay with per-tool gradients
// ---------------------------------------------------------------------------
class _RadialToolsMenu extends StatefulWidget {
  const _RadialToolsMenu({
    required this.toolsAsync,
    required this.onClose,
    required this.onToolTap,
  });

  final AsyncValue<List<AiToolDef>> toolsAsync;
  final VoidCallback onClose;
  final void Function(AiToolDef tool) onToolTap;

  @override
  State<_RadialToolsMenu> createState() => _RadialToolsMenuState();
}

class _RadialToolsMenuState extends State<_RadialToolsMenu>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _itemsCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..forward();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _itemsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _itemsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mq = MediaQuery.of(context);
    final cx = size.width / 2;
    // FAB center = screen height − system nav bar − bottom bar + FAB half-height
    final bottomInset = mq.viewPadding.bottom;
    final fabY = size.height - bottomInset - 72 + 28;

    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, child) => Opacity(
        opacity: CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut).value,
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onClose,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 1.15),
              radius: 1.5,
              colors: const [Color(0xE8160C2C), Color(0xD9000000)],
            ),
          ),
          child: Stack(
            children: [
              // Pulsing glow ring behind FAB
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) {
                  final r = 48.0 + 28.0 * _pulseCtrl.value;
                  final alpha = 0.35 - 0.28 * _pulseCtrl.value;
                  return Positioned(
                    left: cx - r,
                    top: fabY - r,
                    child: Container(
                      width: r * 2,
                      height: r * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          kSaffron.withValues(alpha: alpha),
                          kMagenta.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  );
                },
              ),
              // Title label
              Positioned(
                top: size.height * 0.28,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _itemsCtrl,
                  builder: (_, __) => Opacity(
                    opacity: CurvedAnimation(
                      parent: _itemsCtrl,
                      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                    ).value,
                    child: const Column(
                      children: [
                        Text(
                          '✦  AI Magic Tools  ✦',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(color: kSaffron, blurRadius: 12),
                              Shadow(color: kMagenta, blurRadius: 24),
                            ],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap a tool to get started',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Tool items
              widget.toolsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (tools) => _GlamArcItems(
                  tools: tools,
                  ctrl: _itemsCtrl,
                  onToolTap: widget.onToolTap,
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
// Arc layout with staggered spring animations
// ---------------------------------------------------------------------------
class _GlamArcItems extends StatelessWidget {
  const _GlamArcItems({
    required this.tools,
    required this.ctrl,
    required this.onToolTap,
  });

  final List<AiToolDef> tools;
  final AnimationController ctrl;
  final void Function(AiToolDef) onToolTap;

  static const _btnSize = 52.0;
  static const _totalSlot = 76.0; // button + label height

  static List<Color> _colorsFor(String id) {
    final n = id.toLowerCase();
    if (n.contains('filter')) return [const Color(0xFF7B1FA2), const Color(0xFFCE93D8)];
    if (n.contains('background')) return [const Color(0xFF00695C), const Color(0xFF4DB6AC)];
    if (n.contains('outfit')) return [const Color(0xFF880E4F), const Color(0xFFF06292)];
    if (n.contains('hair')) return [const Color(0xFF4A148C), const Color(0xFFBA68C8)];
    if (n.contains('remix')) return [const Color(0xFFBF360C), const Color(0xFFFF8A65)];
    if (n.contains('text')) return [const Color(0xFF1B5E20), const Color(0xFF66BB6A)];
    if (n.contains('animate')) return [const Color(0xFF0D47A1), const Color(0xFF42A5F5)];
    return [kSaffron, kMagenta];
  }

  static IconData _iconFor(String id) {
    final n = id.toLowerCase();
    if (n.contains('filter')) return Icons.auto_fix_high;
    if (n.contains('outfit')) return Icons.checkroom_outlined;
    if (n.contains('animate')) return Icons.play_circle_outline_rounded;
    if (n.contains('background')) return Icons.wallpaper_rounded;
    if (n.contains('hair')) return Icons.content_cut_outlined;
    if (n.contains('remix')) return Icons.shuffle_rounded;
    if (n.contains('text')) return Icons.text_fields_rounded;
    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final cx = size.width / 2;
    // FAB centre — same formula as _RadialToolsMenuState so glow and items align
    final bottomInset = mq.viewPadding.bottom;
    final cy = size.height - bottomInset - 72 + 28;

    // Arc from 150° to 30° (120° spread). At 30° sin≈0.5, so items land
    // at least radius/2 above cy — enough to clear the ribbon.
    const startDeg = 150.0;
    const endDeg = 30.0;
    final startAngle = startDeg * math.pi / 180;
    final endAngle = endDeg * math.pi / 180;
    // Keep edge items inside screen with 16dp margin
    final maxR = (cx - 16 - _btnSize / 2) / math.cos(math.pi - startAngle).abs();
    final radius = maxR.clamp(130.0, 185.0);

    final n = tools.length;
    return Stack(
      children: [
        for (var i = 0; i < n; i++) _buildItem(context, tools[i], i, n,
            cx, cy, radius, startAngle, endAngle),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    AiToolDef tool,
    int i,
    int n,
    double cx,
    double cy,
    double radius,
    double startAngle,
    double endAngle,
  ) {
    final angle = n == 1
        ? math.pi / 2
        : startAngle + (endAngle - startAngle) * i / (n - 1);

    final targetDx = cx + radius * math.cos(angle) - _btnSize / 2;
    final targetDy = cy - radius * math.sin(angle) - _totalSlot / 2;

    // Stagger: item i starts at t=i*0.07, runs for 0.55 of the total
    final t0 = (i * 0.07).clamp(0.0, 0.45);
    final t1 = (t0 + 0.55).clamp(0.0, 1.0);
    final springAnim = CurvedAnimation(
      parent: ctrl,
      curve: Interval(t0, t1, curve: Curves.elasticOut),
    );
    final fadeAnim = CurvedAnimation(
      parent: ctrl,
      curve: Interval(t0, (t0 + 0.25).clamp(0.0, 1.0), curve: Curves.easeOut),
    );

    // Items animate from FAB position (cx, cy) outward to their target
    final colors = _colorsFor(tool.id);
    final icon = _iconFor(tool.id);

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = springAnim.value;
        final left = cx - _btnSize / 2 + (targetDx - (cx - _btnSize / 2)) * t;
        final top = cy - _totalSlot / 2 + (targetDy - (cy - _totalSlot / 2)) * t;
        return Positioned(
          left: left,
          top: top,
          child: Opacity(
            opacity: fadeAnim.value.clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () => onToolTap(tool),
              child: SizedBox(
                width: _btnSize,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glow aura + gradient button
                    Container(
                      width: _btnSize + 8,
                      height: _btnSize + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withValues(alpha: 0.55),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: colors[1].withValues(alpha: 0.25),
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.40),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(icon, color: Colors.white,
                            size: _btnSize * 0.42),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tool.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 8),
                          Shadow(color: Colors.black, blurRadius: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

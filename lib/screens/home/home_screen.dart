import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../../screens/inspire/inspire_screen.dart';
import '../../screens/photo_merge/photo_merge_screen.dart';
import '../../screens/tools/tools_screen.dart'
    show toolsListProvider, ToolWorkScreen;
import '../../widgets/balance_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/skeleton_card.dart';
import '../../widgets/template_card.dart';

// ---------------------------------------------------------------------------
// Profile picture path (from SharedPreferences, set in profile screen)
// ---------------------------------------------------------------------------
final _profilePicPathProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('profile_pic_path');
});

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
  bool _showToolsMenu = false;

  void _toggleToolsMenu() =>
      setState(() => _showToolsMenu = !_showToolsMenu);

  void _closeToolsMenu() {
    if (_showToolsMenu) setState(() => _showToolsMenu = false);
  }

  void _showInspireSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InspireScreen()),
    );
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
          body: _HomeTab(isAgent: isAgent),
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
                    selected: true,
                    onTap: _closeToolsMenu,
                  ),
                ),
                const Expanded(child: SizedBox()),
                Expanded(
                  child: _NavItem(
                    icon: Icons.auto_fix_high_outlined,
                    selectedIcon: Icons.auto_fix_high,
                    label: 'Inspire',
                    selected: false,
                    onTap: () {
                      _closeToolsMenu();
                      _showInspireSheet(context);
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
              final isPhotoMerge = tool.id == 'photo-merge' ||
                  tool.name.toLowerCase().contains('photo merge') ||
                  tool.name.toLowerCase().contains('photo-merge');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => isPhotoMerge
                      ? PhotoMergeScreen(tool: tool)
                      : ToolWorkScreen(tool: tool),
                ),
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
          context.push('/home/profile').then((_) {
            ref.read(backgroundOrdersProvider.notifier).clearCompleted();
            ref.read(backgroundToolJobsProvider.notifier).clearCompleted();
          });
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
    final picPath = ref.watch(_profilePicPathProvider).valueOrNull;

    final Widget avatar = picPath != null
        ? ClipOval(
            child: Image.file(File(picPath),
                width: 36, height: 36, fit: BoxFit.cover),
          )
        : const Icon(Icons.account_circle_outlined, size: 36);

    return IconButton(
      onPressed: onTap,
      iconSize: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      icon: Badge(
        isLabelVisible: hasCompleted,
        backgroundColor: Colors.red,
        child: avatar,
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
// Glamorous radial tools menu — spinning wheel overlay
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
  late final AnimationController _snapCtrl;

  double _wheelRotation = 0.0;
  Animation<double>? _snapAnim;

  // Angle-based pan tracking
  Offset? _lastPanPos;
  double _cx = 0;
  double _cy = 0;

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
    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _snapCtrl.addListener(_onSnapTick);
  }

  void _onSnapTick() {
    final a = _snapAnim;
    if (a != null) setState(() => _wheelRotation = a.value);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _itemsCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    if (_snapCtrl.isAnimating) _snapCtrl.stop();
    _lastPanPos = d.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final prev = _lastPanPos;
    if (prev == null) return;
    final curr = d.localPosition;

    final prevAngle = math.atan2(-(prev.dy - _cy), prev.dx - _cx);
    final currAngle = math.atan2(-(curr.dy - _cy), curr.dx - _cx);

    var delta = currAngle - prevAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    setState(() => _wheelRotation += delta);
    _lastPanPos = curr;
  }

  void _onPanEnd(DragEndDetails d, int n) {
    _lastPanPos = null;
    _snapToNearest(n);
  }

  void _snapToNearest(int n) {
    if (n == 0) return;
    final spacing = 2 * math.pi / n;
    double offset = _wheelRotation % spacing;
    if (offset < 0) offset += spacing;
    final snapTo = offset <= spacing / 2
        ? _wheelRotation - offset
        : _wheelRotation - offset + spacing;
    _snapAnim = Tween<double>(begin: _wheelRotation, end: snapTo).animate(
        CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic));
    _snapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mq = MediaQuery.of(context);
    final cx = size.width / 2;
    final bottomInset = mq.viewPadding.bottom;
    // Arc center raised 40px vs FAB to give more wheel space
    final cy = size.height - bottomInset - 72 - 40 + 28;
    // FAB actual center for glow ring
    final fabGlowY = size.height - bottomInset - 72 + 28;

    final maxR = (cx - 16 - _GlamArcItems._btnSize / 2) /
        math.cos(math.pi - 150.0 * math.pi / 180).abs();
    final radius = maxR.clamp(140.0, 200.0);

    // Store for angle-based pan tracking
    _cx = cx;
    _cy = cy;

    final toolCount = widget.toolsAsync.maybeWhen(
        data: (t) => t.length, orElse: () => 0);

    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, child) => Opacity(
        opacity: CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut).value,
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onClose,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (d) => _onPanEnd(d, toolCount),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 1.15),
              radius: 1.5,
              colors: [Color(0xE8160C2C), Color(0xD9000000)],
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
                    top: fabGlowY - r,
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
                top: size.height * 0.10,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _itemsCtrl,
                  builder: (_, __) => Opacity(
                    opacity: CurvedAnimation(
                      parent: _itemsCtrl,
                      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                    ).value,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [kSaffron, kMagenta],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'AI Magic Tools',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(color: kSaffron, blurRadius: 16),
                              Shadow(color: kMagenta, blurRadius: 32),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Swipe to spin  ·  Tap to use',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xAAFFFFFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Tool items
              Positioned.fill(
                child: widget.toolsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (tools) => _GlamArcItems(
                    tools: tools,
                    ctrl: _itemsCtrl,
                    cx: cx,
                    cy: cy,
                    radius: radius,
                    wheelRotation: _wheelRotation,
                    onToolTap: widget.onToolTap,
                  ),
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
// Spinning wheel arc layout — full 360° wheel, top arc visible
// ---------------------------------------------------------------------------
class _GlamArcItems extends StatelessWidget {
  const _GlamArcItems({
    required this.tools,
    required this.ctrl,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.wheelRotation,
    required this.onToolTap,
  });

  final List<AiToolDef> tools;
  final AnimationController ctrl;
  final double cx;
  final double cy;
  final double radius;
  final double wheelRotation;
  final void Function(AiToolDef) onToolTap;

  static const _btnSize = 52.0;
  static const _labelWidth = 72.0;
  static const _labelHeight = 22.0;

  // Visible window: angles in [_loRad, _hiRad] (from +x axis, counterclockwise)
  static const _loRad = 20.0 * math.pi / 180;
  static const _hiRad = 160.0 * math.pi / 180;
  static const _fadeZoneRad = 15.0 * math.pi / 180;

  static List<Color> _colorsFor(String id) {
    final n = id.toLowerCase();
    if (n.contains('photo merge') || n.contains('photo-merge')) return [const Color(0xFFE65100), const Color(0xFFFFB74D)];
    if (n.contains('filter')) return [const Color(0xFF7B1FA2), const Color(0xFFCE93D8)];
    if (n.contains('background')) return [const Color(0xFF00695C), const Color(0xFF4DB6AC)];
    if (n.contains('outfit')) return [const Color(0xFF880E4F), const Color(0xFFF06292)];
    if (n.contains('hair')) return [const Color(0xFF4A148C), const Color(0xFFBA68C8)];
    if (n.contains('remix')) return [const Color(0xFFBF360C), const Color(0xFFFF8A65)];
    if (n.contains('text')) return [const Color(0xFF1B5E20), const Color(0xFF66BB6A)];
    if (n.contains('animate')) return [const Color(0xFF0D47A1), const Color(0xFF42A5F5)];
    if (n.contains('veo')) return [const Color(0xFF1A237E), const Color(0xFF7986CB)];
    if (n.contains('seedance') || n.contains('seed dance')) return [const Color(0xFF880E4F), const Color(0xFFFF80AB)];
    if (n.contains('kling')) return [const Color(0xFF004D40), const Color(0xFF80CBC4)];
    if (n.contains('wan') || n.contains('wanx')) return [const Color(0xFF37474F), const Color(0xFF90A4AE)];
    if (n.contains('video')) return [const Color(0xFF311B92), const Color(0xFF9575CD)];
    return [kSaffron, kMagenta];
  }

  static IconData _iconFor(String id) {
    final n = id.toLowerCase();
    if (n.contains('photo merge') || n.contains('photo-merge')) return Icons.merge_type_rounded;
    if (n.contains('filter')) return Icons.auto_fix_high;
    if (n.contains('outfit')) return Icons.checkroom_outlined;
    if (n.contains('animate')) return Icons.play_circle_outline_rounded;
    if (n.contains('background')) return Icons.wallpaper_rounded;
    if (n.contains('hair')) return Icons.content_cut_outlined;
    if (n.contains('remix')) return Icons.shuffle_rounded;
    if (n.contains('text')) return Icons.text_fields_rounded;
    if (n.contains('veo') || n.contains('seedance') || n.contains('kling') ||
        n.contains('wan') || n.contains('video')) return Icons.videocam_rounded;
    return Icons.auto_awesome;
  }

  double _normAngle(double a) {
    final n = a % (2 * math.pi);
    return n < 0 ? n + 2 * math.pi : n;
  }

  @override
  Widget build(BuildContext context) {
    final n = tools.length;
    if (n == 0) return const SizedBox.shrink();

    // Effective angle for each tool in [0, 2π), tool 0 at top (π/2) when rotation=0
    final angles = List.generate(n, (i) =>
        _normAngle(math.pi / 2 - 2 * math.pi * i / n + wheelRotation));

    // Find tool closest to π/2 (12 o'clock)
    int centeredIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < n; i++) {
      double dist = (angles[i] - math.pi / 2).abs();
      if (dist > math.pi) dist = 2 * math.pi - dist;
      if (dist < minDist) {
        minDist = dist;
        centeredIdx = i;
      }
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final widgets = <Widget>[];
        for (int i = 0; i < n; i++) {
          widgets.addAll(_buildToolWidgets(i, n, angles[i], i == centeredIdx));
        }
        return Stack(children: widgets);
      },
    );
  }

  List<Widget> _buildToolWidgets(
      int i, int n, double normAngle, bool isCentered) {
    // Hide tools outside visible arc
    if (normAngle < _loRad || normAngle > _hiRad) return [];

    // Edge fade
    double edgeOpacity = 1.0;
    if (normAngle < _loRad + _fadeZoneRad) {
      edgeOpacity = (normAngle - _loRad) / _fadeZoneRad;
    } else if (normAngle > _hiRad - _fadeZoneRad) {
      edgeOpacity = (_hiRad - normAngle) / _fadeZoneRad;
    }

    // Entrance stagger
    final t0 = (i * 0.07).clamp(0.0, 0.45);
    final t1 = (t0 + 0.55).clamp(0.0, 1.0);
    final springT = CurvedAnimation(
            parent: ctrl,
            curve: Interval(t0, t1, curve: Curves.elasticOut))
        .value;
    final fadeT = CurvedAnimation(
            parent: ctrl,
            curve: Interval(
                t0, (t0 + 0.25).clamp(0.0, 1.0),
                curve: Curves.easeOut))
        .value;

    final totalOpacity = (edgeOpacity * fadeT).clamp(0.0, 1.0);
    if (totalOpacity <= 0) return [];

    // Icon position on circle
    final iconX = cx + radius * math.cos(normAngle);
    final iconY = cy - radius * math.sin(normAngle);
    final animX = cx + (iconX - cx) * springT;
    final animY = cy + (iconY - cy) * springT;

    // Label position — further out radially above the icon
    final labelR = radius + _btnSize / 2 + 14;
    final labelX = cx + labelR * math.cos(normAngle);
    final labelY = cy - labelR * math.sin(normAngle);
    final animLabelX = cx + (labelX - cx) * springT;
    final animLabelY = cy + (labelY - cy) * springT;

    // Text rotates to follow radial direction (upright at top, tilted at sides)
    final textRot = math.pi / 2 - normAngle;

    final colors = _colorsFor(tools[i].name);
    final icon = _iconFor(tools[i].name);
    final scale = isCentered ? 1.18 : 1.0;
    final glowAlpha = isCentered ? 0.80 : 0.55;
    final blurR = isCentered ? 32.0 : 22.0;

    final iconWidget = Positioned(
      left: animX - (_btnSize + 8) / 2,
      top: animY - (_btnSize + 8) / 2,
      child: Opacity(
        opacity: totalOpacity,
        child: Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () => onToolTap(tools[i]),
            child: Container(
              width: _btnSize + 8,
              height: _btnSize + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors[0].withValues(alpha: glowAlpha),
                    blurRadius: blurR,
                    spreadRadius: isCentered ? 5 : 3,
                  ),
                  BoxShadow(
                    color: colors[1].withValues(alpha: isCentered ? 0.40 : 0.25),
                    blurRadius: isCentered ? 56 : 40,
                    spreadRadius: isCentered ? 8 : 6,
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
                    color: Colors.white.withValues(alpha: isCentered ? 0.70 : 0.40),
                    width: isCentered ? 2.0 : 1.5,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: _btnSize * 0.42),
              ),
            ),
          ),
        ),
      ),
    );

    final labelWidget = Positioned(
      left: animLabelX - _labelWidth / 2,
      top: animLabelY - _labelHeight / 2,
      child: Opacity(
        opacity: totalOpacity,
        child: Transform.rotate(
          angle: textRot,
          child: SizedBox(
            width: _labelWidth,
            child: Text(
              tools[i].name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCentered
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.85),
                fontSize: 9.5,
                fontWeight: isCentered ? FontWeight.w700 : FontWeight.w600,
                height: 1.2,
                decoration: TextDecoration.none,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 8),
                  Shadow(color: Colors.black, blurRadius: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return [iconWidget, labelWidget];
  }
}

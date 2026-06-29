import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/auth_controller.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/token_storage.dart';
import '../../models/order_summary.dart';
import '../../repositories/orders_repository.dart';
import '../../widgets/error_view.dart';

final _profileOrdersProvider = FutureProvider.autoDispose<OrderListPage>((ref) {
  return ref.read(ordersRepositoryProvider).getOrders();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final storage = ref.read(tokenStorageProvider);
    final theme = Theme.of(context);

    final firstName = storage.firstName;
    final lastName = storage.lastName;
    final city = storage.city;
    final country = storage.country;

    String displayName = '';
    String phone = '';
    if (authState is AuthAuthenticated) {
      phone = authState.profile.phone;
      displayName = authState.profile.name ??
          (firstName != null
              ? '$firstName ${lastName ?? ''}'.trim()
              : phone);
    }

    final ordersAsync = ref.watch(_profileOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/home/profile/edit'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Avatar + name
          Container(
            padding: const EdgeInsets.symmetric(vertical: kSpaceXl),
            decoration: const BoxDecoration(gradient: kBrandGradient),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white24,
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: kSpaceMd),
                Text(
                  displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(phone,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ],
                if (city != null && city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [city, country].where((s) => s != null && s!.isNotEmpty).join(', '),
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),

          // Quick settings
          Padding(
            padding: const EdgeInsets.all(kSpaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: kSpaceSm),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.language_outlined,
                        label: 'Language',
                        trailing: const Text('English'),
                        onTap: () => context.push('/language-select'),
                      ),
                      _SettingsTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Credits & Topup',
                        onTap: () => context.push('/home/topup'),
                      ),
                      _SettingsTile(
                        icon: Icons.logout,
                        label: 'Sign Out',
                        onTap: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                        },
                        color: theme.colorScheme.error,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: kSpaceLg),
                Text('Past Orders',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: kSpaceSm),
              ],
            ),
          ),

          // Orders list
          ordersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(kSpaceMd),
              child: ErrorView(
                message: 'Could not load orders.',
                onRetry: () => ref.invalidate(_profileOrdersProvider),
              ),
            ),
            data: (page) => page.orders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(kSpaceMd),
                    child: Center(
                      child: Text('No orders yet.',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpaceMd, vertical: 0),
                    itemCount: page.orders.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: kSpaceSm),
                    itemBuilder: (ctx, i) =>
                        _ProfileOrderCard(order: page.orders[i]),
                  ),
          ),
          const SizedBox(height: kSpaceLg),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 15)),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

class _ProfileOrderCard extends StatelessWidget {
  const _ProfileOrderCard({required this.order});
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
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 72,
                  child: order.resultUrl != null
                      ? CachedNetworkImage(
                          imageUrl: order.resultUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _thumb(context),
                        )
                      : _thumb(context),
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
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
            child: Icon(Icons.image_outlined, size: 24, color: Colors.white54)),
      );
}

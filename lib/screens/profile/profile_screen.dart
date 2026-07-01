import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/background_tool_jobs_controller.dart'
    show backgroundToolJobsProvider, CompletedToolJob, ToolJobStatus;
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/token_storage.dart';
import '../../models/order_summary.dart';
import '../../repositories/orders_repository.dart';
import '../../widgets/error_view.dart';

final _profileOrdersProvider = FutureProvider.autoDispose<OrderListPage>((ref) {
  return ref.read(ordersRepositoryProvider).getOrders();
});

// Stores the local profile picture path chosen by the user.
final _profilePicProvider =
    StateNotifierProvider<_ProfilePicNotifier, String?>(_ProfilePicNotifier.new);

class _ProfilePicNotifier extends StateNotifier<String?> {
  _ProfilePicNotifier(Ref ref) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('profile_pic_path');
  }

  Future<void> pick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_pic_path', picked.path);
    state = picked.path;
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final storage = ref.read(tokenStorageProvider);
    final theme = Theme.of(context);
    final picPath = ref.watch(_profilePicProvider);

    final storedName = storage.name;
    final firstName = storage.firstName;
    final lastName = storage.lastName;
    final email = storage.email;
    final mobile = storage.mobile;
    final city = storage.city;
    final country = storage.country;

    String displayName = '';
    String phone = '';
    if (authState is AuthAuthenticated) {
      phone = authState.profile.phone;
      displayName = storedName ??
          authState.profile.name ??
          (firstName != null
              ? '$firstName ${lastName ?? ''}'.trim()
              : phone);
    }

    final ordersAsync = ref.watch(_profileOrdersProvider);
    final toolJobsState = ref.watch(backgroundToolJobsProvider);
    final completedJobs = toolJobsState.completedJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: ListView(
        children: [
          // Avatar + name
          Container(
            padding: const EdgeInsets.symmetric(vertical: kSpaceXl),
            decoration: const BoxDecoration(gradient: kBrandGradient),
            child: Column(
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => ref.read(_profilePicProvider.notifier).pick(),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white24,
                        backgroundImage: picPath != null
                            ? FileImage(File(picPath))
                            : null,
                        child: picPath == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 36,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(_profilePicProvider.notifier).pick(),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Color(0xFFFF6B23)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpaceMd),
                Text(
                  displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                if ((email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(email!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
                if ((mobile ?? phone).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(mobile ?? phone,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
                if ((city ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [city, country]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(', '),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(_profilePicProvider.notifier).pick(),
                  icon: const Icon(Icons.photo_library_outlined,
                      color: Colors.white70, size: 16),
                  label: const Text('Change photo',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
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

              ],
            ),
          ),

          if (completedJobs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpaceMd, kSpaceLg, kSpaceMd, kSpaceSm),
              child: Text('AI Tool Jobs',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
                itemCount: completedJobs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) =>
                    _AiCreationCard(job: completedJobs[i]),
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.fromLTRB(kSpaceMd, kSpaceLg, kSpaceMd, kSpaceSm),
            child: Text('Past Orders',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
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

class _AiCreationCard extends StatelessWidget {
  const _AiCreationCard({required this.job});
  final CompletedToolJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = job.status == ToolJobStatus.active;
    final isFailed = job.status == ToolJobStatus.failed;

    return GestureDetector(
      onTap: () => context.push(
        '/home/tools/job/${job.jobId}',
        extra: {
          'toolName': job.toolName,
          'costDisplay': job.costDisplay,
        },
      ),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    width: 110,
                    height: 90,
                    child: isActive
                        ? _activePlaceholder(context)
                        : isFailed
                            ? _failedPlaceholder(context)
                            : job.resultUrl != null
                                ? job.isVideo
                                    ? Container(
                                        color: Colors.black,
                                        child: const Center(
                                          child: Icon(Icons.play_circle_outline,
                                              color: Colors.white, size: 36),
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: job.resultUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            _placeholder(context),
                                      )
                                : _placeholder(context),
                  ),
                  if (isActive)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              job.toolName,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isActive
                  ? 'Processing…'
                  : isFailed
                      ? 'Failed'
                      : job.costDisplay,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive
                    ? const Color(0xFFFF6B23)
                    : isFailed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
            child: Icon(Icons.auto_awesome, size: 28, color: Colors.white54)),
      );

  Widget _activePlaceholder(BuildContext context) => Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
            child: Icon(Icons.auto_awesome, size: 28, color: Color(0xFFFF6B23))),
      );

  Widget _failedPlaceholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Center(
            child: Icon(Icons.error_outline,
                size: 28, color: Theme.of(context).colorScheme.error)),
      );
}

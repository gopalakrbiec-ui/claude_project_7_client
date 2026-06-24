import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../controllers/agent_earnings_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants.dart';
import '../../models/agent_earnings.dart';
import '../../widgets/error_view.dart';

class AgentEarningsScreen extends ConsumerWidget {
  const AgentEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(agentEarningsControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final profile = authState is AuthAuthenticated ? authState.profile : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Earnings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(agentEarningsControllerProvider.notifier).refresh(),
        child: earningsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorBody(
            message: _friendlyError(e.toString()),
            onRetry: () =>
                ref.read(agentEarningsControllerProvider.notifier).refresh(),
          ),
          data: (earnings) => _EarningsBody(
            earnings: earnings,
            agentName: profile?.name,
          ),
        ),
      ),
    );
  }

  static String _friendlyError(String raw) {
    if (raw.contains('NetworkError') || raw.contains('SocketException')) {
      return 'No internet connection.\nPull down to retry.';
    }
    return 'Could not load earnings.\nPull down to retry.';
  }
}

// ---------------------------------------------------------------------------
class _EarningsBody extends StatelessWidget {
  const _EarningsBody({required this.earnings, this.agentName});
  final AgentEarnings earnings;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                kSpaceLg, kSpaceLg, kSpaceLg, kSpaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Greeting
                if (agentName != null) ...[
                  Text(
                    'Hello, $agentName',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: kSpaceSm),
                ],

                // Total earnings card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(kSpaceLg),
                    child: Column(
                      children: [
                        Text(
                          'Total Commission Earned',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: kSpaceSm),
                        Text(
                          earnings.totalCommissionDisplay,
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: kSpaceXs),
                        Text(
                          '${earnings.entries.length} order${earnings.entries.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: kSpaceLg),
                Text('Recent Commissions',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: kSpaceXs),
              ],
            ),
          ),
        ),

        // Commission list
        if (earnings.entries.isEmpty)
          const SliverFillRemaining(child: _EmptyEarnings())
        else
          SliverList.separated(
            itemCount: earnings.entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: kSpaceLg),
            itemBuilder: (context, i) =>
                _CommissionTile(entry: earnings.entries[i]),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class _CommissionTile extends StatelessWidget {
  const _CommissionTile({required this.entry});
  final CommissionEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('d MMM y').format(entry.createdAt.toLocal());

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: kSpaceLg, vertical: kSpaceXs),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(Icons.currency_rupee,
            size: 20, color: theme.colorScheme.onSecondaryContainer),
      ),
      title: Text(
        entry.customerName != null
            ? 'Order for ${entry.customerName}'
            : 'Order #${_shortId(entry.orderId)}',
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        dateStr,
        style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline),
      ),
      trailing: Text(
        entry.amountDisplay,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _shortId(String id) =>
      id.length > 8 ? id.substring(0, 8) : id;
}

// ---------------------------------------------------------------------------
class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined,
                size: 72, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: kSpaceMd),
            Text(
              'No earnings yet',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: kSpaceSm),
            Text(
              'Place orders for customers to earn commission.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: ErrorView(message: message, onRetry: onRetry),
      ),
    );
  }
}

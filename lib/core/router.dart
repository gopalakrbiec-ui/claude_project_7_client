import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../controllers/locale_controller.dart';
import '../screens/language_select/language_select_screen.dart';
import '../models/template.dart';
import '../screens/login/phone_entry_screen.dart';
import '../screens/login/otp_entry_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/template_detail/template_detail_screen.dart';
import '../screens/create_order/create_order_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/order_status/order_status_screen.dart';
import '../screens/agent_earnings/agent_earnings_screen.dart';
import '../screens/topup/topup_screen.dart';

// ---------------------------------------------------------------------------
// RouterNotifier — bridges Riverpod auth + locale state into GoRouter.
// ---------------------------------------------------------------------------
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
    _ref.listen(localeControllerProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final localeAsync = _ref.read(localeControllerProvider);
    final authState = _ref.read(authControllerProvider);

    // While auth is still loading, show splash.
    if (authState is AuthInitializing) return '/splash';

    final isAuthenticated = authState is AuthAuthenticated;
    final loc = state.matchedLocation;

    // 1. Not authenticated → login (allow /login/* sub-routes and language-select)
    final onLoginFlow = loc == '/login' || loc.startsWith('/login/');
    if (!isAuthenticated && !onLoginFlow && loc != '/language-select') {
      return '/login';
    }

    // 2. Authenticated user hits login → home
    if (isAuthenticated && onLoginFlow) return '/home';

    // 4. Agent-only route guard — consumers get redirected to home
    if (isAuthenticated) {
      final isAgent = authState.profile.isAgent;
      if (!isAgent && loc == '/home/agent-earnings') return '/home';
    }

    return null;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // Splash shown only while AuthInitializing — replaced by redirect ASAP.
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/language-select',
        builder: (_, __) => const LanguageSelectScreen(),
      ),

      // ── Login flow (two-step: phone → OTP) ──────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => const PhoneEntryScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (_, state) {
              final phone = (state.extra as Map?)?['phone'] as String? ?? '';
              return OtpEntryScreen(normalisedPhone: phone);
            },
          ),
        ],
      ),

      // ── Authenticated routes ─────────────────────────────────────────────
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'template/:id',
            builder: (_, state) => TemplateDetailScreen(
              templateId: state.pathParameters['id']!,
              // extra is a Template when navigating from the grid;
              // null on deep-links (detail screen falls back to cache / fetch).
              preloaded: state.extra is Template ? state.extra as Template : null,
            ),
          ),
          GoRoute(
            path: 'create-order/:templateId',
            builder: (_, state) => CreateOrderScreen(
              templateId: state.pathParameters['templateId']!,
              preloaded:
                  state.extra is Template ? state.extra as Template : null,
            ),
          ),
          GoRoute(
            path: 'payment',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return PaymentScreen(
                orderId: extra['orderId'] as String? ?? '',
                priceDisplay: extra['priceDisplay'] as String? ?? '',
              );
            },
          ),
          GoRoute(
            path: 'order-status/:orderId',
            builder: (_, state) =>
                OrderStatusScreen(orderId: state.pathParameters['orderId']!),
          ),
          GoRoute(
            path: 'agent-earnings',
            builder: (_, __) => const AgentEarningsScreen(),
          ),
          GoRoute(
            path: 'topup',
            builder: (_, __) => const TopupScreen(),
          ),
        ],
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Splash — shown only during the AuthInitializing window (<1 second).
// ---------------------------------------------------------------------------
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

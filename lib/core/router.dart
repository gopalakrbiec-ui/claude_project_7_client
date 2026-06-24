import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../controllers/locale_controller.dart';
import '../screens/language_select/language_select_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/template_detail/template_detail_screen.dart';
import '../screens/create_order/create_order_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/order_status/order_status_screen.dart';
import '../screens/agent_earnings/agent_earnings_screen.dart';

// ---------------------------------------------------------------------------
// RouterNotifier: bridges Riverpod state into GoRouter's refreshListenable.
// ---------------------------------------------------------------------------
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
    _ref.listen(localeControllerProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final localeAsync = _ref.read(localeControllerProvider);
    final authAsync = _ref.read(authControllerProvider);

    // While loading either piece of state, stay put.
    if (localeAsync.isLoading || authAsync.isLoading) return null;

    final localeIsSet = localeAsync.valueOrNull != null;
    final isAuthenticated = authAsync.valueOrNull != null;

    // 1. No locale yet → language picker (always, unless already there)
    if (!localeIsSet && state.matchedLocation != '/language-select') {
      return '/language-select';
    }

    // 2. Locale set but no auth → login
    if (localeIsSet &&
        !isAuthenticated &&
        state.matchedLocation != '/login' &&
        state.matchedLocation != '/language-select') {
      return '/login';
    }

    // 3. Authenticated user hits login → home
    if (isAuthenticated &&
        (state.matchedLocation == '/login' ||
            state.matchedLocation == '/language-select')) {
      return '/home';
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
    initialLocation: '/language-select',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/language-select',
        builder: (_, __) => const LanguageSelectScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'template/:id',
            builder: (_, state) => TemplateDetailScreen(
              templateId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'create-order/:templateId',
            builder: (_, state) => CreateOrderScreen(
              templateId: state.pathParameters['templateId']!,
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
            builder: (_, state) => OrderStatusScreen(
              orderId: state.pathParameters['orderId']!,
            ),
          ),
          GoRoute(
            path: 'agent-earnings',
            builder: (_, __) => const AgentEarningsScreen(),
          ),
        ],
      ),
    ],
  );
});

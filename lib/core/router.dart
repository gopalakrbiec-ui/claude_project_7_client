import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../controllers/locale_controller.dart';
import '../screens/language_select/language_select_screen.dart';
import '../models/template.dart';
import '../screens/login/login_screen.dart';
import '../screens/login/phone_entry_screen.dart';
import '../screens/login/otp_entry_screen.dart';
import '../screens/login/signup_screen.dart';
import '../screens/login/reset_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/template_detail/template_detail_screen.dart';
import '../screens/create_order/create_order_screen.dart';
import '../screens/payment/payment_screen.dart';
import '../screens/order_status/order_status_screen.dart';
import '../screens/agent_earnings/agent_earnings_screen.dart';
import '../screens/topup/topup_screen.dart';
import '../screens/tools/tools_screen.dart';
import '../screens/tool_job_status/tool_job_status_screen.dart';

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
    final authState = _ref.read(authControllerProvider);

    // While auth is still loading, show splash.
    if (authState is AuthInitializing) return '/splash';

    final isAuthenticated = authState is AuthAuthenticated;
    final loc = state.matchedLocation;

    // 1. Not authenticated → login (allow /login/* and /signup and /language-select and /reset-password)
    final onLoginFlow = loc == '/login' || loc.startsWith('/login/');
    final onResetFlow = loc.startsWith('/reset-password');
    if (!isAuthenticated && !onLoginFlow && !onResetFlow &&
        loc != '/language-select' && loc != '/signup') {
      return '/login';
    }

    // 2. Authenticated user hits login → home or signup for new users
    if (onLoginFlow && authState is AuthAuthenticated) {
      return authState.isNewUser ? '/signup' : '/home';
    }

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
    // Handle savinenapu:// deep links by mapping the path/query through as-is.
    // GoRouter treats custom-scheme URIs the same as path navigation.

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
      // Deep link: savinenapu://reset-password?token=TOKEN
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),

      // ── Login flow ───────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'phone',
            builder: (_, __) => const PhoneEntryScreen(),
          ),
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
          GoRoute(
            path: 'tools',
            builder: (_, __) => const ToolsScreen(),
            routes: [
              GoRoute(
                path: 'job/:jobId',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  return ToolJobStatusScreen(
                    jobId: state.pathParameters['jobId']!,
                    toolName: extra['toolName'] as String? ?? 'AI Tool',
                    costDisplay: extra['costDisplay'] as String?,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Splash — shown only during the AuthInitializing window (<1 second).
// ---------------------------------------------------------------------------
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B23), Color(0xFFC21860)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Savi Nenapu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ಸವಿ ನೆನಪು · Sweet memories',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.7),
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

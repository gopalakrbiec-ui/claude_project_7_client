import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../core/token_storage.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

// ---------------------------------------------------------------------------
// Auth state — sealed so the router and UI can exhaustively match.
// ---------------------------------------------------------------------------
sealed class AuthState {
  const AuthState();
}

/// App is checking the stored token against GET /auth/me.
final class AuthInitializing extends AuthState {
  const AuthInitializing();
}

/// No valid token; user must log in.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Token valid and /auth/me returned a profile.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.profile, this.isNewUser = false});
  final UserProfile profile;
  final bool isNewUser;
}

// ---------------------------------------------------------------------------
// Derived role provider
// ---------------------------------------------------------------------------
final isAgentProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthAuthenticated && auth.profile.isAgent;
});

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthInitializing();
  }

  // ── Initialisation ──────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      await _doInit();
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> _doInit() async {
    // Ensure at least one async hop before setting state so Riverpod doesn't
    // overwrite our assignment with build()'s return value.
    await Future<void>.value();
    final storage = ref.read(tokenStorageProvider);
    final token = storage.token;

    if (token == null) {
      state = const AuthUnauthenticated();
      return;
    }

    // Optimistic restore: show the app immediately with the cached role while
    // GET /auth/me runs in the background (avoids spinner on slow networks).
    final cachedRole = storage.role ?? 'user';
    state = AuthAuthenticated(
      profile: UserProfile(id: '', phone: '', role: cachedRole),
    );

    // Background refresh — updates role + profile without blocking the UI.
    try {
      final profile = await ref.read(authRepositoryProvider).getMe();
      await storage.writeRole(profile.role);
      if (state is AuthAuthenticated) {
        state = AuthAuthenticated(profile: profile);
      }
    } on ServerError catch (e) {
      if (e.isUnauthorised) {
        await storage.clear();
        state = const AuthUnauthenticated();
      }
      // Any other server error: keep the optimistic state.
    } catch (_) {
      // NetworkError / unknown: cached state is already showing, do nothing.
    }
  }

  DateTime? _lastRefresh;

  /// Called on app resume (e.g. returning from gallery/camera).
  /// Silently refreshes profile in the background — never clears the session.
  /// Debounced to 10 s so brief backgrounding (image picker) is a no-op.
  Future<void> refresh() async {
    if (state is! AuthAuthenticated) return;
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < const Duration(seconds: 10)) {
      return;
    }
    _lastRefresh = now;
    // Background profile refresh — does not touch auth state on errors.
    try {
      final profile = await ref.read(authRepositoryProvider).getMe();
      final storage = ref.read(tokenStorageProvider);
      await storage.writeRole(profile.role);
      if (state is AuthAuthenticated) {
        state = AuthAuthenticated(profile: profile);
      }
    } on ServerError catch (e) {
      if (e.isUnauthorised) {
        await storage.clear();
        state = const AuthUnauthenticated();
      }
    } catch (_) {
      // Network hiccup on resume — keep the user logged in.
    }
  }

  // ── OTP flow ─────────────────────────────────────────────────────────────

  Future<void> requestOtp(String normalisedPhone) async {
    await ref.read(authRepositoryProvider).requestOtp(normalisedPhone);
  }

  Future<void> verifyOtp(String normalisedPhone, String code) async {
    final result =
        await ref.read(authRepositoryProvider).verifyOtp(normalisedPhone, code);

    final storage = ref.read(tokenStorageProvider);
    await storage.writeToken(result.accessToken);
    await storage.writeRole(result.role);

    final profile = UserProfile(
      id: '',
      phone: normalisedPhone,
      role: result.role,
    );
    state = AuthAuthenticated(profile: profile, isNewUser: result.isNewUser);
  }

  // ── Email / password flow ─────────────────────────────────────────────────

  Future<void> loginWithPassword(
      {required String identifier, required String password}) async {
    final result = await ref
        .read(authRepositoryProvider)
        .loginWithPassword(identifier: identifier, password: password);
    final storage = ref.read(tokenStorageProvider);
    await storage.writeToken(result.accessToken);
    await storage.writeRole(result.role);
    final profile = UserProfile(id: '', phone: identifier, role: result.role);
    state = AuthAuthenticated(profile: profile, isNewUser: result.isNewUser);
  }

  /// Registers a new account. Does NOT authenticate — caller redirects to login.
  Future<void> register({
    required String name,
    required String email,
    required String mobile,
    required String city,
    required String password,
  }) async {
    await ref.read(authRepositoryProvider).register(
          name: name,
          email: email,
          mobile: mobile,
          city: city,
          password: password,
        );
    final storage = ref.read(tokenStorageProvider);
    await storage.writeRegistration(
        name: name, email: email, mobile: mobile, city: city);
  }

  // ── Session termination ───────────────────────────────────────────────────

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AuthUnauthenticated();
  }

  void forceLogout() => state = const AuthUnauthenticated();
}

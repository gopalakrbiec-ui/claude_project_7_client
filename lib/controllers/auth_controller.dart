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
  /// Set on the first login after OTP verify; cleared on subsequent launches.
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

  // ── Initialisation (every app launch / resume) ──────────────────────────

  Future<void> _init() async {
    try {
      await _doInit();
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> _doInit() async {
    // Ensure at least one async hop before setting state. If _doInit() completes
    // synchronously (e.g. token == null path has no awaits), Riverpod overwrites
    // our state assignment with build()'s return value (AuthInitializing).
    await Future<void>.value();
    final storage = ref.read(tokenStorageProvider);
    final token = storage.token;

    if (token == null) {
      state = const AuthUnauthenticated();
      return;
    }

    // Optimistic restore: immediately show the app with the cached role while
    // GET /auth/me runs in the background. This prevents the splash from
    // spinning for up to 30 s on slow networks or a cold Railway start.
    final cachedRole = storage.role ?? 'user';
    state = AuthAuthenticated(
      profile: UserProfile(id: '', phone: '', role: cachedRole),
    );

    // Background refresh — updates role and profile without blocking the UI.
    try {
      final profile = await ref.read(authRepositoryProvider).getMe();
      await storage.writeRole(profile.role);
      // Only update state if we're still authenticated (user didn't log out).
      if (state is AuthAuthenticated) {
        state = AuthAuthenticated(profile: profile);
      }
    } on ServerError catch (e) {
      if (e.isUnauthorised) {
        await storage.clear();
        state = const AuthUnauthenticated();
      }
      // Any other server error: keep the optimistic state already set.
    } catch (_) {
      // NetworkError or unknown: cached state is already showing, do nothing.
    }
  }

  DateTime? _lastRefresh;

  /// Re-runs initialisation — call from AppLifecycleListener on resume.
  /// Debounced to 10 s so opening the image picker (which briefly backgrounds
  /// the app) doesn't trigger a redundant /auth/me call.
  Future<void> refresh() {
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!) < const Duration(seconds: 10)) {
      return Future.value();
    }
    _lastRefresh = now;
    return _init();
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
    final profile = UserProfile(id: '', phone: '', role: result.role);
    state = AuthAuthenticated(profile: profile, isNewUser: result.isNewUser);
  }

  Future<void> register({
    required String name,
    required String email,
    required String mobile,
    required String city,
    required String password,
  }) async {
    final result = await ref.read(authRepositoryProvider).register(
          name: name,
          email: email,
          mobile: mobile,
          city: city,
          password: password,
        );
    final storage = ref.read(tokenStorageProvider);
    await storage.writeToken(result.accessToken);
    await storage.writeRole(result.role);
    final profile = UserProfile(id: '', phone: mobile, role: result.role);
    state = AuthAuthenticated(profile: profile, isNewUser: true);
  }

  // ── Social auth ───────────────────────────────────────────────────────────

  Future<bool> loginWithGoogle() async {
    final result = await ref.read(authRepositoryProvider).loginWithGoogle();
    if (result == null) return false; // user cancelled
    final storage = ref.read(tokenStorageProvider);
    await storage.writeToken(result.accessToken);
    await storage.writeRole(result.role);
    final profile = UserProfile(id: '', phone: '', role: result.role);
    state = AuthAuthenticated(profile: profile, isNewUser: result.isNewUser);
    return true;
  }

  Future<bool> loginWithFacebook() async {
    final result = await ref.read(authRepositoryProvider).loginWithFacebook();
    if (result == null) return false; // user cancelled
    final storage = ref.read(tokenStorageProvider);
    await storage.writeToken(result.accessToken);
    await storage.writeRole(result.role);
    final profile = UserProfile(id: '', phone: '', role: result.role);
    state = AuthAuthenticated(profile: profile, isNewUser: result.isNewUser);
    return true;
  }

  // ── Session termination ───────────────────────────────────────────────────

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AuthUnauthenticated();
  }

  void forceLogout() => state = const AuthUnauthenticated();
}

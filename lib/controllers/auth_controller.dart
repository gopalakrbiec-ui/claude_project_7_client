import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_error.dart';
import '../core/constants.dart';
import '../models/user_profile.dart';

import '../repositories/auth_repository.dart';

// ---------------------------------------------------------------------------
// Shared secure-storage instance — override in tests via ProviderContainer.
// ---------------------------------------------------------------------------
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

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
// Single reactive bool watched by all role-gated widgets and the router.
// Updates automatically whenever /auth/me refreshes the profile (launch,
// resume, or manual refresh), so role changes propagate without navigation.
//
// Why not read role from secure storage directly in widgets?
// Secure storage is async; this derived Provider is synchronous and
// composable — the router and every widget get the same consistent value
// with no await/FutureBuilder.
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
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: kTokenKey);

    if (token == null) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      // CLAUDE.md contract rule: call GET /auth/me on every launch/resume to
      // refresh role + profile; never trust only the locally stored role.
      final profile = await ref.read(authRepositoryProvider).getMe();
      await storage.write(key: kRoleKey, value: profile.role);
      state = AuthAuthenticated(profile: profile);
    } on ServerError catch (e) {
      if (e.isUnauthorised) {
        await _clearCredentials(storage);
        state = const AuthUnauthenticated();
        return;
      }
      // Non-401 server error — fall through to stale-data path below.
      final storedRole = await storage.read(key: kRoleKey) ?? 'user';
      state = AuthAuthenticated(
        profile: UserProfile(id: '', phone: '', role: storedRole),
      );
    } on NetworkError {
      // Network error on startup — keep user logged in with stale role.
      // The stored role is a fallback until the next successful /auth/me.
      final storedRole = await storage.read(key: kRoleKey) ?? 'user';
      state = AuthAuthenticated(
        profile: UserProfile(id: '', phone: '', role: storedRole),
      );
    } catch (_) {
      await _clearCredentials(storage);
      state = const AuthUnauthenticated();
    }
  }

  /// Re-runs initialisation — call from AppLifecycleListener on resume.
  Future<void> refresh() => _init();

  // ── OTP flow ─────────────────────────────────────────────────────────────

  /// Throws [ApiError] on failure; callers handle errors and show UI feedback.
  Future<void> requestOtp(String normalisedPhone) async {
    await ref.read(authRepositoryProvider).requestOtp(normalisedPhone);
  }

  /// On success: stores token + role, transitions to [AuthAuthenticated].
  /// Throws [ApiError] on failure (wrong code, expired, too many attempts).
  Future<void> verifyOtp(String normalisedPhone, String code) async {
    final result =
        await ref.read(authRepositoryProvider).verifyOtp(normalisedPhone, code);

    final storage = ref.read(secureStorageProvider);
    await storage.write(key: kTokenKey, value: result.accessToken);
    await storage.write(key: kRoleKey, value: result.role);

    final profile = UserProfile(
      // Profile fields are filled in from the next /auth/me call (on next
      // launch), but we have enough for role-gating right now.
      id: '',
      phone: normalisedPhone,
      role: result.role,
    );
    state = AuthAuthenticated(profile: profile, isNewUser: result.isNewUser);
  }

  // ── Session termination ───────────────────────────────────────────────────

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await _clearCredentials(storage);
    state = const AuthUnauthenticated();
  }

  /// Called by the JWT interceptor when a 401 is received mid-session.
  void forceLogout() => state = const AuthUnauthenticated();

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _clearCredentials(FlutterSecureStorage storage) async {
    await Future.wait([
      storage.delete(key: kTokenKey),
      storage.delete(key: kRoleKey),
    ]);
  }
}

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
    final storage = ref.read(tokenStorageProvider);
    // Synchronous read — never hangs, no Keystore involved.
    final token = storage.token;

    if (token == null) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      // CLAUDE.md contract: call GET /auth/me on every launch/resume.
      final profile = await ref.read(authRepositoryProvider).getMe();
      await storage.writeRole(profile.role);
      state = AuthAuthenticated(profile: profile);
    } on ServerError catch (e) {
      if (e.isUnauthorised) {
        await storage.clear();
        state = const AuthUnauthenticated();
        return;
      }
      final storedRole = storage.role ?? 'user';
      state = AuthAuthenticated(
        profile: UserProfile(id: '', phone: '', role: storedRole),
      );
    } on NetworkError {
      final storedRole = storage.role ?? 'user';
      state = AuthAuthenticated(
        profile: UserProfile(id: '', phone: '', role: storedRole),
      );
    } catch (_) {
      final storedRole = storage.role ?? 'user';
      state = AuthAuthenticated(
        profile: UserProfile(id: '', phone: '', role: storedRole),
      );
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

  // ── Session termination ───────────────────────────────────────────────────

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AuthUnauthenticated();
  }

  void forceLogout() => state = const AuthUnauthenticated();
}

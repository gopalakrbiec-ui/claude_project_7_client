import 'dart:async';

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
    await Future<void>.value();
    final storage = ref.read(tokenStorageProvider);

    // Always require re-login on cold start (app killed / closed).
    // The token is cleared so the user must authenticate every session.
    await storage.clearToken();
    state = const AuthUnauthenticated();
  }

  static const _inactivityDuration = Duration(minutes: 10);
  Timer? _inactivityTimer;

  /// Reset the 10-minute inactivity timer. Call on any user interaction.
  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (state is! AuthAuthenticated) return;
    _inactivityTimer = Timer(_inactivityDuration, logout);
  }

  /// Re-runs on app resume — clears session so user must re-authenticate.
  Future<void> refresh() {
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
    resetInactivityTimer();
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
    resetInactivityTimer();
  }

  /// Registers a new account. Does NOT authenticate — caller must redirect to login.
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
    // State stays unauthenticated — user must log in after registration.
  }

  // ── Session termination ───────────────────────────────────────────────────

  Future<void> logout() async {
    _inactivityTimer?.cancel();
    await ref.read(tokenStorageProvider).clearToken();
    state = const AuthUnauthenticated();
  }

  void forceLogout() {
    _inactivityTimer?.cancel();
    state = const AuthUnauthenticated();
  }
}

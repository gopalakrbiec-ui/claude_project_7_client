import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../repositories/auth_repository.dart';

// ---------------------------------------------------------------------------
// Shared storage instance
// ---------------------------------------------------------------------------
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

// ---------------------------------------------------------------------------
// Auth state: null = logged out, non-null = role string ("user" | "agent")
// ---------------------------------------------------------------------------
final authControllerProvider =
    AsyncNotifierProvider<AuthController, String?>(AuthController.new);

class AuthController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    // On every app start, read the stored role.
    // GET /auth/me is called here to refresh role + profile per CLAUDE.md rule.
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: kTokenKey);
    if (token == null) return null;

    try {
      final role = await ref.read(authRepositoryProvider).getMe();
      await storage.write(key: kRoleKey, value: role);
      return role;
    } catch (_) {
      // Token may be expired; clear and require re-login.
      await storage.delete(key: kTokenKey);
      await storage.delete(key: kRoleKey);
      return null;
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendOtp(phoneNumber),
    );
  }

  Future<void> verifyOtp(String phoneNumber, String otp) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final result = await repo.verifyOtp(phoneNumber, otp);
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: kTokenKey, value: result.token);
      await storage.write(key: kRoleKey, value: result.role);
      return result.role;
    });
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: kTokenKey);
    await storage.delete(key: kRoleKey);
    state = const AsyncData(null);
  }

  // Called by the JWT interceptor's 401 handler.
  void forceLogout() {
    state = const AsyncData(null);
  }
}

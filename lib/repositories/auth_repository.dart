import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';

// ---------------------------------------------------------------------------
// Result type returned after a successful OTP verify
// ---------------------------------------------------------------------------
class AuthResult {
  const AuthResult({required this.token, required this.role});
  final String token;
  final String role;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = DioClient.create(
    storage,
    // 401 → tell the controller to force-logout (no circular dep: read, not watch)
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return AuthRepository(dio);
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------
// INTEGRATION NOTE: After `make gen-api`, replace raw Dio calls below with
// the generated AuthApi class:
//   import '../api/generated/lib/src/api/auth_api.dart';
//   final _api = AuthApi(dio);
//   await _api.sendOtp(OtpSendRequest(phoneNumber: phoneNumber));
// ---------------------------------------------------------------------------
class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  /// Returns null; throws [ApiError] on failure.
  Future<void> sendOtp(String phoneNumber) async {
    try {
      await _dio.post<void>(
        '/auth/otp/send',
        data: {'phone_number': phoneNumber},
      );
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// Returns [AuthResult] on success; throws [ApiError] on failure.
  Future<AuthResult> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'phone_number': phoneNumber, 'otp': otp},
      );
      final data = response.data!;
      return AuthResult(
        token: data['access_token'] as String,
        role: data['role'] as String,
      );
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// Refreshes role + profile. Call on every app launch/resume per CLAUDE.md.
  /// Returns the role string ("user" | "agent").
  Future<String> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return response.data!['role'] as String;
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}

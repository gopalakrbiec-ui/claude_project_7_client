import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../models/user_profile.dart';
import '../models/verify_otp_result.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return AuthRepository(dio);
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------
// INTEGRATION NOTE: After `make gen-api`, replace the raw Dio calls with the
// generated AuthApi class from lib/api/generated/lib/src/api/auth_api.dart.
// The method signatures here are intentionally kept thin so the swap is
// mechanical — only the repository changes, not callers.
// ---------------------------------------------------------------------------
class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  /// POST /auth/request-otp — throws [ApiError] on failure.
  Future<void> requestOtp(String phone) async {
    try {
      await _dio.post<void>(
        '/auth/request-otp',
        data: {'phone': phone},
      );
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// POST /auth/verify-otp — returns [VerifyOtpResult]; throws [ApiError].
  ///
  /// Error taxonomy from the backend:
  ///   400 → wrong / malformed code
  ///   401 → OTP expired
  ///   429 → too many attempts
  Future<VerifyOtpResult> verifyOtp(String phone, String code) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/verify-otp',
        data: {'phone': phone, 'code': code},
      );
      return VerifyOtpResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// GET /auth/me — returns [UserProfile]; throws [ApiError].
  /// Call on every app launch and resume (CLAUDE.md contract rule).
  Future<UserProfile> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return UserProfile.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}

/// Mirror of the POST /auth/verify-otp response schema.
/// Replace with generated model once `make gen-api` has run.
class VerifyOtpResult {
  const VerifyOtpResult({
    required this.accessToken,
    required this.tokenType,
    required this.role,
    required this.isNewUser,
  });

  final String accessToken;
  final String tokenType;
  final String role; // "user" | "agent"
  final bool isNewUser;

  factory VerifyOtpResult.fromJson(Map<String, dynamic> json) =>
      VerifyOtpResult(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
        role: json['role'] as String,
        isNewUser: json['is_new_user'] as bool? ?? false,
      );
}

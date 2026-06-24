/// Mirror of the GET /auth/me response schema.
/// Replace with the generated model once `make gen-api` has run and
/// UserProfile is available from lib/api/generated/.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.preferredLanguage,
  });

  final String id;
  final String phone;
  final String role; // "user" | "agent"
  final String? name;
  final String? preferredLanguage;

  bool get isAgent => role == 'agent';

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        phone: json['phone'] as String,
        role: json['role'] as String,
        name: json['name'] as String?,
        preferredLanguage: json['preferred_language'] as String?,
      );

  UserProfile copyWith({
    String? id,
    String? phone,
    String? role,
    String? name,
    String? preferredLanguage,
  }) =>
      UserProfile(
        id: id ?? this.id,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        name: name ?? this.name,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      );
}

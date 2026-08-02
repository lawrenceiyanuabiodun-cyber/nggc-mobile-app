/// ─────────────────────────────────────────────────────────
/// UserModel
/// Represents a logged-in user
/// Maps to backend /auth/me response
/// ─────────────────────────────────────────────────────────
class UserModel {
  final String id;
  final String firstName;
  final String? lastName;
  final String phone;
  final String role; // 'admin' | 'user'
  final String? profileImageUrl;
  final String? preferredLanguage; // 'english' | 'yoruba'
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.firstName,
    this.lastName,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.preferredLanguage,
    this.createdAt,
  });

  /// Full display name
  String get fullName {
    if (lastName == null || lastName!.isEmpty) return firstName;
    return '$firstName $lastName';
  }

  /// Is admin?
  bool get isAdmin => role.toLowerCase() == 'admin';

  /// First letter for avatar fallback
  String get initial {
    if (firstName.isEmpty) return '?';
    return firstName[0].toUpperCase();
  }

  /// ── From JSON ─────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ??
          json['firstName']?.toString() ??
          '',
      lastName: json['last_name']?.toString() ?? json['lastName']?.toString(),
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      profileImageUrl: json['profile_image_url']?.toString() ??
          json['profileImageUrl']?.toString(),
      preferredLanguage: json['preferred_language']?.toString() ??
          json['preferredLanguage']?.toString(),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  /// ── To JSON ───────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'role': role,
      'profile_image_url': profileImageUrl,
      'preferred_language': preferredLanguage,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// ── Copy With ─────────────────────────────────────────
  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    String? profileImageUrl,
    String? preferredLanguage,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// ── Helper: Parse Date ────────────────────────────────
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

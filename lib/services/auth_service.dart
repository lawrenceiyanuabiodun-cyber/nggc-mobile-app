import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// ─────────────────────────────────────────────────────────
/// AuthService
/// Handles login, register, logout, and current user session
/// ─────────────────────────────────────────────────────────
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();

  /// ── Login ─────────────────────────────────────────────
  static Future<AuthResult> login({
    required String firstName,
    required String phone,
    required String pin,
  }) async {
    final response = await ApiService.post(
      '/auth/login',
      body: {
        'first_name': firstName.trim(),
        'phone': phone.trim(),
        'pin': pin.trim(),
      },
      requireAuth: false,
    );

    if (response.isError) {
      return AuthResult.failure(response.error ?? 'Login failed');
    }

    final data = response.asMap;
    if (data == null) {
      return AuthResult.failure('Invalid response from server');
    }

    final token = data['access_token']?.toString() ??
        data['token']?.toString();

    if (token == null || token.isEmpty) {
      return AuthResult.failure('No token received from server');
    }

    await ApiService.saveToken(token);

    UserModel? user;
    if (data['user'] is Map) {
      user = UserModel.fromJson(Map<String, dynamic>.from(data['user']));
    } else {
      final meResponse = await ApiService.get('/auth/me');
      if (meResponse.isSuccess && meResponse.asMap != null) {
        user = UserModel.fromJson(meResponse.asMap!);
      }
    }

    if (user == null) {
      return AuthResult.failure('Could not load user profile');
    }

    await _saveUser(user);
    return AuthResult.success(user);
  }

  /// ── Register ──────────────────────────────────────────
  static Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String pin,
  }) async {
    final response = await ApiService.post(
      '/auth/register',
      body: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'pin': pin.trim(),
      },
      requireAuth: false,
    );

    if (response.isError) {
      return AuthResult.failure(response.error ?? 'Registration failed');
    }

    return await login(firstName: firstName, phone: phone, pin: pin);
  }

  /// ── Logout ────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout');
    } catch (_) {}

    await ApiService.clearToken();
    await _clearUser();
  }

  /// ── Get Current User (from local storage) ─────────────
  static Future<UserModel?> getCurrentUser() async {
    final userJson = await _storage.read(key: AppConfig.userStorageKey);
    if (userJson == null || userJson.isEmpty) return null;

    try {
      final map = json.decode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// ── Refresh Current User from API ─────────────────────
  static Future<UserModel?> refreshCurrentUser() async {
    final response = await ApiService.get('/auth/me');
    if (response.isError || response.asMap == null) return null;

    final user = UserModel.fromJson(response.asMap!);
    await _saveUser(user);
    return user;
  }

  /// ── Check if User is Logged In ────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await ApiService.getToken();
    return token != null && token.isNotEmpty;
  }

  /// ── Save User to Secure Storage ───────────────────────
  static Future<void> _saveUser(UserModel user) async {
    final userJson = json.encode(user.toJson());
    await _storage.write(key: AppConfig.userStorageKey, value: userJson);
  }

  /// ── Clear User from Secure Storage ────────────────────
  static Future<void> _clearUser() async {
    await _storage.delete(key: AppConfig.userStorageKey);
  }
}

/// ─────────────────────────────────────────────────────────
/// AuthResult
/// Wrapper for auth operations
/// ─────────────────────────────────────────────────────────
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? error;

  AuthResult._({required this.success, this.user, this.error});

  factory AuthResult.success(UserModel user) {
    return AuthResult._(success: true, user: user);
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(success: false, error: error);
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// AuthService
/// Handles login, register, logout, and current user session.
///
/// WEB: Session auto-expires at midnight Africa/Lagos (UTC+1) time.
///      User must log in again the next day.
/// MOBILE: Session persists forever until manual logout.
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();

  // Storage key for the daily expiry timestamp (web only)
  static const _expiryStorageKey = 'nggc_token_expires_at_utc_ms';

  // ---------------------------------------------------------------
  // WEB-ONLY: Daily Session Expiry Helpers
  // ---------------------------------------------------------------

  /// Calculates the next midnight in Africa/Lagos (UTC+1, no DST).
  /// Returns the UTC timestamp in milliseconds.
  ///
  /// Example: if current Lagos time is 2026-08-12 14:30,
  ///          returns UTC timestamp for 2026-08-13 00:00 Lagos time
  ///          which is 2026-08-12 23:00 UTC.
  static int _calculateNextMidnightLagosUtcMs() {
    // Nigeria is UTC+1 with NO daylight saving time
    const lagosOffsetHours = 1;

    // Current UTC time
    final nowUtc = DateTime.now().toUtc();

    // Convert to Lagos time (UTC+1)
    final nowLagos = nowUtc.add(const Duration(hours: lagosOffsetHours));

    // Get tomorrow's date in Lagos
    final tomorrowLagos = DateTime(
      nowLagos.year,
      nowLagos.month,
      nowLagos.day,
    ).add(const Duration(days: 1));

    // Midnight in Lagos = tomorrow at 00:00 Lagos time
    // Convert back to UTC by subtracting 1 hour
    final midnightLagosAsUtc = tomorrowLagos
        .subtract(const Duration(hours: lagosOffsetHours));

    return midnightLagosAsUtc.millisecondsSinceEpoch;
  }

  /// Save the session expiry timestamp (web only, no-op on mobile).
  static Future<void> _saveExpiry() async {
    if (!kIsWeb) return;
    final expiryMs = _calculateNextMidnightLagosUtcMs();
    await _storage.write(
      key: _expiryStorageKey,
      value: expiryMs.toString(),
    );
  }

  /// Clear the session expiry timestamp.
  static Future<void> _clearExpiry() async {
    await _storage.delete(key: _expiryStorageKey);
  }

  /// Check if the session has expired (web only).
  /// Returns true if expired, false if still valid or on mobile.
  static Future<bool> _isSessionExpired() async {
    if (!kIsWeb) return false;

    final expiryStr = await _storage.read(key: _expiryStorageKey);
    if (expiryStr == null || expiryStr.isEmpty) {
      // No expiry saved yet - treat as expired to force fresh login
      return true;
    }

    final expiryMs = int.tryParse(expiryStr);
    if (expiryMs == null) return true;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    return nowMs >= expiryMs;
  }

  // ---------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------
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

    // WEB: Set session to expire at midnight Africa/Lagos time
    await _saveExpiry();

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

  // ---------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------
  static Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout');
    } catch (_) {}

    await ApiService.clearToken();
    await _clearUser();
    await _clearExpiry();
  }

  // ---------------------------------------------------------------
  // Get Current User (from local storage)
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // Refresh Current User from API
  // ---------------------------------------------------------------
  static Future<UserModel?> refreshCurrentUser() async {
    final response = await ApiService.get('/auth/me');
    if (response.isError || response.asMap == null) return null;

    final user = UserModel.fromJson(response.asMap!);
    await _saveUser(user);
    return user;
  }

  // ---------------------------------------------------------------
  // Check if User is Logged In
  // WEB: Also verifies session has not expired (past midnight Lagos)
  // MOBILE: Only checks token exists
  // ---------------------------------------------------------------
  static Future<bool> isLoggedIn() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return false;

    // WEB-ONLY: Enforce daily expiry
    if (kIsWeb) {
      final expired = await _isSessionExpired();
      if (expired) {
        // Auto-logout: session has passed midnight Africa/Lagos
        await ApiService.clearToken();
        await _clearUser();
        await _clearExpiry();
        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------
  // Save User to Secure Storage
  // ---------------------------------------------------------------
  static Future<void> _saveUser(UserModel user) async {
    final userJson = json.encode(user.toJson());
    await _storage.write(key: AppConfig.userStorageKey, value: userJson);
  }

  // ---------------------------------------------------------------
  // Clear User from Secure Storage
  // ---------------------------------------------------------------
  static Future<void> _clearUser() async {
    await _storage.delete(key: AppConfig.userStorageKey);
  }
}

/// AuthResult
/// Wrapper for auth operations
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

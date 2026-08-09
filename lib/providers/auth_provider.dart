import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

// ─────────────────────────────────────────────────────────
// Auth State
// Represents the full authentication state of the app
// ─────────────────────────────────────────────────────────
enum AuthStatus {
  unknown,      // App just launched — checking storage
  authenticated, // User is logged in
  unauthenticated, // User is not logged in
  loading,      // Login/logout in progress
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  // Initial state — app just launched
  const AuthState.unknown()
      : status = AuthStatus.unknown,
        user = null,
        errorMessage = null;

  // Checking / logging in / logging out
  AuthState copyWithLoading() {
    return AuthState(
      status: AuthStatus.loading,
      user: user,
      errorMessage: null,
    );
  }

  // Logged in successfully
  AuthState copyWithUser(UserModel user) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      errorMessage: null,
    );
  }

  // Logged out or not logged in
  AuthState copyWithLoggedOut() {
    return const AuthState(
      status: AuthStatus.unauthenticated,
      user: null,
      errorMessage: null,
    );
  }

  // Error during login
  AuthState copyWithError(String error) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      user: null,
      errorMessage: error,
    );
  }

  // Helpers
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isUnknown => status == AuthStatus.unknown;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

// ─────────────────────────────────────────────────────────
// Auth Notifier
// Controls login, logout, and session restoration
// ─────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.unknown()) {
    // Automatically check login on app start
    _restoreSession();
  }

  // ── Restore session on app launch ─────────────────────
  Future<void> _restoreSession() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        state = state.copyWithLoggedOut();
        return;
      }

      // Try loading from local storage first (fast)
      UserModel? user = await AuthService.getCurrentUser();

      if (user != null) {
        state = state.copyWithUser(user);
        // Silently refresh from API in background
        _silentRefresh();
        // Register FCM token in background (in case not registered yet)
        _registerFcmTokenSilently();
      } else {
        // No local user — try fetching from API
        user = await AuthService.refreshCurrentUser();
        if (user != null) {
          state = state.copyWithUser(user);
          _registerFcmTokenSilently();
        } else {
          state = state.copyWithLoggedOut();
        }
      }
    } catch (_) {
      state = state.copyWithLoggedOut();
    }
  }

  // ── Silent background refresh ──────────────────────────
  Future<void> _silentRefresh() async {
    try {
      final user = await AuthService.refreshCurrentUser();
      if (user != null && mounted) {
        state = state.copyWithUser(user);
      }
    } catch (_) {
      // Silent — do not change state on background error
    }
  }

  // ── Register FCM token silently (background, non-blocking) ──
  Future<void> _registerFcmTokenSilently({bool forceReRegister = false}) async {
    try {
      final jwt = await ApiService.getToken();
      if (jwt == null || jwt.isEmpty) return;

      // Small delay to let FCM service finish initializing
      await Future.delayed(const Duration(seconds: 2));

      await FcmService.registerTokenWithBackend(
        jwt: jwt,
        forceReRegister: forceReRegister,
      );
    } catch (_) {
      // Silent fail — user experience is not affected
    }
  }

  // ── Login ──────────────────────────────────────────────
  Future<bool> login({
    required String firstName,
    required String phone,
    required String pin,
  }) async {
    state = state.copyWithLoading();

    final result = await AuthService.login(
      firstName: firstName,
      phone: phone,
      pin: pin,
    );

    if (result.success && result.user != null) {
      state = state.copyWithUser(result.user!);
      // Register FCM token with backend (fire-and-forget)
      _registerFcmTokenSilently(forceReRegister: true);
      return true;
    } else {
      state = state.copyWithError(result.error ?? 'Login failed');
      return false;
    }
  }

  // ── Register ───────────────────────────────────────────
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String pin,
  }) async {
    state = state.copyWithLoading();

    final result = await AuthService.register(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      pin: pin,
    );

    if (result.success && result.user != null) {
      state = state.copyWithUser(result.user!);
      // Register FCM token with backend (fire-and-forget)
      _registerFcmTokenSilently(forceReRegister: true);
      return true;
    } else {
      state = state.copyWithError(result.error ?? 'Registration failed');
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    state = state.copyWithLoading();
    // Reset FCM registration so next login re-registers
    await FcmService.resetRegistration();
    await AuthService.logout();
    state = state.copyWithLoggedOut();
  }

  // ── Clear Error ────────────────────────────────────────
  void clearError() {
    if (state.hasError) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        user: state.user,
        errorMessage: null,
      );
    }
  }

  // ── Refresh user manually (e.g. after profile update) ──
  Future<void> refreshUser() async {
    await _silentRefresh();
  }
}

// ─────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────

/// Main auth provider — use this everywhere
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Convenience: just the current user (nullable)
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

/// Convenience: is user authenticated?
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Convenience: is auth loading?
final isAuthLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});
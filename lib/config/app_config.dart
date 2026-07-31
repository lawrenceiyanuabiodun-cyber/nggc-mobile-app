/// Central configuration for the NGGC app
/// All environment-specific values live here
class AppConfig {
  AppConfig._(); // prevent instantiation

  // ── App Identity ──────────────────────────────────────────
  static const String appDisplayName = 'NGGC';
  static const String appFullName = 'New Generation Gospel Church';
  static const String appTagline = 'Sunday School';
  static const String packageName = 'com.nggc.nggc';
  static const String appVersion = '1.0.0';

  // ── Backend API ───────────────────────────────────────────
  /// Development — local FastAPI server
  /// 10.0.2.2 is the Android emulator's alias for localhost
  static const String _devBaseUrl = 'http://10.0.2.2:8000';

  /// Production — update this before APK release
  static const String _prodBaseUrl = 'https://your-production-domain.com';

  /// Toggle this to switch environments
  static const bool isProduction = false;

  static String get baseUrl => isProduction ? _prodBaseUrl : _devBaseUrl;
  static String get apiUrl => '$baseUrl/api';

  // ── Auth ──────────────────────────────────────────────────
  static const String tokenStorageKey = 'nggc_auth_token';
  static const String userStorageKey = 'nggc_user_data';
  static const String deviceIdKey = 'nggc_device_id';

  // ── Hive Box Names ────────────────────────────────────────
  static const String bibleBoxName = 'bible_cache';
  static const String lessonsBoxName = 'lessons_cache';
  static const String notesBoxName = 'user_notes';
  static const String favoritesBoxName = 'user_favorites';
  static const String progressBoxName = 'user_progress';
  static const String settingsBoxName = 'app_settings';
  static const String verseBoxName = 'verse_cache';

  // ── Timeouts ──────────────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration cacheExpiry = Duration(hours: 24);

  // ── Pagination ────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int biblePageSize = 50;
}
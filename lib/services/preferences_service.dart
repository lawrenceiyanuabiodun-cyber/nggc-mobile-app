import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
// PreferencesService
// Stores user preferences locally
// - Preferred Bible language
// - Theme mode (light/dark/system)
// - Font size preference
// ─────────────────────────────────────────────────────────
class PreferencesService {
  PreferencesService._();

  // ── Keys ──────────────────────────────────────────────
  static const String _bibleLanguageKey = 'preferred_bible_language';
  static const String _themeModeKey = 'preferred_theme_mode';
  static const String _fontSizeKey = 'preferred_font_size';

  // ─────────────────────────────────────────────────────
  // Bible Language
  // ─────────────────────────────────────────────────────

  /// Get preferred Bible language (default: english)
  static Future<String> getBibleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bibleLanguageKey) ?? 'english';
  }

  /// Save preferred Bible language
  static Future<void> setBibleLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bibleLanguageKey, language);
  }

  // ─────────────────────────────────────────────────────
  // Theme Mode
  // ─────────────────────────────────────────────────────

  /// Get preferred theme: 'light' | 'dark' | 'system'
  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  /// Save preferred theme mode
  static Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }

  // ─────────────────────────────────────────────────────
  // Font Size
  // ─────────────────────────────────────────────────────

  /// Get preferred font size (default: 16.0)
  static Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey) ?? 16.0;
  }

  /// Save preferred font size
  static Future<void> setFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
  }
}

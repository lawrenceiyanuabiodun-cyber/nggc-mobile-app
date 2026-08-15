import 'package:shared_preferences/shared_preferences.dart';

/// Tracks locally which notifications the user has read.
/// Uses SharedPreferences (no backend needed).
class UnreadTracker {
  UnreadTracker._();

  static const _kSeenVerseDate     = 'unread_seen_verse_date';
  static const _kSeenReadingDate   = 'unread_seen_reading_date';
  static const _kReadAnnouncements = 'unread_read_announcements';
  static const _kViewedSermons     = 'unread_viewed_sermons';

  static String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // ---------- DAILY VERSE ----------
  static Future<bool> isVerseUnread() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getString(_kSeenVerseDate);
    return seen != _todayKey();
  }

  static Future<void> markVerseSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSeenVerseDate, _todayKey());
  }

  // ---------- DAILY READING ----------
  static Future<bool> isReadingUnread() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getString(_kSeenReadingDate);
    return seen != _todayKey();
  }

  static Future<void> markReadingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSeenReadingDate, _todayKey());
  }

  // ---------- ANNOUNCEMENTS ----------
  static Future<List<String>> _getReadAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kReadAnnouncements) ?? [];
  }

  static Future<bool> isAnnouncementUnread(String id) async {
    final list = await _getReadAnnouncements();
    return !list.contains(id);
  }

  static Future<void> markAnnouncementRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _getReadAnnouncements();
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_kReadAnnouncements, list);
    }
  }

  // ---------- SERMONS ----------
  static Future<List<String>> _getViewedSermons() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kViewedSermons) ?? [];
  }

  static Future<bool> isSermonUnread(String id) async {
    final list = await _getViewedSermons();
    return !list.contains(id);
  }

  static Future<void> markSermonViewed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _getViewedSermons();
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_kViewedSermons, list);
    }
  }
}

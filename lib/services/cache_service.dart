import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';

// ─────────────────────────────────────────────────────────
// CacheService
// Caches API responses in Hive for offline access
// Keys: lessons, announcements, events, today_lesson
// Expiry: 24 hours (configurable in AppConfig)
// ─────────────────────────────────────────────────────────
class CacheService {
  CacheService._();

  // ── Box names ──────────────────────────────────────────
  static const String _lessonsKey = 'cached_lessons';
  static const String _announcementsKey = 'cached_announcements';
  static const String _eventsKey = 'cached_events';
  static const String _todayLessonKey = 'cached_today_lesson';
  static const String _timestampSuffix = '_timestamp';

  // ── Open settings box ──────────────────────────────────
  static Box get _box => Hive.box(AppConfig.settingsBoxName);

  // ─────────────────────────────────────────────────────
  // SAVE methods
  // ─────────────────────────────────────────────────────

  /// Cache lessons list
  static Future<void> saveLessons(List<dynamic> lessons) async {
    await _save(_lessonsKey, lessons);
  }

  /// Cache announcements list
  static Future<void> saveAnnouncements(List<dynamic> announcements) async {
    await _save(_announcementsKey, announcements);
  }

  /// Cache events list
  static Future<void> saveEvents(List<dynamic> events) async {
    await _save(_eventsKey, events);
  }

  /// Cache today lesson
  static Future<void> saveTodayLesson(Map<String, dynamic> lesson) async {
    await _save(_todayLessonKey, lesson);
  }

  // ─────────────────────────────────────────────────────
  // GET methods
  // ─────────────────────────────────────────────────────

  /// Get cached lessons
  static List<dynamic>? getLessons() {
    final data = _get(_lessonsKey);
    if (data is List) return data;
    return null;
  }

  /// Get cached announcements
  static List<dynamic>? getAnnouncements() {
    final data = _get(_announcementsKey);
    if (data is List) return data;
    return null;
  }

  /// Get cached events
  static List<dynamic>? getEvents() {
    final data = _get(_eventsKey);
    if (data is List) return data;
    return null;
  }

  /// Get cached today lesson
  static Map<String, dynamic>? getTodayLesson() {
    final data = _get(_todayLessonKey);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  // ─────────────────────────────────────────────────────
  // EXPIRY checks
  // ─────────────────────────────────────────────────────

  static bool isLessonsExpired() => _isExpired(_lessonsKey);
  static bool isAnnouncementsExpired() => _isExpired(_announcementsKey);
  static bool isEventsExpired() => _isExpired(_eventsKey);
  static bool isTodayLessonExpired() => _isExpired(_todayLessonKey);

  // ─────────────────────────────────────────────────────
  // CLEAR methods
  // ─────────────────────────────────────────────────────

  static Future<void> clearLessons() async {
    await _box.delete(_lessonsKey);
    await _box.delete('$_lessonsKey$_timestampSuffix');
  }

  static Future<void> clearAll() async {
    await _box.delete(_lessonsKey);
    await _box.delete(_announcementsKey);
    await _box.delete(_eventsKey);
    await _box.delete(_todayLessonKey);
    await _box.delete('$_lessonsKey$_timestampSuffix');
    await _box.delete('$_announcementsKey$_timestampSuffix');
    await _box.delete('$_eventsKey$_timestampSuffix');
    await _box.delete('$_todayLessonKey$_timestampSuffix');
  }

  // ─────────────────────────────────────────────────────
  // PRIVATE helpers
  // ─────────────────────────────────────────────────────

  static Future<void> _save(String key, dynamic data) async {
    try {
      final encoded = json.encode(data);
      await _box.put(key, encoded);
      await _box.put(
        '$key$_timestampSuffix',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Cache failure should never crash the app
    }
  }

  static dynamic _get(String key) {
    try {
      final raw = _box.get(key);
      if (raw == null) return null;
      return json.decode(raw as String);
    } catch (_) {
      return null;
    }
  }

  static bool _isExpired(String key) {
    try {
      final ts = _box.get('$key$_timestampSuffix');
      if (ts == null) return true;
      final saved = DateTime.fromMillisecondsSinceEpoch(ts as int);
      return DateTime.now().difference(saved) > AppConfig.cacheExpiry;
    } catch (_) {
      return true;
    }
  }
}

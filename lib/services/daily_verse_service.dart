import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// DailyVerseService
/// Downloads all 365 verses once, stores in Hive for offline use.
/// Notifications and home screen both read from Hive.
/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class DailyVerseService {
  DailyVerseService._();

  static const String _boxName = 'daily_verses';
  static const String _lastSyncKey = 'daily_verses_last_sync';
  static const String _yearKey = 'daily_verses_year';

  // Re-sync every 7 days
  static const int _syncIntervalDays = 7;

  /// Initialize the Hive box
  static Future<void> ensureInitialized() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  /// Sync all 365 verses from API into Hive
  /// Returns true if sync succeeded or skipped (still valid)
  static Future<bool> syncIfNeeded({bool force = false}) async {
    await ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final lastSyncMs = prefs.getInt(_lastSyncKey) ?? 0;
    final storedYear = prefs.getInt(_yearKey) ?? 0;
    final currentYear = DateTime.now().year;

    // Check if sync needed
    if (!force && lastSyncMs > 0 && storedYear == currentYear) {
      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      final daysSince = DateTime.now().difference(lastSync).inDays;
      if (daysSince < _syncIntervalDays) {
        return true; // still fresh
      }
    }

    // Perform sync
    try {
      final response = await ApiService.get(
        '/verses/daily/preview/year',
      );

      if (!response.isSuccess || response.asMap == null) {
        return false;
      }

      final data = response.asMap!;
      final verses = data['verses'];
      if (verses is! List) return false;

      final box = Hive.box(_boxName);
      await box.clear();

      for (final v in verses) {
        if (v is! Map) continue;
        final dayOfYear = v['day_of_year'];
        if (dayOfYear == null) continue;

        final ref = v['reference'];
        String refString = '';
        if (ref is Map) {
          final book = ref['book_name']?.toString() ?? '';
          final chapter = ref['chapter']?.toString() ?? '';
          final verse = ref['verse']?.toString() ?? '';
          if (book.isNotEmpty && chapter.isNotEmpty && verse.isNotEmpty) {
            refString = '$book $chapter:$verse';
          }
        }

        await box.put(dayOfYear.toString(), {
          'day_of_year': dayOfYear,
          'date': v['date']?.toString() ?? '',
          'text': v['text']?.toString() ?? '',
          'reference': refString,
          'book_name': ref is Map ? (ref['book_name']?.toString() ?? '') : '',
          'chapter': ref is Map ? (ref['chapter']?.toString() ?? '') : '',
          'verse': ref is Map ? (ref['verse']?.toString() ?? '') : '',
          'language': v['language']?.toString() ?? 'english',
        });
      }

      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_yearKey, currentYear);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get today's verse from Hive (offline-ready)
  static Map<String, String>? getTodaysVerse() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final dayOfYear = _dayOfYear(DateTime.now());
    final raw = box.get(dayOfYear.toString());
    if (raw is Map) {
      return {
        'text': raw['text']?.toString() ?? '',
        'reference': raw['reference']?.toString() ?? '',
        'book_name': raw['book_name']?.toString() ?? '',
        'chapter': raw['chapter']?.toString() ?? '',
        'verse': raw['verse']?.toString() ?? '',
      };
    }
    return null;
  }

  /// Get verse for any specific day of year (1-366)
  static Map<String, String>? getVerseForDay(int dayOfYear) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final raw = box.get(dayOfYear.toString());
    if (raw is Map) {
      return {
        'text': raw['text']?.toString() ?? '',
        'reference': raw['reference']?.toString() ?? '',
        'book_name': raw['book_name']?.toString() ?? '',
        'chapter': raw['chapter']?.toString() ?? '',
        'verse': raw['verse']?.toString() ?? '',
      };
    }
    return null;
  }

  /// Check if verses are downloaded
  static bool hasCachedVerses() {
    if (!Hive.isBoxOpen(_boxName)) return false;
    return Hive.box(_boxName).length > 0;
  }

  /// Number of verses cached
  static int cachedVerseCount() {
    if (!Hive.isBoxOpen(_boxName)) return 0;
    return Hive.box(_boxName).length;
  }

  static int _dayOfYear(DateTime d) {
    return d.difference(DateTime(d.year, 1, 1)).inDays + 1;
  }
}
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';

// ─────────────────────────────────────────────────────────
// ProgressCacheService
// Tracks which lessons are completed locally in Hive
// Works offline — syncs with API when online
// ─────────────────────────────────────────────────────────
class ProgressCacheService {
  ProgressCacheService._();

  static Box get _box => Hive.box(AppConfig.progressBoxName);

  static const String _completedPrefix = 'completed_';
  static const String _progressPrefix = 'progress_';

  // ── Mark lesson as completed ───────────────────────────
  static Future<void> markCompleted(String lessonId) async {
    await _box.put('$_completedPrefix$lessonId', true);
    await _box.put('$_progressPrefix$lessonId', 100);
  }

  // ── Save progress percentage ───────────────────────────
  static Future<void> saveProgress(String lessonId, int percentage) async {
    await _box.put('$_progressPrefix$lessonId', percentage);
    if (percentage >= 100) {
      await _box.put('$_completedPrefix$lessonId', true);
    }
  }

  // ── Check if lesson is completed ──────────────────────
  static bool isCompleted(String lessonId) {
    return _box.get('$_completedPrefix$lessonId') == true;
  }

  // ── Get progress percentage ────────────────────────────
  static int getProgress(String lessonId) {
    return _box.get('$_progressPrefix$lessonId') as int? ?? 0;
  }

  // ── Get all completed lesson IDs ──────────────────────
  static List<String> getAllCompletedIds() {
    final ids = <String>[];
    for (final key in _box.keys) {
      final k = key.toString();
      if (k.startsWith(_completedPrefix) && _box.get(k) == true) {
        ids.add(k.replaceFirst(_completedPrefix, ''));
      }
    }
    return ids;
  }

  // ── Total completed count ──────────────────────────────
  static int get completedCount => getAllCompletedIds().length;

  // ── Clear all progress ─────────────────────────────────
  static Future<void> clearAll() async {
    final keysToDelete = _box.keys
        .where((k) =>
            k.toString().startsWith(_completedPrefix) ||
            k.toString().startsWith(_progressPrefix))
        .toList();
    for (final k in keysToDelete) {
      await _box.delete(k);
    }
  }
}

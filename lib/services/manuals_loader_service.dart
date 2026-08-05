import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────
/// ManualsLoaderService
/// Loads bundled manuals.json + lessons_full.json into Hive
/// on first launch for instant offline-first access.
/// ─────────────────────────────────────────────────────
class ManualsLoaderService {
  ManualsLoaderService._();

  static const String _manualsBoxName = 'manuals_cache';
  static const String _lessonsBoxName = 'lessons_full_cache';

  // Bump this when data content changes to force reload
  static const String _loadedFlag = 'manuals_bundled_v2';

  /// Main entry - call from splash
  static Future<bool> ensureManualsLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyLoaded = prefs.getBool(_loadedFlag) ?? false;

    // Always open the boxes so read methods work
    await Hive.openBox(_manualsBoxName);
    await Hive.openBox(_lessonsBoxName);

    if (alreadyLoaded) return true;

    try {
      await _loadManuals();
      await _loadLessons();
      await prefs.setBool(_loadedFlag, true);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Manuals loading failed: $e');
      return false;
    }
  }

  /// Load bundled manuals.json into Hive
  /// Handles BOTH raw array [] and wrapped { manuals: [] } formats
  static Future<void> _loadManuals() async {
    final jsonString =
        await rootBundle.loadString('assets/manuals/manuals.json');
    final dynamic root = json.decode(jsonString);

    final box = Hive.box(_manualsBoxName);
    await box.clear();

    List manuals = [];
    if (root is List) {
      manuals = root;
    } else if (root is Map && root['manuals'] is List) {
      manuals = root['manuals'];
    }

    for (final m in manuals) {
      if (m is Map && m['id'] != null) {
        final id = m['id'].toString();
        await box.put(id, json.encode(m));
      }
    }

    // ignore: avoid_print
    print('Manuals loaded: ${box.length}');
  }

  /// Load bundled lessons_full.json into Hive
  /// Handles BOTH raw array [] and wrapped { lessons: [] } formats
  static Future<void> _loadLessons() async {
    final jsonString =
        await rootBundle.loadString('assets/manuals/lessons_full.json');
    final dynamic root = json.decode(jsonString);

    final box = Hive.box(_lessonsBoxName);
    await box.clear();

    List lessons = [];
    if (root is List) {
      lessons = root;
    } else if (root is Map && root['lessons'] is List) {
      lessons = root['lessons'];
    }

    for (final l in lessons) {
      if (l is Map && l['id'] != null) {
        final id = l['id'].toString();
        await box.put(id, json.encode(l));
      }
    }

    // ignore: avoid_print
    print('Full lessons loaded: ${box.length}');
  }

  // ─────────────────────────────────────────────────
  // READ API
  // ─────────────────────────────────────────────────

  /// Get all manuals sorted by year (newest first) then period
  static List<Map<String, dynamic>> getAllManuals() {
    if (!Hive.isBoxOpen(_manualsBoxName)) return [];
    final box = Hive.box(_manualsBoxName);
    final list = <Map<String, dynamic>>[];
    for (final k in box.keys) {
      final raw = box.get(k);
      if (raw is String) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map) list.add(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      }
    }
    list.sort((a, b) {
      final ya = (a['year'] as num?)?.toInt() ?? 0;
      final yb = (b['year'] as num?)?.toInt() ?? 0;
      if (ya != yb) return yb.compareTo(ya);
      final pa = a['period']?.toString() ?? '';
      final pb = b['period']?.toString() ?? '';
      return pb.compareTo(pa);
    });
    return list;
  }

  /// Get single manual by id
  static Map<String, dynamic>? getManual(String id) {
    if (!Hive.isBoxOpen(_manualsBoxName)) return null;
    final raw = Hive.box(_manualsBoxName).get(id);
    if (raw is String) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// Get all lessons for a specific manual, sorted by lesson_number
  static List<Map<String, dynamic>> getLessonsForManual(String manualId) {
    if (!Hive.isBoxOpen(_lessonsBoxName)) return [];
    final box = Hive.box(_lessonsBoxName);
    final list = <Map<String, dynamic>>[];
    for (final k in box.keys) {
      final raw = box.get(k);
      if (raw is String) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map) {
            final mid = decoded['manual_id']?.toString();
            if (mid == manualId) {
              list.add(Map<String, dynamic>.from(decoded));
            }
          }
        } catch (_) {}
      }
    }
    list.sort((a, b) {
      final na = (a['lesson_number'] as num?)?.toInt() ?? 0;
      final nb = (b['lesson_number'] as num?)?.toInt() ?? 0;
      return na.compareTo(nb);
    });
    return list;
  }

  /// Get single full lesson by id
  static Map<String, dynamic>? getFullLesson(String lessonId) {
    if (!Hive.isBoxOpen(_lessonsBoxName)) return null;
    final raw = Hive.box(_lessonsBoxName).get(lessonId);
    if (raw is String) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// Save a single lesson fetched from API (for updates)
  static Future<void> saveFullLesson(Map<String, dynamic> lesson) async {
    if (!Hive.isBoxOpen(_lessonsBoxName)) return;
    final id = lesson['id']?.toString();
    if (id == null) return;
    await Hive.box(_lessonsBoxName).put(id, json.encode(lesson));
  }

  /// Save updated manuals list from API
  static Future<void> saveManuals(List<dynamic> manuals) async {
    if (!Hive.isBoxOpen(_manualsBoxName)) return;
    final box = Hive.box(_manualsBoxName);
    for (final m in manuals) {
      if (m is Map && m['id'] != null) {
        await box.put(m['id'].toString(), json.encode(m));
      }
    }
  }

  // ─────────────────────────────────────────────────
  // LANGUAGE SWITCH — find sibling lesson in other language
  // ─────────────────────────────────────────────────

  /// Given a lesson, find its equivalent in the sibling (other-language) manual.
  /// Match rule: same lesson_number in the parent/child manual.
  /// Returns null if no sibling found.
  static Map<String, dynamic>? findSiblingLesson(
      Map<String, dynamic> currentLesson) {
    final currentManualId = currentLesson['manual_id']?.toString();
    final currentLessonNumber =
        (currentLesson['lesson_number'] as num?)?.toInt();

    if (currentManualId == null || currentLessonNumber == null) return null;

    final currentManual = getManual(currentManualId);
    if (currentManual == null) return null;

    // Determine sibling manual id
    String? siblingManualId;
    final parentId = currentManual['parent_manual_id'];

    if (parentId != null) {
      // Current is a child (yoruba) → sibling is its parent (english)
      siblingManualId = parentId.toString();
    } else {
      // Current is a parent (english) → sibling is the child pointing to it
      final all = getAllManuals();
      for (final m in all) {
        if (m['parent_manual_id']?.toString() == currentManualId) {
          siblingManualId = m['id']?.toString();
          break;
        }
      }
    }

    if (siblingManualId == null) return null;

    // Find lesson with same lesson_number in sibling manual
    final siblingLessons = getLessonsForManual(siblingManualId);
    for (final l in siblingLessons) {
      final ln = (l['lesson_number'] as num?)?.toInt();
      if (ln == currentLessonNumber) return l;
    }
    return null;
  }
}
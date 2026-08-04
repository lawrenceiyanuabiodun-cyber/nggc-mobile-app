import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';

/// ─────────────────────────────────────────────────────────
/// LessonsLoaderService
/// Loads bundled lessons.json into cache on first launch.
/// After first load, cache is pre-populated for instant
/// offline access — mirrors BibleLoaderService pattern.
/// ─────────────────────────────────────────────────────────
class LessonsLoaderService {
  LessonsLoaderService._();

  // Flag stored in SharedPreferences so we don't reload every time
  static const String _loadedFlag = 'lessons_bundled_v1';

  /// Main entry — call this from splash screen
  /// Returns true if lessons are ready to use
  static Future<bool> ensureLessonsLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyLoaded = prefs.getBool(_loadedFlag) ?? false;

    if (alreadyLoaded) {
      // Lessons already in cache — skip loading
      return true;
    }

    // First launch → load from bundled JSON asset into cache
    try {
      await _loadLessons();
      await prefs.setBool(_loadedFlag, true);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Lessons loading failed: $e');
      return false;
    }
  }

  /// Read bundled JSON and save into CacheService
  static Future<void> _loadLessons() async {
    final jsonString = await rootBundle.loadString(
      'assets/lessons/lessons.json',
    );

    final List<dynamic> lessons = json.decode(jsonString);

    // Save into cache so lessons_screen.dart finds them instantly
    await CacheService.saveLessons(lessons);

    // ignore: avoid_print
    print('✅ Lessons loaded from bundle: ${lessons.length} lessons');
  }
}
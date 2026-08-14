import 'api_service.dart';

/// ─────────────────────────────────────────────────────────
/// ReadingPlanService
/// Wraps /reading-plan/* endpoints on the backend.
/// - GET /reading-plan/today       → today's chapter reference
/// - GET /reading-plan/day/{d}     → any specific day 1-365
/// - POST /reading-plan/mark-read  → mark a chapter as read
/// - GET /reading-plan/progress    → streak + history
/// ─────────────────────────────────────────────────────────
class ReadingPlanService {
  ReadingPlanService._();

  /// Fetch today's chapter reading.
  /// Returns a map with: day_of_year, book_number, book_english_name,
  /// book_yoruba_name, chapter, theme, label, is_read, is_rest_day
  static Future<Map<String, dynamic>?> getToday() async {
    final res = await ApiService.get('/reading-plan/today');
    if (res.isSuccess && res.asMap != null) {
      return res.asMap;
    }
    return null;
  }

  /// Fetch reading for a specific day (1-365)
  static Future<Map<String, dynamic>?> getDay(int dayOfYear) async {
    if (dayOfYear < 1 || dayOfYear > 365) return null;
    final res = await ApiService.get('/reading-plan/day/$dayOfYear');
    if (res.isSuccess && res.asMap != null) {
      return res.asMap;
    }
    return null;
  }

  /// Mark today's (or any day's) chapter as read.
  /// Returns true if marked (or already marked), false on real error.
  static Future<bool> markRead({
    required int dayOfYear,
    required int year,
  }) async {
    final res = await ApiService.post(
      '/reading-plan/mark-read',
      body: {
        'day_of_year': dayOfYear,
        'year': year,
      },
    );
    return res.isSuccess;
  }

  /// Get user progress + streak stats.
  /// Returns: total_read, current_streak, longest_streak, year, days_read_this_year
  static Future<Map<String, dynamic>?> getProgress() async {
    final res = await ApiService.get('/reading-plan/progress');
    if (res.isSuccess && res.asMap != null) {
      return res.asMap;
    }
    return null;
  }

  /// Fetch AMPC (Amplified Classic Bible) chapter from backend.
  /// Returns a list of verse maps: [{verse: 1, text: "..."}, ...]
  /// Returns null on error or if chapter not found.
  static Future<List<Map<String, dynamic>>?> fetchAmpcChapter({
    required int bookNumber,
    required int chapter,
  }) async {
    final res = await ApiService.get('/bible/ampc/chapter/$bookNumber/$chapter');
    if (!res.isSuccess || res.asMap == null) return null;
    final map = res.asMap!;
    final versesRaw = map['verses'];
    if (versesRaw is! List) return null;
    return versesRaw
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }
}

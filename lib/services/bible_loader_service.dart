import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────
/// BibleLoaderService
/// Loads bundled Bible JSON files into Hive on first launch.
/// After first load, uses Hive for instant offline access.
/// ─────────────────────────────────────────────────────────
class BibleLoaderService {
  BibleLoaderService._();

  // Hive box names
  static const String _englishBoxName = 'bible_english';
  static const String _yorubaBoxName = 'bible_yoruba';

  // Flag stored in SharedPreferences so we don't reload every time
  static const String _loadedFlag = 'bibles_loaded_v1';

  /// Main entry — call this from splash screen
  /// Returns true if Bibles are ready to use
  static Future<bool> ensureBiblesLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyLoaded = prefs.getBool(_loadedFlag) ?? false;

    if (alreadyLoaded) {
      // Bibles already in Hive → open the boxes and return
      await Hive.openBox(_englishBoxName);
      await Hive.openBox(_yorubaBoxName);
      return true;
    }

    // First launch → load from JSON assets into Hive
    try {
      await _loadEnglishBible();
      await _loadYorubaBible();
      await prefs.setBool(_loadedFlag, true);
      return true;
    } catch (e) {
      // If loading fails, log and continue (app can still use API)
      // ignore: avoid_print
      print('❌ Bible loading failed: $e');
      return false;
    }
  }

  /// ─────────────────────────────────────────────────
  /// English Bible — Nested format
  /// Structure: { "Book": { "Chapter": { "Verse": "text" } } }
  /// ─────────────────────────────────────────────────
  static Future<void> _loadEnglishBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/english_bible.json',
    );
    final Map<String, dynamic> data = json.decode(jsonString);

    final box = await Hive.openBox(_englishBoxName);
    await box.clear();

    for (final bookEntry in data.entries) {
      final bookName = bookEntry.key;
      final chapters = bookEntry.value as Map<String, dynamic>;

      // Store each book as one entry: "Genesis" → { "1": { "1": "text" } }
      await box.put(bookName, chapters);
    }

    // ignore: avoid_print
    print('✅ English Bible loaded: ${box.length} books');
  }

  /// ─────────────────────────────────────────────────
  /// Yoruba Bible — Flat array format
  /// Structure: [ {bookName, book_number, chapter, verse, text} ]
  /// We convert it to the same nested format for consistency.
  /// ─────────────────────────────────────────────────
  static Future<void> _loadYorubaBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/yoruba_bible.json',
    );
    final dynamic decoded = json.decode(jsonString);

    final box = await Hive.openBox(_yorubaBoxName);
    await box.clear();

    // Handle two possible structures:
    // A) Array of book-groups: [ { bookName, details: [...] } ]
    // B) Flat array of verses: [ { bookName, chapter, verse, text } ]
    if (decoded is List) {
      final Map<String, Map<String, Map<String, String>>> grouped = {};

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          // Format A — has "details" key containing verse array
          if (item.containsKey('details')) {
            final details = item['details'] as List;
            for (final v in details) {
              _addYorubaVerse(grouped, v as Map<String, dynamic>);
            }
          } else {
            // Format B — item itself is a verse
            _addYorubaVerse(grouped, item);
          }
        }
      }

      // Save into Hive
      for (final entry in grouped.entries) {
        await box.put(entry.key, entry.value);
      }
    }

    // ignore: avoid_print
    print('✅ Yoruba Bible loaded: ${box.length} books');
  }

  /// Helper: Add one Yoruba verse to the grouped structure
  static void _addYorubaVerse(
    Map<String, Map<String, Map<String, String>>> grouped,
    Map<String, dynamic> verseData,
  ) {
    final bookName = verseData['bookName']?.toString() ?? 'Unknown';
    final chapter = verseData['chapter']?.toString() ?? '0';
    final verse = verseData['verse']?.toString() ?? '0';
    final text = verseData['text']?.toString() ?? '';

    grouped.putIfAbsent(bookName, () => {});
    grouped[bookName]!.putIfAbsent(chapter, () => {});
    grouped[bookName]![chapter]![verse] = text;
  }

  /// ─────────────────────────────────────────────────
  /// Public Read API — for Bible screens to use
  /// ─────────────────────────────────────────────────

  /// Get all books for a language
  /// language: 'english' or 'yoruba'
  static List<String> getBooks(String language) {
    final boxName = language == 'yoruba' ? _yorubaBoxName : _englishBoxName;
    if (!Hive.isBoxOpen(boxName)) return [];
    final box = Hive.box(boxName);
    return box.keys.cast<String>().toList();
  }

  /// Get all chapters for a book
  static List<String> getChapters(String language, String book) {
    final boxName = language == 'yoruba' ? _yorubaBoxName : _englishBoxName;
    if (!Hive.isBoxOpen(boxName)) return [];
    final box = Hive.box(boxName);
    final bookData = box.get(book);
    if (bookData is Map) {
      return bookData.keys.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Get all verses for a chapter
  /// Returns: { "1": "In the beginning...", "2": "..." }
  static Map<String, String> getVerses(
    String language,
    String book,
    String chapter,
  ) {
    final boxName = language == 'yoruba' ? _yorubaBoxName : _englishBoxName;
    if (!Hive.isBoxOpen(boxName)) return {};
    final box = Hive.box(boxName);
    final bookData = box.get(book);
    if (bookData is Map) {
      final chapterData = bookData[chapter];
      if (chapterData is Map) {
        return chapterData.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
    }
    return {};
  }

  /// Get a single verse
  static String? getVerse(
    String language,
    String book,
    String chapter,
    String verse,
  ) {
    final verses = getVerses(language, book, chapter);
    return verses[verse];
  }
}
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
  // Bumped to v2 to force reload after fixing parser bug
  static const String _loadedFlag = 'bibles_loaded_v3';

  // Standard 66-book English Bible name map (matches KJV book numbers 1-66)
  static const List<String> _englishBookNames = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
    '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
    'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
    'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah', 'Lamentations',
    'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
    'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
    'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation',
  ];

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
      // ignore: avoid_print
      print('❌ Bible loading failed: $e');
      return false;
    }
  }

  /// ─────────────────────────────────────────────────────────
  /// English Bible loader
  /// JSON structure:
  /// {
  ///   "language": "english",
  ///   "translation": "KJV",
  ///   "books": {
  ///     "1": { "1": { "1": "text" } },
  ///     "2": { ... }
  ///   }
  /// }
  /// We map book numbers 1..66 → English book names.
  /// ─────────────────────────────────────────────────────────
  static Future<void> _loadEnglishBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/english_bible.json',
    );
    final Map<String, dynamic> root = json.decode(jsonString);

    // Get the "books" object (or fallback to root for legacy format)
    final Map<String, dynamic> booksMap = root['books'] is Map
        ? Map<String, dynamic>.from(root['books'])
        : root;

    final box = await Hive.openBox(_englishBoxName);
    await box.clear();

    // Sort by numeric key to preserve Genesis..Revelation order
    final sortedKeys = booksMap.keys.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a) ?? 999;
        final bi = int.tryParse(b) ?? 999;
        return ai.compareTo(bi);
      });

    for (final key in sortedKeys) {
      final chaptersRaw = booksMap[key];
      if (chaptersRaw is! Map) continue;

      // Map "1" → "Genesis", "66" → "Revelation"
      final bookNum = int.tryParse(key);
      String bookName;
      if (bookNum != null && bookNum >= 1 && bookNum <= _englishBookNames.length) {
        bookName = _englishBookNames[bookNum - 1];
      } else {
        // If key is already a name (legacy format), use it
        bookName = key;
      }

      // Normalize chapters → { "1": { "1": "text" } }
      final Map<String, Map<String, String>> normalized = {};
      for (final chapEntry in chaptersRaw.entries) {
        final chapKey = chapEntry.key.toString();
        final versesRaw = chapEntry.value;
        if (versesRaw is Map) {
          final Map<String, String> verses = {};
          for (final verseEntry in versesRaw.entries) {
            verses[verseEntry.key.toString()] = verseEntry.value.toString();
          }
          normalized[chapKey] = verses;
        }
      }

      await box.put(bookName, normalized);
    }

    // ignore: avoid_print
    print('✅ English Bible loaded: ${box.length} books');
  }

  /// ─────────────────────────────────────────────────────────
  /// Yoruba Bible loader
  /// JSON structure (Format A):
  /// [
  ///   {
  ///     "bookName": "Gẹ́nẹ́sísì",
  ///     "details": [
  ///       { "bookName": "...", "chapter": 1, "verse": 1, "text": "..." }
  ///     ]
  ///   }
  /// ]
  /// ─────────────────────────────────────────────────────────
  static Future<void> _loadYorubaBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/yoruba_bible.json',
    );
    final dynamic decoded = json.decode(jsonString);

    final box = await Hive.openBox(_yorubaBoxName);
    await box.clear();

    if (decoded is List) {
      // Preserve original book order using a list of book names
      final List<String> bookOrder = [];
      final Map<String, Map<String, Map<String, String>>> grouped = {};

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          // Prefer top-level bookName for grouping (Format A)
          final topBookName = item['bookName']?.toString();

          if (item.containsKey('details') && item['details'] is List) {
            final details = item['details'] as List;
            for (final v in details) {
              if (v is Map<String, dynamic>) {
                _addYorubaVerse(grouped, bookOrder, v, fallbackBookName: topBookName);
              }
            }
          } else {
            // Format B — item itself is a verse
            _addYorubaVerse(grouped, bookOrder, item);
          }
        }
      }

      // Save in insertion order (matches JSON order)
      for (final book in bookOrder) {
        final data = grouped[book];
        if (data != null) {
          await box.put(book, data);
        }
      }
    }

    // ignore: avoid_print
    print('✅ Yoruba Bible loaded: ${box.length} books');
  }

  /// Helper: Add one Yoruba verse to the grouped structure
  static void _addYorubaVerse(
    Map<String, Map<String, Map<String, String>>> grouped,
    List<String> bookOrder,
    Map<String, dynamic> verseData, {
    String? fallbackBookName,
  }) {
    final bookName = (verseData['bookName']?.toString().trim().isNotEmpty ?? false)
        ? verseData['bookName'].toString()
        : (fallbackBookName ?? 'Unknown');
    final chapter = verseData['chapter']?.toString() ?? '0';
    final verse = verseData['verse']?.toString() ?? '0';
    final text = verseData['text']?.toString() ?? '';

    if (!grouped.containsKey(bookName)) {
      grouped[bookName] = {};
      bookOrder.add(bookName);
    }
    grouped[bookName]!.putIfAbsent(chapter, () => {});
    grouped[bookName]![chapter]![verse] = text;
  }

  /// ─────────────────────────────────────────────────────────
  /// Public Read API
  /// ─────────────────────────────────────────────────────────

  /// Get all books for a language
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
      final keys = bookData.keys.map((e) => e.toString()).toList();
      // Sort numerically so 1, 2, 3, ... 10, 11 (not 1, 10, 11, 2)
      keys.sort((a, b) {
        final ai = int.tryParse(a) ?? 999;
        final bi = int.tryParse(b) ?? 999;
        return ai.compareTo(bi);
      });
      return keys;
    }
    return [];
  }

  /// Get all verses for a chapter
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



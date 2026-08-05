import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────
/// BibleLoaderService
/// Loads all Bible translations into Hive on first launch.
/// Supports: KJV, ASV, BBE, KJVA, Webster, YLT, Yoruba
/// ─────────────────────────────────────────────────────────
class BibleLoaderService {
  BibleLoaderService._();

  // Hive box names
  static const String _englishBoxName = 'bible_english';
  static const String _yorubaBoxName  = 'bible_yoruba';
  static const String _asvBoxName     = 'bible_asv';
  static const String _bbeBoxName     = 'bible_bbe';
  static const String _kjvaBoxName    = 'bible_kjva';
  static const String _websterBoxName = 'bible_webster';
  static const String _yltBoxName     = 'bible_ylt';

  // Bump version to force reload when new translations added
  static const String _loadedFlag = 'bibles_loaded_v6';

  // Special key for Yoruba book order
  static const String _yorubaOrderKey = '__book_order__';

  // All supported translations
  static const List<Map<String, String>> translations = [
    {
      'key':      'english',
      'label':    'KJV',
      'fullName': 'King James Version',
      'box':      'bible_english',
      'year':     '1611',
    },
    {
      'key':      'kjva',
      'label':    'KJVA',
      'fullName': 'King James Version with Apocrypha',
      'box':      'bible_kjva',
      'year':     '1611',
    },
    {
      'key':      'asv',
      'label':    'ASV',
      'fullName': 'American Standard Version',
      'box':      'bible_asv',
      'year':     '1901',
    },
    {
      'key':      'bbe',
      'label':    'BBE',
      'fullName': 'Bible in Basic English',
      'box':      'bible_bbe',
      'year':     '1949',
    },
    {
      'key':      'webster',
      'label':    'Webster',
      'fullName': 'Webster Bible',
      'box':      'bible_webster',
      'year':     '1833',
    },
    {
      'key':      'ylt',
      'label':    'YLT',
      'fullName': "Young's Literal Translation",
      'box':      'bible_ylt',
      'year':     '1898',
    },
    {
      'key':      'yoruba',
      'label':    'Yoruba',
      'fullName': 'Bibeli Mimo',
      'box':      'bible_yoruba',
      'year':     '',
    },
  ];

  // Standard 66-book English Bible name map
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

  /// Main entry — call from splash screen
  static Future<bool> ensureBiblesLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyLoaded = prefs.getBool(_loadedFlag) ?? false;

    if (alreadyLoaded) {
      await Hive.openBox(_englishBoxName);
      await Hive.openBox(_yorubaBoxName);
      await Hive.openBox(_asvBoxName);
      await Hive.openBox(_bbeBoxName);
      await Hive.openBox(_kjvaBoxName);
      await Hive.openBox(_websterBoxName);
      await Hive.openBox(_yltBoxName);
      return true;
    }

    try {
      await _loadEnglishBible();
      await _loadYorubaBible();
      await _loadScrollmapperBible(
        assetPath: 'assets/bibles/asv_bible.json',
        boxName: _asvBoxName,
        label: 'ASV',
      );
      await _loadScrollmapperBible(
        assetPath: 'assets/bibles/bbe_bible.json',
        boxName: _bbeBoxName,
        label: 'BBE',
      );
      await _loadScrollmapperBible(
        assetPath: 'assets/bibles/kjva_bible.json',
        boxName: _kjvaBoxName,
        label: 'KJVA',
      );
      await _loadScrollmapperBible(
        assetPath: 'assets/bibles/webster_bible.json',
        boxName: _websterBoxName,
        label: 'Webster',
      );
      await _loadScrollmapperBible(
        assetPath: 'assets/bibles/ylt_bible.json',
        boxName: _yltBoxName,
        label: 'YLT',
      );
      await prefs.setBool(_loadedFlag, true);
      return true;
    } catch (e) {
      print('Bible loading failed: $e');
      return false;
    }
  }

  /// Load Scrollmapper format:
  /// { "translation": "...", "books": [ { "name": "Genesis",
  ///   "chapters": [ { "chapter": 1,
  ///     "verses": [ { "verse": 1, "text": "..." } ] } ] } ] }
  static Future<void> _loadScrollmapperBible({
    required String assetPath,
    required String boxName,
    required String label,
  }) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> root = json.decode(jsonString);

    final box = await Hive.openBox(boxName);
    await box.clear();

    final books = root['books'];
    if (books is! List) {
      print('$label: no books array found');
      return;
    }

    for (final bookRaw in books) {
      if (bookRaw is! Map) continue;
      final bookName = bookRaw['name']?.toString() ?? '';
      if (bookName.isEmpty) continue;

      final Map<String, Map<String, String>> chaptersMap = {};
      final chaptersRaw = bookRaw['chapters'];
      if (chaptersRaw is List) {
        for (final chapRaw in chaptersRaw) {
          if (chapRaw is! Map) continue;
          final chapNum = chapRaw['chapter']?.toString() ?? '';
          if (chapNum.isEmpty) continue;

          final Map<String, String> versesMap = {};
          final versesRaw = chapRaw['verses'];
          if (versesRaw is List) {
            for (final verseRaw in versesRaw) {
              if (verseRaw is! Map) continue;
              final verseNum = verseRaw['verse']?.toString() ?? '';
              final text    = verseRaw['text']?.toString() ?? '';
              if (verseNum.isNotEmpty) {
                versesMap[verseNum] = text;
              }
            }
          }
          chaptersMap[chapNum] = versesMap;
        }
      }
      await box.put(bookName, chaptersMap);
    }

    print('$label Bible loaded: ${box.length} books');
  }

  /// English KJV loader (existing format)
  static Future<void> _loadEnglishBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/english_bible.json',
    );
    final Map<String, dynamic> root = json.decode(jsonString);
    final Map<String, dynamic> booksMap = root['books'] is Map
        ? Map<String, dynamic>.from(root['books'])
        : root;

    final box = await Hive.openBox(_englishBoxName);
    await box.clear();

    final sortedKeys = booksMap.keys.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a) ?? 999;
        final bi = int.tryParse(b) ?? 999;
        return ai.compareTo(bi);
      });

    for (final key in sortedKeys) {
      final chaptersRaw = booksMap[key];
      if (chaptersRaw is! Map) continue;

      final bookNum = int.tryParse(key);
      String bookName;
      if (bookNum != null &&
          bookNum >= 1 &&
          bookNum <= _englishBookNames.length) {
        bookName = _englishBookNames[bookNum - 1];
      } else {
        bookName = key;
      }

      final Map<String, Map<String, String>> normalized = {};
      for (final chapEntry in chaptersRaw.entries) {
        final chapKey  = chapEntry.key.toString();
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
    print('KJV Bible loaded: ${box.length} books');
  }

  /// Yoruba Bible loader (existing format)
  static Future<void> _loadYorubaBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/yoruba_bible.json',
    );
    final dynamic decoded = json.decode(jsonString);
    final box = await Hive.openBox(_yorubaBoxName);
    await box.clear();

    if (decoded is List) {
      final List<String> bookOrder = [];
      final Map<String, Map<String, Map<String, String>>> grouped = {};

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final topBookName = item['bookName']?.toString();
          if (item.containsKey('details') && item['details'] is List) {
            for (final v in item['details'] as List) {
              if (v is Map<String, dynamic>) {
                _addYorubaVerse(grouped, bookOrder, v,
                    fallbackBookName: topBookName);
              }
            }
          } else {
            _addYorubaVerse(grouped, bookOrder, item);
          }
        }
      }

      for (final book in bookOrder) {
        final data = grouped[book];
        if (data != null) await box.put(book, data);
      }
      await box.put(_yorubaOrderKey, bookOrder);
    }
    print('Yoruba Bible loaded: ${box.length - 1} books');
  }

  static void _addYorubaVerse(
    Map<String, Map<String, Map<String, String>>> grouped,
    List<String> bookOrder,
    Map<String, dynamic> verseData, {
    String? fallbackBookName,
  }) {
    final bookName =
        (verseData['bookName']?.toString().trim().isNotEmpty ?? false)
            ? verseData['bookName'].toString()
            : (fallbackBookName ?? 'Unknown');
    final chapter = verseData['chapter']?.toString() ?? '0';
    final verse   = verseData['verse']?.toString() ?? '0';
    final text    = verseData['text']?.toString() ?? '';

    if (!grouped.containsKey(bookName)) {
      grouped[bookName] = {};
      bookOrder.add(bookName);
    }
    grouped[bookName]!.putIfAbsent(chapter, () => {});
    grouped[bookName]![chapter]![verse] = text;
  }

  // ─────────────────────────────────────────────────────────
  // Public Read API
  // ─────────────────────────────────────────────────────────

  static String _boxForTranslation(String translation) {
    switch (translation) {
      case 'asv':     return _asvBoxName;
      case 'bbe':     return _bbeBoxName;
      case 'kjva':    return _kjvaBoxName;
      case 'webster': return _websterBoxName;
      case 'ylt':     return _yltBoxName;
      case 'yoruba':  return _yorubaBoxName;
      default:        return _englishBoxName; // KJV
    }
  }

  /// Get all books for a translation in correct Biblical order
  static List<String> getBooks(String translation) {
    if (translation == 'yoruba') {
      if (!Hive.isBoxOpen(_yorubaBoxName)) return [];
      final box = Hive.box(_yorubaBoxName);
      final orderRaw = box.get(_yorubaOrderKey);
      if (orderRaw is List) return orderRaw.cast<String>().toList();
      return box.keys
          .cast<String>()
          .where((k) => k != _yorubaOrderKey)
          .toList();
    }

    final boxName = _boxForTranslation(translation);
    if (!Hive.isBoxOpen(boxName)) return [];
    final box = Hive.box(boxName);
    final storedKeys = box.keys.cast<String>().toSet();
    return _englishBookNames.where((n) => storedKeys.contains(n)).toList();
  }

  /// Get all chapters for a book
  static List<String> getChapters(String translation, String book) {
    final boxName = _boxForTranslation(translation);
    if (!Hive.isBoxOpen(boxName)) return [];
    final box     = Hive.box(boxName);
    final bookData = box.get(book);
    if (bookData is Map) {
      final keys = bookData.keys.map((e) => e.toString()).toList();
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
    String translation,
    String book,
    String chapter,
  ) {
    final boxName  = _boxForTranslation(translation);
    if (!Hive.isBoxOpen(boxName)) return {};
    final box      = Hive.box(boxName);
    final bookData = box.get(book);
    if (bookData is Map) {
      final chapterData = bookData[chapter];
      if (chapterData is Map) {
        return chapterData.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }
    return {};
  }

  /// Get a single verse
  static String? getVerse(
    String translation,
    String book,
    String chapter,
    String verse,
  ) {
    return getVerses(translation, book, chapter)[verse];
  }

  /// Backward compat — old code passes 'english' or 'yoruba'
  /// New code passes 'asv', 'bbe', etc.
  static List<String> getBooksLegacy(String language) => getBooks(language);
  static List<String> getChaptersLegacy(String language, String book) =>
      getChapters(language, book);
  static Map<String, String> getVersesLegacy(
          String language, String book, String chapter) =>
      getVerses(language, book, chapter);
}
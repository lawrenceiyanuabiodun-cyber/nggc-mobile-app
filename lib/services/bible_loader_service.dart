import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BibleLoaderService {
  BibleLoaderService._();

  static const String _englishBoxName = 'bible_english';
  static const String _yorubaBoxName = 'bible_yoruba';
  static const String _ampcBoxName = 'bible_ampc';
  static const String _nivBoxName = 'bible_niv';
  static const String _nltBoxName = 'bible_nlt';

  static const String _loadedFlag = 'bibles_loaded_v10';
  static const String _yorubaOrderKey = '_book_order';

  static const List<Map<String, String>> translations = [
    {
      'key': 'english',
      'label': 'KJV',
      'fullName': 'King James Version',
      'box': 'bible_english',
      'year': '1611',
    },
    {
      'key': 'yoruba',
      'label': 'Yoruba',
      'fullName': 'Bibeli Mimo',
      'box': 'bible_yoruba',
      'year': '',
    },
    {
      'key': 'ampc',
      'label': 'AMPC',
      'fullName': 'Amplified Classic',
      'box': 'bible_ampc',
      'year': '1987',
    },
    {
      'key': 'niv',
      'label': 'NIV',
      'fullName': 'New International Version',
      'box': 'bible_niv',
      'year': '2011',
    },
    {
      'key': 'nlt',
      'label': 'NLT',
      'fullName': 'New Living Translation',
      'box': 'bible_nlt',
      'year': '2015',
    },
  ];

  static const List<String> _englishBookNames = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
    '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
    'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
    'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
    'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
    'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians',
    '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus',
    'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter',
    '1 John', '2 John', '3 John', 'Jude', 'Revelation',
  ];

  static Future<bool> ensureBiblesLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyLoaded = prefs.getBool(_loadedFlag) ?? false;

    if (alreadyLoaded) {
      await Hive.openBox(_englishBoxName);
      await Hive.openBox(_yorubaBoxName);
      await Hive.openBox(_ampcBoxName);
      await Hive.openBox(_nivBoxName);
      await Hive.openBox(_nltBoxName);
      return true;
    }

    try {
      await _loadEnglishBible();
      await _loadYorubaBible();
      await _loadAmpcBible();
      await _loadNivBible();
      await _loadNltBible();

      await prefs.setBool(_loadedFlag, true);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _loadEnglishBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/english_bible.json',
    );

    final Map<String, dynamic> root = json.decode(jsonString);

    final Map<String, dynamic> booksMap =
        root['books'] is Map
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

      final String bookName =
          bookNum != null &&
                  bookNum >= 1 &&
                  bookNum <= _englishBookNames.length
              ? _englishBookNames[bookNum - 1]
              : key;

      final Map<String, Map<String, String>> normalized = {};

      for (final chapEntry in chaptersRaw.entries) {
        final chapKey = chapEntry.key.toString();
        final versesRaw = chapEntry.value;

        if (versesRaw is Map) {
          final Map<String, String> verses = {};

          for (final verseEntry in versesRaw.entries) {
            verses[verseEntry.key.toString()] =
                verseEntry.value.toString();
          }

          normalized[chapKey] = verses;
        }
      }

      await box.put(bookName, normalized);
    }
  }


  static Future<void> _loadAmpcBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/ampc_bible.json',
    );

    final Map<String, dynamic> booksMap = json.decode(jsonString);

    final box = await Hive.openBox(_ampcBoxName);
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
      final String bookName =
          bookNum != null &&
                  bookNum >= 1 &&
                  bookNum <= _englishBookNames.length
              ? _englishBookNames[bookNum - 1]
              : key;

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
  }


  static Future<void> _loadNivBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/niv_bible.json',
    );

    final Map<String, dynamic> booksMap = json.decode(jsonString);

    final box = await Hive.openBox(_nivBoxName);
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
      final String bookName =
          bookNum != null &&
                  bookNum >= 1 &&
                  bookNum <= _englishBookNames.length
              ? _englishBookNames[bookNum - 1]
              : key;

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
  }


  static Future<void> _loadNltBible() async {
    final jsonString = await rootBundle.loadString(
      'assets/bibles/nlt_bible.json',
    );

    final Map<String, dynamic> booksMap = json.decode(jsonString);

    final box = await Hive.openBox(_nltBoxName);
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
      final String bookName =
          bookNum != null &&
                  bookNum >= 1 &&
                  bookNum <= _englishBookNames.length
              ? _englishBookNames[bookNum - 1]
              : key;

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
  }

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

          if (item.containsKey('details') &&
              item['details'] is List) {
            for (final v in item['details'] as List) {
              if (v is Map<String, dynamic>) {
                _addYorubaVerse(
                  grouped,
                  bookOrder,
                  v,
                  fallbackBookName: topBookName,
                );
              }
            }
          } else {
            _addYorubaVerse(
              grouped,
              bookOrder,
              item,
            );
          }
        }
      }

      for (final book in bookOrder) {
        final data = grouped[book];

        if (data != null) {
          await box.put(book, data);
        }
      }

      await box.put(_yorubaOrderKey, bookOrder);
    }
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
    final verse = verseData['verse']?.toString() ?? '0';
    final text = verseData['text']?.toString() ?? '';

    if (!grouped.containsKey(bookName)) {
      grouped[bookName] = {};
      bookOrder.add(bookName);
    }

    grouped[bookName]!.putIfAbsent(chapter, () => {});
    grouped[bookName]![chapter]![verse] = text;
  }

  static String _boxForTranslation(String translation) {
    switch (translation) {
      case 'yoruba':
        return _yorubaBoxName;
      case 'ampc':
        return _ampcBoxName;
      case 'niv':
        return _nivBoxName;
      case 'nlt':
        return _nltBoxName;
      default:
        return _englishBoxName;
    }
  }

  static List<String> getBooks(String translation) {
    if (translation == 'yoruba') {
      if (!Hive.isBoxOpen(_yorubaBoxName)) return [];

      final box = Hive.box(_yorubaBoxName);
      final orderRaw = box.get(_yorubaOrderKey);

      if (orderRaw is List) {
        return orderRaw.cast<String>().toList();
      }

      return box.keys
          .cast<String>()
          .where((k) => k != _yorubaOrderKey)
          .toList();
    }

    final boxName = _boxForTranslation(translation);

    if (!Hive.isBoxOpen(boxName)) return [];

    final box = Hive.box(boxName);
    final storedKeys = box.keys.cast<String>().toSet();

    return _englishBookNames
        .where((name) => storedKeys.contains(name))
        .toList();
  }

  static List<String> getChapters(
    String translation,
    String book,
  ) {
    final boxName = _boxForTranslation(translation);

    if (!Hive.isBoxOpen(boxName)) return [];

    final box = Hive.box(boxName);
    final bookData = box.get(book);

    if (bookData is Map) {
      final keys =
          bookData.keys.map((e) => e.toString()).toList();

      keys.sort((a, b) {
        final ai = int.tryParse(a) ?? 999;
        final bi = int.tryParse(b) ?? 999;
        return ai.compareTo(bi);
      });

      return keys;
    }

    return [];
  }

  static Map<String, String> getVerses(
    String translation,
    String book,
    String chapter,
  ) {
    final boxName = _boxForTranslation(translation);

    if (!Hive.isBoxOpen(boxName)) return {};

    final box = Hive.box(boxName);
    final bookData = box.get(book);

    if (bookData is Map) {
      final chapterData = bookData[chapter];

      if (chapterData is Map) {
        return chapterData.map(
          (k, v) => MapEntry(
            k.toString(),
            v.toString(),
          ),
        );
      }
    }

    return {};
  }

  static String? getVerse(
    String translation,
    String book,
    String chapter,
    String verse,
  ) {
    return getVerses(
      translation,
      book,
      chapter,
    )[verse];
  }

  static List<String> getBooksLegacy(String language) =>
      getBooks(language);

  static List<String> getChaptersLegacy(
    String language,
    String book,
  ) =>
      getChapters(language, book);

  static Map<String, String> getVersesLegacy(
    String language,
    String book,
    String chapter,
  ) =>
      getVerses(language, book, chapter);
}

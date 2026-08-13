import 'dart:typed_data';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

// Conditional imports: dart:io and path_provider only on mobile,
// web_download_helper only on web.
import 'stub_io.dart' if (dart.library.io) 'io_helper.dart';
import 'stub_web_download.dart'
    if (dart.library.html) '../../services/web_download_helper.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/daily_verse_service.dart';
import '../../services/bible_loader_service.dart';
import '../../services/manuals_loader_service.dart';
import '../../services/reading_plan_service.dart';
import '../../theme/app_theme.dart';
import '../announcements/announcements_screen.dart';
import '../bible/bible_language_screen.dart';
import '../bible/reading_plan_reader_screen.dart';
import '../events/events_screen.dart';
import '../lessons/lesson_detail_screen.dart';
import '../manuals/manuals_screen.dart';
import '../support/support_screen.dart';

class HomeTabScreen extends ConsumerStatefulWidget {
  const HomeTabScreen({super.key});

  @override
  ConsumerState<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends ConsumerState<HomeTabScreen> {
  String? _dailyVerse;
  String? _dailyVerseRef;
  bool _verseLoading = true;
  bool _verseError = false;
  bool _sharingFlyer = false;
  bool _refreshingVerse = false;

  final ScreenshotController _screenshotController = ScreenshotController();

  Map<String, dynamic>? _todayLesson;
  String? _todayLessonDate;
  bool _lessonLoading = true;

  // Reading plan state
  Map<String, dynamic>? _todayReading;
  bool _readingLoading = true;

  // Per-image gradient opacity tuning
  static const Map<String, double> _imageOverlayOpacity = {
    'bible_bg1.jpg': 0.55,
    'bible_bg2.jpg': 0.65,
    'bible_bg3.jpg': 0.60,
    'bible_bg4.jpg': 0.55,
    'bible_bg5.jpg': 0.35,
    'bible_bg6.jpg': 0.55,
    'bible_bg7.jpg': 0.50,
    'bible_bg8.jpg': 0.65,
    'bible_bg9.jpg': 0.55,
    'bible_bg10.jpg': 0.60,
    'bible_bg11.jpg': 0.35,
  };

  static const List<String> _backgroundFiles = [
    'bible_bg1.jpg',
    'bible_bg2.jpg',
    'bible_bg3.jpg',
    'bible_bg4.jpg',
    'bible_bg5.jpg',
    'bible_bg6.jpg',
    'bible_bg7.jpg',
    'bible_bg8.jpg',
    'bible_bg9.jpg',
    'bible_bg10.jpg',
    'bible_bg11.jpg',
  ];

  static const Map<String, String> _englishToYorubaBookNames = {
    'Genesis': 'Gẹ́nẹ́sísì',
    'Exodus': 'Ékísódù',
    'Leviticus': 'Léfítíkù',
    'Numbers': 'Numeri',
    'Deuteronomy': 'Deuteronomi',
    'Joshua': 'Josua',
    'Judges': 'Awọn Onidajọ',
    'Ruth': 'Ruutu',
    '1 Samuel': 'Samueli (Kinni)',
    '2 Samuel': 'Samueli (Keji)',
    '1 Kings': 'Awon Ọba (Kinni)',
    '2 Kings': 'Awon Ọba (Keji)',
    '1 Chronicles': 'Kronika (Kinni)',
    '2 Chronicles': 'Kronika (Keji)',
    'Ezra': 'Esra',
    'Nehemiah': 'Nehemiah',
    'Esther': 'Esteri',
    'Job': 'Jobu',
    'Psalm': 'Psalmu',
    'Psalms': 'Psalmu',
    'Proverbs': 'Òwe',
    'Ecclesiastes': 'Oniwasu',
    'Song of Solomon': 'Orin Solomọni',
    'Song of Songs': 'Orin Solomọni',
    'Isaiah': 'Isaiah',
    'Jeremiah': 'Jeremiah',
    'Lamentations': 'Ẹkún Jeremiah',
    'Ezekiel': 'Esekieli',
    'Daniel': 'Danieli',
    'Hosea': 'Hosea',
    'Joel': 'Joeli',
    'Amos': 'Amọsi',
    'Obadiah': 'Obadiah',
    'Jonah': 'Jonà',
    'Micah': 'Mika',
    'Nahum': 'Nahumu',
    'Habakkuk': 'Habakkuku',
    'Zephaniah': 'Sefaniah',
    'Haggai': 'Haggai',
    'Zechariah': 'Sekariah',
    'Malachi': 'Malaki',
    'Matthew': 'Matteu',
    'Mark': 'Marku',
    'Luke': 'Luku',
    'John': 'Johanu',
    'Acts': 'Ise Awọn Aposteli',
    'Acts of the Apostles': 'Ise Awọn Aposteli',
    'Romans': 'Awọn Ará Romu',
    '1 Corinthians': 'Awọn Ará Korinti (Kinni)',
    '2 Corinthians': 'Awọn Ará Korinti (Keji)',
    'Galatians': 'Awọn Ará Galatia',
    'Ephesians': 'Awọn Ará Efesu',
    'Philippians': 'Awọn Ará Filippi',
    'Colossians': 'Awọn Ará Kolosse',
    '1 Thessalonians': 'Awọn Ará Tessalonika (Kinni)',
    '2 Thessalonians': 'Awọn Ará Tessalonika (Keji)',
    '1 Timothy': 'Timoteu (Kinni)',
    '2 Timothy': 'Timoteu (Keji)',
    'Titus': 'Titu',
    'Philemon': 'Filimọni',
    'Hebrews': 'Awọn Heberu',
    'James': 'Jákọ́bù',
    '1 Peter': 'Peteru (Kinni)',
    '2 Peter': 'Peteru (Keji)',
    '1 John': 'Johanu (Kinni)',
    '2 John': 'Johanu (Keji)',
    '3 John': 'Johanu (Kẹta)',
    'Jude': 'Juda',
    'Revelation': 'Ifihan',
  };

  String _backgroundFileForToday() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(startOfYear).inDays + 1;
    return _backgroundFiles[dayOfYear % _backgroundFiles.length];
  }

  @override
  void initState() {
    super.initState();
    _loadDailyVerse();
    _loadTodayLesson();
    _loadTodayReading();
  }

  Future<void> _loadTodayReading() async {
    setState(() => _readingLoading = true);
    final reading = await ReadingPlanService.getToday();
    if (!mounted) return;
    setState(() {
      _todayReading = reading;
      _readingLoading = false;
    });
  }

  Future<void> _openReader() async {
    if (_todayReading == null) return;
    if (_todayReading!['is_rest_day'] == true) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingPlanReaderScreen(reading: _todayReading!),
      ),
    );
    // Refresh reading state (is_read may have changed)
    _loadTodayReading();
  }

  Future<void> _loadDailyVerse() async {
    setState(() {
      _verseLoading = true;
      _verseError = false;
    });

    final cached = DailyVerseService.getTodaysVerse();
    if (cached != null &&
        (cached['text'] ?? '').isNotEmpty &&
        (cached['reference'] ?? '').isNotEmpty) {
      setState(() {
        _dailyVerse = cached['text'];
        _dailyVerseRef = cached['reference'];
        _verseLoading = false;
        _verseError = false;
      });
      DailyVerseService.syncIfNeeded();
      return;
    }

    try {
      final response = await ApiService.get('/verses/daily');
      if (!mounted) return;

      if (response.isSuccess && response.asMap != null) {
        final data = response.asMap!;
        final text =
            (data['text'] ?? data['verse_text'])?.toString().trim() ?? '';
        final ref = _extractDailyVerseReference(data);

        if (text.isNotEmpty) {
          setState(() {
            _dailyVerse = text;
            _dailyVerseRef = ref;
            _verseLoading = false;
            _verseError = false;
          });
          DailyVerseService.syncIfNeeded(force: true);
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    _loadOfflineVerse();
  }

  String? _extractDailyVerseReference(Map<String, dynamic> data) {
    final refRaw = data['reference'];
    if (refRaw is Map) {
      final ref = Map<String, dynamic>.from(refRaw);
      final book = (ref['book_name'] ?? ref['book'])?.toString().trim() ?? '';
      final chapter = ref['chapter']?.toString().trim() ?? '';
      final verse = ref['verse']?.toString().trim() ?? '';
      if (book.isNotEmpty && chapter.isNotEmpty && verse.isNotEmpty) {
        return '$book $chapter:$verse';
      }
      if (book.isNotEmpty && chapter.isNotEmpty) {
        return '$book $chapter';
      }
      if (book.isNotEmpty) return book;
    }

    if (refRaw is String && refRaw.trim().isNotEmpty) {
      return refRaw.trim();
    }

    final book =
        (data['book'] ?? data['book_name'])?.toString().trim() ?? '';
    final chapter = data['chapter']?.toString().trim() ?? '';
    final verse =
        (data['verse'] ?? data['verse_number'])?.toString().trim() ?? '';

    if (book.isNotEmpty && chapter.isNotEmpty && verse.isNotEmpty) {
      return '$book $chapter:$verse';
    }
    if (book.isNotEmpty && chapter.isNotEmpty) {
      return '$book $chapter';
    }
    if (book.isNotEmpty) return book;
    return null;
  }

  void _loadOfflineVerse() {
    final fallbackVerses = [
      {
        'text':
            'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.',
        'ref': 'John 3:16'
      },
      {
        'text':
            'I can do all things through Christ which strengtheneth me.',
        'ref': 'Philippians 4:13'
      },
      {
        'text': 'The Lord is my shepherd; I shall not want.',
        'ref': 'Psalm 23:1'
      },
      {
        'text':
            'Trust in the Lord with all thine heart; and lean not unto thine own understanding.',
        'ref': 'Proverbs 3:5'
      },
      {
        'text':
            'And we know that all things work together for good to them that love God.',
        'ref': 'Romans 8:28'
      },
      {
        'text':
            'Be strong and of a good courage; be not afraid, neither be thou dismayed: for the Lord thy God is with thee whithersoever thou goest.',
        'ref': 'Joshua 1:9'
      },
      {
        'text':
            'Come unto me, all ye that labour and are heavy laden, and I will give you rest.',
        'ref': 'Matthew 11:28'
      },
    ];

    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(startOfYear).inDays + 1;
    final v = fallbackVerses[dayOfYear % fallbackVerses.length];

    setState(() {
      _dailyVerse = v['text'];
      _dailyVerseRef = v['ref'];
      _verseLoading = false;
      _verseError = false;
    });
  }

  Future<void> _forceRefreshVerse() async {
    if (_refreshingVerse) return;
    setState(() => _refreshingVerse = true);

    try {
      final response = await ApiService.get('/verses/daily');
      if (!mounted) return;

      if (response.isSuccess && response.asMap != null) {
        final data = response.asMap!;
        final text =
            (data['text'] ?? data['verse_text'])?.toString().trim() ?? '';
        final ref = _extractDailyVerseReference(data);

        if (text.isNotEmpty) {
          setState(() {
            _dailyVerse = text;
            _dailyVerseRef = ref;
            _verseError = false;
          });
          DailyVerseService.syncIfNeeded(force: true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verse refreshed!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh verse. Check your connection.'),
          backgroundColor: AppTheme.errorRed,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh verse. Check your connection.'),
          backgroundColor: AppTheme.errorRed,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshingVerse = false);
      }
    }
  }

  Map<String, String?> _parseReferenceParts(String reference) {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) {
      return {
        'book': null,
        'chapter': null,
        'verse': null,
      };
    }

    final match = RegExp(r'^(.+?)\s+(\d+)(?::(\d+))?$').firstMatch(trimmed);
    if (match == null) {
      return {
        'book': trimmed,
        'chapter': null,
        'verse': null,
      };
    }

    return {
      'book': match.group(1)?.trim(),
      'chapter': match.group(2)?.trim(),
      'verse': match.group(3)?.trim(),
    };
  }

  Future<String?> _showShareLanguagePicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Share Daily Verse',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.primaryBlue,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
                child: const Text(
                  'EN',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'English',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                'Share verse in English',
                style: TextStyle(
                  color: isDark ? Colors.white60 : AppTheme.textSecondary,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'english'),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.accentGold.withOpacity(0.15),
                child: const Text(
                  'YO',
                  style: TextStyle(
                    color: AppTheme.accentGoldDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'Yoruba',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                'Share verse in Yoruba',
                style: TextStyle(
                  color: isDark ? Colors.white60 : AppTheme.textSecondary,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'yoruba'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<_ShareVersePayload?> _buildShareVersePayload(String language) async {
    final englishText = _dailyVerse?.trim() ?? '';
    final englishRef = _dailyVerseRef?.trim() ?? '';

    if (englishText.isEmpty) return null;

    _ShareVersePayload fallbackEnglish([String? notice]) {
      return _ShareVersePayload(
        verseText: englishText,
        referenceText: englishRef,
        shareLabel: 'Verse of the Day',
        flyerTitle: 'BIBLE VERSE OF THE DAY',
        notice: notice,
      );
    }

    if (language != 'yoruba') {
      return fallbackEnglish();
    }

    final parts = _parseReferenceParts(englishRef);
    final englishBook = parts['book']?.trim() ?? '';
    final chapter = parts['chapter']?.trim() ?? '';
    final verse = parts['verse']?.trim() ?? '';

    if (englishBook.isEmpty || chapter.isEmpty || verse.isEmpty) {
      return fallbackEnglish(
        'Yoruba translation unavailable for this verse. Shared English version instead.',
      );
    }

    final yorubaBook = _englishToYorubaBookNames[englishBook];
    if (yorubaBook == null || yorubaBook.trim().isEmpty) {
      return fallbackEnglish(
        'Yoruba translation unavailable for this verse. Shared English version instead.',
      );
    }

    final loaded = await BibleLoaderService.ensureBiblesLoaded();
    if (!loaded) {
      return fallbackEnglish(
        'Could not load Yoruba Bible right now. Shared English version instead.',
      );
    }

    final yorubaText =
        BibleLoaderService.getVerse('yoruba', yorubaBook, chapter, verse)
            ?.trim() ??
        '';

    if (yorubaText.isEmpty) {
      return fallbackEnglish(
        'Yoruba translation unavailable for this verse. Shared English version instead.',
      );
    }

    return _ShareVersePayload(
      verseText: yorubaText,
      referenceText: '$yorubaBook $chapter:$verse',
      shareLabel: 'Ẹsẹ Bibeli ti Ọjọ́',
      flyerTitle: 'ẸSẸ BIBELI TI ỌJỌ́',
    );
  }

  Future<void> _shareAsFlyer() async {
    if (_dailyVerse == null || _dailyVerse!.trim().isEmpty) return;
    if (_sharingFlyer) return;

    final selectedLanguage = await _showShareLanguagePicker();
    if (!mounted || selectedLanguage == null) return;

    setState(() => _sharingFlyer = true);

    try {
      final payload = await _buildShareVersePayload(selectedLanguage);
      if (payload == null) {
        throw Exception('No verse available to share.');
      }

      final bgFile = _backgroundFileForToday();
      await precacheImage(
        AssetImage('assets/images/bible_bg/$bgFile'),
        context,
      );

      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(1200, 800),
            devicePixelRatio: 1.0,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: Colors.transparent,
              child: _buildFlyerWidget(
                verse: payload.verseText,
                ref: payload.referenceText,
                headerTitle: payload.flyerTitle,
              ),
            ),
          ),
        ),
        delay: const Duration(milliseconds: 200),
        pixelRatio: 2.0,
        targetSize: const Size(1200, 800),
        context: context,
      );

      final shareText = payload.referenceText.trim().isNotEmpty
          ? '${payload.shareLabel} - ${payload.referenceText}'
          : '${payload.shareLabel} from NGGC Sunday School App';

      if (kIsWeb) {
        downloadBytesAsFile(
          imageBytes,
          'nggc_daily_verse_flyer.png',
          'image/png',
        );

        final clipText = payload.referenceText.trim().isNotEmpty
            ? '"${payload.verseText}"\n- ${payload.referenceText}\n\nFrom NGGC Sunday School App'
            : '"${payload.verseText}"\n\nFrom NGGC Sunday School App';

        await Clipboard.setData(ClipboardData(text: clipText));

        if (!mounted) return;

        final successMessage = payload.notice == null
            ? 'Flyer downloaded! Verse copied to clipboard. Share anywhere!'
            : 'Flyer downloaded! Verse copied to clipboard. ${payload.notice!}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        final file = await saveBytesToTempFile(
          imageBytes,
          'nggc_daily_verse_flyer.png',
        );

        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
          subject: payload.shareLabel,
        );

        if (payload.notice != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(payload.notice!),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share verse flyer. Please try again.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sharingFlyer = false);
      }
    }
  }

  String _flyerFullDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildFlyerWidget({
    required String verse,
    required String ref,
    required String headerTitle,
  }) {
    final now = DateTime.now();

    final bgFile = _backgroundFileForToday();
    final bgImagePath = 'assets/images/bible_bg/$bgFile';
    final baseOpacity = _imageOverlayOpacity[bgFile] ?? 0.55;

    return SizedBox(
      width: 1200,
      height: 800,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            bgImagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF0D1B5E),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(baseOpacity * 0.6),
                  Colors.black.withOpacity(baseOpacity * 0.9),
                  Colors.black.withOpacity(0.90),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: AutoSizeText(
                  headerTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  minFontSize: 10,
                  maxFontSize: 16,
                  style: TextStyle(
                    color: const Color(0xFFFFD700).withOpacity(0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.5,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    _flyerFullDate(now),
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(70, 25, 70, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: AutoSizeText(
                            verse,
                            textAlign: TextAlign.center,
                            maxLines: 8,
                            minFontSize: 22,
                            maxFontSize: 68,
                            stepGranularity: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 62,
                              fontWeight: FontWeight.w900,
                              height: 1.35,
                              letterSpacing: 0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 16,
                                  offset: Offset(0, 3),
                                ),
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 24,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (ref.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 2.5,
                            ),
                          ),
                          child: Text(
                            ref,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.88),
                  border: const Border(
                    top: BorderSide(
                      color: Color(0xFFFFD700),
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/nggc-logo.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.church,
                            color: Color(0xFF0D1B5E),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEW GENERATION GOSPEL CHURCH',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'nggcwebsite.vercel.app',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadTodayLesson() async {
    setState(() => _lessonLoading = true);

    try {
      final user = ref.read(currentUserProvider);
      final preferredLang =
          (user?.preferredLanguage ?? 'english').toLowerCase();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final daysSinceSunday =
          today.weekday == DateTime.sunday ? 0 : today.weekday;
      final targetSunday = today.subtract(Duration(days: daysSinceSunday));
      final targetKey = _dateKey(targetSunday);

      final allManuals = ManualsLoaderService.getAllManuals();
      Map<String, dynamic>? found;

      for (final manual in allManuals) {
        final manualLang =
            manual['language']?.toString().toLowerCase() ?? 'english';
        if (manualLang != preferredLang) continue;
        final lessons =
            ManualsLoaderService.getLessonsForManual(manual['id'].toString());
        for (final l in lessons) {
          final ld = l['lesson_date']?.toString() ?? '';
          if (_dateKey(_tryParseDate(ld)) == targetKey) {
            found = l;
            break;
          }
        }
        if (found != null) break;
      }

      if (found == null && preferredLang != 'english') {
        for (final manual in allManuals) {
          final manualLang =
              manual['language']?.toString().toLowerCase() ?? 'english';
          if (manualLang != 'english') continue;
          final lessons =
              ManualsLoaderService.getLessonsForManual(manual['id'].toString());
          for (final l in lessons) {
            final ld = l['lesson_date']?.toString() ?? '';
            if (_dateKey(_tryParseDate(ld)) == targetKey) {
              found = l;
              break;
            }
          }
          if (found != null) break;
        }
      }

      found ??=
          _findMostRecentPastLesson(allManuals, preferredLang, targetSunday);

      if (found == null && preferredLang != 'english') {
        found = _findMostRecentPastLesson(allManuals, 'english', targetSunday);
      }

      if (!mounted) return;
      setState(() {
        _todayLesson = found;
        _todayLessonDate = found?['lesson_date']?.toString();
        _lessonLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _lessonLoading = false);
    }
  }

  Map<String, dynamic>? _findMostRecentPastLesson(
    List<Map<String, dynamic>> allManuals,
    String language,
    DateTime targetSunday,
  ) {
    Map<String, dynamic>? best;
    DateTime? bestDate;
    for (final manual in allManuals) {
      final manualLang =
          manual['language']?.toString().toLowerCase() ?? 'english';
      if (manualLang != language) continue;
      final lessons =
          ManualsLoaderService.getLessonsForManual(manual['id'].toString());
      for (final l in lessons) {
        final ld = l['lesson_date']?.toString() ?? '';
        final d = _tryParseDate(ld);
        if (d == null) continue;
        if (d.isAfter(targetSunday)) continue;
        if (bestDate == null || d.isAfter(bestDate)) {
          best = l;
          bestDate = d;
        }
      }
    }
    return best;
  }

  String _dateKey(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DateTime? _tryParseDate(String s) {
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _formatSundayLabel(String isoDate) {
    final d = _tryParseDate(isoDate);
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    if (target == today) return 'Today';
    return 'Sunday, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _openTodayLesson() {
    if (_todayLesson == null) return;
    final id = _todayLesson!['id']?.toString() ?? '';
    final title = _todayLesson!['title']?.toString() ?? "Today's Lesson";
    if (id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonDetailScreen(lessonId: id, title: title),
      ),
    );
  }

  Future<void> _logout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.primaryBlue,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppTheme.primaryBlue,
        onRefresh: () async {
          await _loadDailyVerse();
          await _loadTodayLesson();
          await _loadTodayReading();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(user?.firstName ?? 'Member', isAdmin),
              const SizedBox(height: 20),
              _buildSectionTitle('Daily Verse'),
              _buildDailyVerseCard(),
              const SizedBox(height: 20),
              _buildSectionTitle("Today's Reading"),
              _buildReadingPlanCard(),
              const SizedBox(height: 20),
              _buildSectionTitle('Quick Access'),
              _buildFeatureGrid(),
              const SizedBox(height: 20),
              _buildSectionTitle("Today's Lesson"),
              _buildTodayLessonCard(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingPlanCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withOpacity(isDark ? 0.20 : 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _readingLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue,
                  strokeWidth: 2,
                ),
              ),
            )
          : _todayReading == null
              ? _buildReadingUnavailable(isDark)
              : _todayReading!['is_rest_day'] == true
                  ? _buildRestDayCard(isDark)
                  : _buildReadingContent(isDark),
    );
  }

  Widget _buildReadingUnavailable(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            color: isDark ? Colors.white38 : AppTheme.textHint,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reading plan unavailable.\nPull down to retry.',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white70 : AppTheme.primaryBlue,
            ),
            onPressed: _loadTodayReading,
          ),
        ],
      ),
    );
  }

  Widget _buildRestDayCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(isDark ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.self_improvement,
              color: AppTheme.accentGoldDark,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rest Day 🌿',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No scheduled reading today.\nTake time to reflect and pray.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingContent(bool isDark) {
    final book = _todayReading!['book_english_name']?.toString() ?? '';
    final chapter = _todayReading!['chapter']?.toString() ?? '';
    final theme = _todayReading!['theme']?.toString() ?? '';
    final doy = _todayReading!['day_of_year']?.toString() ?? '';
    final isRead = _todayReading!['is_read'] == true;

    return InkWell(
      onTap: _openReader,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  color: AppTheme.accentGoldDark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Day $doy of 365',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentGoldDark,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                if (isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Read',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(isDark ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book,
                    color: AppTheme.primaryBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$book $chapter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (theme.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          theme,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white38 : AppTheme.textHint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/nggc-logo.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.church, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          const Text(
            'NGGC',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.support_agent, color: Colors.white, size: 24),
          tooltip: 'Contact Support',
          onPressed: () => showSupportSheet(context),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70, size: 22),
          tooltip: 'Sign Out',
          onPressed: _logout,
        ),
      ],
    );
  }

  Widget _buildHeaderBanner(String firstName, bool isAdmin) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting,',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            firstName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WELCOME TO NGGC',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentGold,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'SEARCH THE SCRIPTURE',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.accentGold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentGold),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppTheme.textPrimary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDailyVerseCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: _verseLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          : _verseError
              ? _buildVerseError()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          color: AppTheme.accentGold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Verse of the Day',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentGold,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        _refreshingVerse
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppTheme.accentGold,
                                  strokeWidth: 2,
                                ),
                              )
                            : InkWell(
                                onTap: _forceRefreshVerse,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.refresh,
                                    color: AppTheme.accentGold,
                                    size: 16,
                                  ),
                                ),
                              ),
                        const SizedBox(width: 8),
                        _sharingFlyer
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppTheme.accentGold,
                                  strokeWidth: 2,
                                ),
                              )
                            : InkWell(
                                onTap: _shareAsFlyer,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.share,
                                    color: AppTheme.accentGold,
                                    size: 16,
                                  ),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '"${_dailyVerse ?? ''}"',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (_dailyVerseRef != null &&
                        _dailyVerseRef!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '- $_dailyVerseRef',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildVerseError() {
    return Row(
      children: [
        const Icon(Icons.wifi_off, color: Colors.white60, size: 18),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Could not load daily verse.\nPull down to retry.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
          onPressed: _loadDailyVerse,
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    final features = [
      _FeatureItem(
        icon: Icons.menu_book,
        label: 'Bible',
        subtitle: 'Read Scripture',
        color: const Color(0xFF1565C0),
        onTap: () => _navigateTo(const BibleLanguageScreen()),
      ),
      _FeatureItem(
        icon: Icons.import_contacts,
        label: 'Manuals',
        subtitle: 'Sunday School Books',
        color: const Color(0xFF2E7D32),
        onTap: () => _navigateTo(const ManualsScreen()),
      ),
      _FeatureItem(
        icon: Icons.campaign_outlined,
        label: 'Announcements',
        subtitle: 'Church Updates',
        color: const Color(0xFFE65100),
        onTap: () => _navigateTo(const AnnouncementsScreen()),
      ),
      _FeatureItem(
        icon: Icons.event_outlined,
        label: 'Events',
        subtitle: 'Upcoming Events',
        color: const Color(0xFF6A1B9A),
        onTap: () => _navigateTo(const EventsScreen()),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: features.map(_buildFeatureCard).toList(),
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(isDark ? 0.25 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : item.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLessonCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _lessonLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue,
                  strokeWidth: 2,
                ),
              ),
            )
          : _todayLesson == null
              ? _buildNoLesson()
              : _buildLessonContent(_todayLesson!),
    );
  }

  Widget _buildNoLesson() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? Colors.white38 : AppTheme.textHint,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No lesson found for this Sunday.\nCheck the Manuals section for all lessons.',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonContent(Map<String, dynamic> lesson) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = lesson['title']?.toString() ?? "Today's Lesson";
    final topic = lesson['topic']?.toString() ?? '';
    final language = lesson['language']?.toString() ?? 'english';
    final sundayLabel =
        _todayLessonDate != null ? _formatSundayLabel(_todayLessonDate!) : '';

    return InkWell(
      onTap: _openTodayLesson,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(isDark ? 0.25 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.import_contacts,
                color: AppTheme.primaryBlue,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topic.isNotEmpty && topic != title) ...[
                    const SizedBox(height: 4),
                    Text(
                      topic,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildChip(
                        language[0].toUpperCase() + language.substring(1),
                        AppTheme.primaryBlue,
                      ),
                      if (sundayLabel.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: _buildChip(
                            sundayLabel,
                            AppTheme.accentGoldDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : AppTheme.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

class _ShareVersePayload {
  final String verseText;
  final String referenceText;
  final String shareLabel;
  final String flyerTitle;
  final String? notice;

  const _ShareVersePayload({
    required this.verseText,
    required this.referenceText,
    required this.shareLabel,
    required this.flyerTitle,
    this.notice,
  });
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
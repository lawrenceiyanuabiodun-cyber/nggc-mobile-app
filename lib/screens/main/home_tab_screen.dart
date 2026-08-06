import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/manuals_loader_service.dart';
import '../../theme/app_theme.dart';
import '../announcements/announcements_screen.dart';
import '../bible/bible_language_screen.dart';
import '../events/events_screen.dart';
import '../lessons/lesson_detail_screen.dart';
import '../manuals/manuals_screen.dart';

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

  final ScreenshotController _screenshotController = ScreenshotController();

  Map<String, dynamic>? _todayLesson;
  String? _todayLessonDate;
  bool _lessonLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyVerse();
    _loadTodayLesson();
  }

  Future<void> _loadDailyVerse() async {
    setState(() {
      _verseLoading = true;
      _verseError = false;
    });

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
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    _loadOfflineVerse();
  }

  String? _extractDailyVerseReference(Map<String, dynamic> data) {
    // Handle when reference is a nested object
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

    // Handle when reference is a plain string
    if (refRaw is String && refRaw.trim().isNotEmpty) {
      return refRaw.trim();
    }

    // Handle flat fields
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

    // Use day_of_year so all users see same verse each day (offline fallback)
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

  Future<void> _shareAsFlyer() async {
    if (_dailyVerse == null || _dailyVerse!.trim().isEmpty) return;
    if (_sharingFlyer) return;

    setState(() => _sharingFlyer = true);

    try {
      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: _buildFlyerWidget(),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 1.0,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nggc_daily_verse_flyer.png');
      await file.writeAsBytes(imageBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _dailyVerseRef != null && _dailyVerseRef!.trim().isNotEmpty
            ? 'Verse of the Day - ${_dailyVerseRef!}'
            : 'Verse of the Day from NGGC Sunday School App',
        subject: 'Verse of the Day',
      );
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

  Widget _buildFlyerWidget() {
    final verse = _dailyVerse?.trim() ?? '';
    final ref = _dailyVerseRef?.trim() ?? '';
    final now = DateTime.now();

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dateLabel = '${now.day} ${months[now.month - 1]} ${now.year}';

    final backgrounds = [
      'assets/images/bible_bg/bible_bg1.jpg',
      'assets/images/bible_bg/bible_bg3.jpg',
      'assets/images/bible_bg/bible_bg5.jpg',
      'assets/images/bible_bg/bible_bg7.jpg',
      'assets/images/bible_bg/bible_bg9.jpg',
      'assets/images/bible_bg/bible_bg10.jpg',
      'assets/images/bible_bg/bible_bg12.jpg',
      'assets/images/bible_bg/bible_bg14.jpg',
    ];
    final startOfYear = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(startOfYear).inDays + 1;
    final bgImage = backgrounds[dayOfYear % backgrounds.length];

    return SizedBox(
      width: 1080,
      height: 1080,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Bible image background
          Image.asset(
            bgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF0D1B5E),
            ),
          ),
          // Dark gradient overlay for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.75),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(60, 50, 60, 50),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // TOP - date + label
                Column(
                  children: [
                    Text(
                      dateLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 100,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'VERSE OF THE DAY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // MIDDLE - verse + reference
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      verse,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 20,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    if (ref.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 14,
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
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // BOTTOM - logo + church name
                Column(
                  children: [
                    Container(
                      width: 200,
                      height: 1,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/nggc-logo.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.church,
                            color: Color(0xFF0D1B5E),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'NEW GENERATION GOSPEL CHURCH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'nggcwebsite.netlify.app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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
              const Text(
                'Welcome to Sunday School',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.accentGold,
                  letterSpacing: 0.5,
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    color:
                        isDark ? Colors.white60 : AppTheme.textSecondary,
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
                        color: isDark
                            ? Colors.white60
                            : AppTheme.textSecondary,
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
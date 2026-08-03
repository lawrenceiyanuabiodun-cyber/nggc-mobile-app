import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_dashboard_screen.dart';
import '../announcements/announcements_screen.dart';
import '../bible/bible_language_screen.dart';
import '../events/events_screen.dart';
import '../lessons/lessons_screen.dart';
import '../profile/profile_screen.dart';

// ─────────────────────────────────────────────────────────
// HomeScreen
// Main dashboard — shows Admin tab if user is admin
// ─────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  String? _dailyVerse;
  String? _dailyVerseRef;
  bool _verseLoading = true;
  bool _verseError = false;

  Map<String, dynamic>? _todayLesson;
  bool _lessonLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyVerse();
    _loadTodayLesson();
  }

  Future<void> _loadDailyVerse() async {
    setState(() { _verseLoading = true; _verseError = false; });

    // Try API first
    try {
      final response = await ApiService.get('/verses/daily');
      if (!mounted) return;
      if (response.isSuccess && response.asMap != null) {
        final data = response.asMap!;
        setState(() {
          _dailyVerse = data['text']?.toString() ??
              data['verse_text']?.toString() ?? '';
          _dailyVerseRef =
              '${data['book'] ?? data['book_name'] ?? ''} ${data['chapter'] ?? ''}:${data['verse'] ?? ''}';
          _verseLoading = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback: use a random verse from offline Bible
    if (!mounted) return;
    _loadOfflineVerse();
  }

  void _loadOfflineVerse() {
    // Curated inspirational verses (offline fallback)
    final fallbackVerses = [
      {'text': 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.', 'ref': 'John 3:16'},
      {'text': 'I can do all things through Christ which strengtheneth me.', 'ref': 'Philippians 4:13'},
      {'text': 'The Lord is my shepherd; I shall not want.', 'ref': 'Psalm 23:1'},
      {'text': 'Trust in the Lord with all thine heart; and lean not unto thine own understanding.', 'ref': 'Proverbs 3:5'},
      {'text': 'And we know that all things work together for good to them that love God.', 'ref': 'Romans 8:28'},
      {'text': 'Be strong and of a good courage; be not afraid, neither be thou dismayed: for the Lord thy God is with thee whithersoever thou goest.', 'ref': 'Joshua 1:9'},
      {'text': 'Come unto me, all ye that labour and are heavy laden, and I will give you rest.', 'ref': 'Matthew 11:28'},
    ];
    final day = DateTime.now().day;
    final v = fallbackVerses[day % fallbackVerses.length];
    setState(() {
      _dailyVerse = v['text'];
      _dailyVerseRef = v['ref'];
      _verseLoading = false;
      _verseError = false;
    });
  }

  void _shareDailyVerse() {
    if (_dailyVerse == null || _dailyVerse!.isEmpty) return;
    final ref = _dailyVerseRef ?? '';
    Share.share(
      '"${_dailyVerse!}"\n\n- $ref\n\nShared from NGGC Sunday School App',
      subject: 'Verse of the Day',
    );
  }

  Future<void> _loadTodayLesson() async {
    // Offline-first: show cache immediately
    final cached = CacheService.getTodayLesson();
    if (cached != null) {
      setState(() { _todayLesson = cached; _lessonLoading = false; });
    } else {
      setState(() => _lessonLoading = true);
    }

    // Try to refresh from API
    try {
      final response = await ApiService.get('/today');
      if (!mounted) return;
      if (response.isSuccess && response.asMap != null) {
        await CacheService.saveTodayLesson(response.asMap!);
        setState(() { _todayLesson = response.asMap; _lessonLoading = false; });
        return;
      }
    } catch (_) {}

    // API failed - fallback to any cached lessons
    if (!mounted) return;
    if (_todayLesson == null) {
      final allCached = CacheService.getLessons();
      if (allCached != null && allCached.isNotEmpty) {
        // Pick lesson based on today's date
        final day = DateTime.now().day;
        final lesson = allCached[day % allCached.length];
        if (lesson is Map<String, dynamic>) {
          setState(() { _todayLesson = lesson; _lessonLoading = false; });
          return;
        }
      }
      setState(() => _lessonLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
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

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: _buildAppBar(user?.firstName ?? 'Member'),
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
      bottomNavigationBar: _buildBottomNav(isAdmin),
    );
  }

  PreferredSizeWidget _buildAppBar(String firstName) {
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
                fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.white),
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
          Text('$greeting,',
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(firstName,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Welcome to Sunday School',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.accentGold, letterSpacing: 0.5)),
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
                    '⭐ Admin',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGold),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: 0.3)),
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
                    color: Colors.white, strokeWidth: 2),
              ))
          : _verseError
              ? _buildVerseError()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book_outlined,
                            color: AppTheme.accentGold, size: 18),
                        const SizedBox(width: 8),
                        const Text('Verse of the Day',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.accentGold,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1)),
                        const Spacer(),
                        InkWell(
                          onTap: _shareDailyVerse,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.share,
                                color: AppTheme.accentGold, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('"${_dailyVerse ?? ''}"',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            height: 1.6,
                            fontStyle: FontStyle.italic)),
                    if (_dailyVerseRef != null &&
                        _dailyVerseRef!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('— $_dailyVerseRef',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.accentGold,
                                fontWeight: FontWeight.w600)),
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
          child: Text('Could not load daily verse.\nPull down to retry.',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
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
        icon: Icons.school_outlined,
        label: 'Lessons',
        subtitle: 'Study Materials',
        color: const Color(0xFF2E7D32),
        onTap: () => _navigateTo(const LessonsScreen()),
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
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.12),
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
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: item.color)),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLessonCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                    color: AppTheme.primaryBlue, strokeWidth: 2),
              ))
          : _todayLesson == null
              ? _buildNoLesson()
              : _buildLessonContent(_todayLesson!),
    );
  }

  Widget _buildNoLesson() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.textHint, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No lesson scheduled for today.\nCheck back tomorrow!',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonContent(Map<String, dynamic> lesson) {
    final title = lesson['title']?.toString() ??
        lesson['lesson_title']?.toString() ?? "Today's Lesson";
    final topic = lesson['topic']?.toString() ?? '';
    final language = lesson['language']?.toString() ?? 'english';
    final quarter = lesson['quarter']?.toString() ?? '';

    return InkWell(
      onTap: () => _navigateTo(const LessonsScreen()),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school,
                  color: AppTheme.primaryBlue, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (topic.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(topic,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildChip(
                        language[0].toUpperCase() + language.substring(1),
                        AppTheme.primaryBlue,
                      ),
                      if (quarter.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildChip(quarter, AppTheme.accentGoldDark),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Bottom Nav — shows Admin tab for admins ────────────
  Widget _buildBottomNav(bool isAdmin) {
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_outlined),
        activeIcon: Icon(Icons.menu_book),
        label: 'Bible',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.school_outlined),
        activeIcon: Icon(Icons.school),
        label: 'Lessons',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
    ];

    return BottomNavigationBar(
      currentIndex: _currentIndex.clamp(0, items.length - 1),
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) _navigateTo(const BibleLanguageScreen());
        if (index == 2) _navigateTo(const LessonsScreen());
        if (index == 3) _navigateTo(const ProfileScreen());
        if (index == 4 && isAdmin) _navigateTo(const AdminDashboardScreen());
      },
      selectedItemColor: AppTheme.primaryBlue,
      unselectedItemColor: AppTheme.textHint,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 10,
      items: items,
    );
  }
}

// ── Feature Item Model ─────────────────────────────────
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




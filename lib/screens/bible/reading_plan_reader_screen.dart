import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/bible_loader_service.dart';
import '../../services/reading_plan_service.dart';
import '../../theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────
/// ReadingPlanReaderScreen
/// Full-screen chapter reader for the daily reading plan.
/// Loads chapter text from the bundled Bible (offline-ready)
/// and lets user mark it as read.
/// ─────────────────────────────────────────────────────────
class ReadingPlanReaderScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> reading;

  const ReadingPlanReaderScreen({
    super.key,
    required this.reading,
  });

  @override
  ConsumerState<ReadingPlanReaderScreen> createState() =>
      _ReadingPlanReaderScreenState();
}

class _ReadingPlanReaderScreenState
    extends ConsumerState<ReadingPlanReaderScreen> {
  bool _loading = true;
  bool _marking = false;
  bool _isRead = false;
  List<_VerseRow> _verses = [];
  String _language = 'english';

  @override
  void initState() {
    super.initState();
    _isRead = widget.reading['is_read'] == true;
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    setState(() => _loading = true);

    try {
      await BibleLoaderService.ensureBiblesLoaded();

      final book = widget.reading['book_english_name']?.toString() ?? '';
      final chapter = widget.reading['chapter']?.toString() ?? '';

      if (book.isEmpty || chapter.isEmpty) {
        setState(() {
          _verses = [];
          _loading = false;
        });
        return;
      }

      final verses = <_VerseRow>[];
      // Loop from verse 1 upward until BibleLoader returns null.
      // Cap at 200 to be safe (longest chapter is Psalm 119 with 176 verses).
      for (int v = 1; v <= 200; v++) {
        final text = BibleLoaderService.getVerse(
          _language,
          book,
          chapter,
          v.toString(),
        );
        if (text == null || text.trim().isEmpty) {
          if (v == 1) continue; // some Bibles start at 0
          break;
        }
        verses.add(_VerseRow(number: v, text: text.trim()));
      }

      if (!mounted) return;
      setState(() {
        _verses = verses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verses = [];
        _loading = false;
      });
    }
  }

  Future<void> _toggleLanguage() async {
    setState(() {
      _language = _language == 'english' ? 'yoruba' : 'english';
    });
    await _loadChapter();
  }

  Future<void> _markAsRead() async {
    if (_isRead || _marking) return;

    final doy = widget.reading['day_of_year'] as int?;
    if (doy == null || doy < 1) return;

    setState(() => _marking = true);

    final year = DateTime.now().year;
    final ok = await ReadingPlanService.markRead(
      dayOfYear: doy,
      year: year,
    );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _isRead = true;
        _marking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chapter marked as read! 🔥'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _marking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark as read. Please try again.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight;

    final book = widget.reading['book_english_name']?.toString() ?? '';
    final bookYoruba = widget.reading['book_yoruba_name']?.toString() ?? '';
    final chapter = widget.reading['chapter']?.toString() ?? '';
    final theme = widget.reading['theme']?.toString() ?? '';
    final doy = widget.reading['day_of_year']?.toString() ?? '';

    final displayBook = _language == 'yoruba' && bookYoruba.isNotEmpty
        ? bookYoruba
        : book;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        title: Text(
          "Today's Reading",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: _language == 'english'
                ? 'Switch to Yoruba'
                : 'Switch to English',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _language == 'english' ? 'EN' : 'YO',
                style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            onPressed: _toggleLanguage,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(displayBook, chapter, theme, doy, isDark),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                  )
                : _verses.isEmpty
                    ? _buildEmpty(isDark)
                    : _buildVerseList(isDark),
          ),
          _buildBottomBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(
    String book,
    String chapter,
    String theme,
    String doy,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined,
                  color: AppTheme.accentGold, size: 16),
              const SizedBox(width: 6),
              Text(
                'Day $doy of 365',
                style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (_isRead)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.greenAccent, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Read',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$book $chapter',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (theme.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              theme,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: isDark ? Colors.white38 : AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load chapter text.\nMake sure the Bible files are downloaded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: _loadChapter,
          ),
        ],
      ),
    );
  }

  Widget _buildVerseList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      itemCount: _verses.length,
      itemBuilder: (context, index) {
        final v = _verses[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
              children: [
                TextSpan(
                  text: '${v.number} ',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                TextSpan(text: v.text),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            icon: _marking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    _isRead ? Icons.check_circle : Icons.check_circle_outline,
                    color: Colors.white,
                  ),
            label: Text(
              _isRead ? 'Read Today ✓' : 'Mark as Read',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isRead ? Colors.green : AppTheme.primaryBlue,
              disabledBackgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isRead ? null : _markAsRead,
          ),
        ),
      ),
    );
  }
}

class _VerseRow {
  final int number;
  final String text;
  const _VerseRow({required this.number, required this.text});
}
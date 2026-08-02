import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/bible_loader_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import 'bible_saved_verses_screen.dart';

// ─────────────────────────────────────────────────────────
// BibleVersesScreen
// Displays all verses for a chapter
// Supports: highlight, share, copy, bookmark, font size
// ─────────────────────────────────────────────────────────
class BibleVersesScreen extends StatefulWidget {
  final String language;
  final String bookName;
  final int bookNumber;
  final String chapter;
  final int totalChapters;

  const BibleVersesScreen({
    super.key,
    required this.language,
    required this.bookName,
    required this.bookNumber,
    required this.chapter,
    required this.totalChapters,
  });

  @override
  State<BibleVersesScreen> createState() => _BibleVersesScreenState();
}

class _BibleVersesScreenState extends State<BibleVersesScreen> {
  List<MapEntry<String, String>> _verseList = [];
  bool _loading = true;
  int? _highlightedVerse;
  String? _highlightedText;
  double _fontSize = 16.0;
  late String _currentChapter;
  final ScrollController _scrollController = ScrollController();

  Color get _accentColor => widget.bookNumber <= 39
      ? const Color(0xFF6A1B9A)
      : const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _loadVerses();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final size = await PreferencesService.getFontSize();
    if (mounted) setState(() { _fontSize = size; });
  }

  void _changeFontSize(double delta) {
    final newSize = (_fontSize + delta).clamp(12.0, 26.0);
    setState(() => _fontSize = newSize);
    PreferencesService.setFontSize(newSize);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadVerses() {
    setState(() => _loading = true);

    final verses = BibleLoaderService.getVerses(
      widget.language,
      widget.bookName,
      _currentChapter,
    );

    final sorted = verses.entries.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.key) ?? 0;
        final bNum = int.tryParse(b.key) ?? 0;
        return aNum.compareTo(bNum);
      });

    setState(() {
      _verseList = sorted;
      _loading = false;
      _highlightedVerse = null;
      _highlightedText = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _prevChapter() {
    final current = int.tryParse(_currentChapter) ?? 1;
    if (current <= 1) return;
    setState(() => _currentChapter = '${current - 1}');
    _loadVerses();
  }

  void _nextChapter() {
    final current = int.tryParse(_currentChapter) ?? 1;
    if (current >= widget.totalChapters) return;
    setState(() => _currentChapter = '${current + 1}');
    _loadVerses();
  }

  // ── Copy verse ─────────────────────────────────────────
  void _copyVerse(String verseNum, String text) {
    final ref = '${widget.bookName} $_currentChapter:$verseNum';
    Clipboard.setData(ClipboardData(text: '"$text" — $ref'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$ref copied'),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Share verse ────────────────────────────────────────
  void _shareVerse(String verseNum, String text) {
    final ref = '${widget.bookName} $_currentChapter:$verseNum';
    Share.share(
      '"$text"\n\n— $ref\n\nShared from NGGC Sunday School App',
      subject: ref,
    );
  }

  // ── Bookmark verse ─────────────────────────────────────
  Future<void> _bookmarkVerse(String verseNum, String text) async {
    final verse = SavedVerse(
      bookName: widget.bookName,
      chapter: _currentChapter,
      verseNum: verseNum,
      text: text,
      language: widget.language,
      savedAt: DateTime.now(),
    );

    final alreadySaved = BibleVerseStorage.isVersesSaved(verse.key);

    if (alreadySaved) {
      await BibleVerseStorage.deleteVerse(verse.key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.bookName} $_currentChapter:$verseNum removed'),
            backgroundColor: AppTheme.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await BibleVerseStorage.saveVerse(verse);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bookmark, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                    '${widget.bookName} $_currentChapter:$verseNum saved!'),
              ],
            ),
            backgroundColor: _accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentNum = int.tryParse(_currentChapter) ?? 1;
    final hasPrev = currentNum > 1;
    final hasNext = currentNum < widget.totalChapters;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        title: Text(
          '${widget.bookName} $_currentChapter',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // View saved verses
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BibleSavedVersesScreen(),
              ),
            ),
            tooltip: 'Saved verses',
          ),
          // Share highlighted verse
          if (_highlightedVerse != null && _highlightedText != null)
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              onPressed: () => _shareVerse(
                '$_highlightedVerse',
                _highlightedText!,
              ),
              tooltip: 'Share verse',
            ),
          // Copy highlighted verse
          if (_highlightedVerse != null && _highlightedText != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20),
              onPressed: () => _copyVerse(
                '$_highlightedVerse',
                _highlightedText!,
              ),
              tooltip: 'Copy verse',
            ),
          // Font size controls
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            onPressed: () => _changeFontSize(-2),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 20),
            onPressed: () => _changeFontSize(2),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : _verseList.isEmpty
              ? _buildEmpty()
              : _buildBody(hasPrev, hasNext),
    );
  }

  Widget _buildBody(bool hasPrev, bool hasNext) {
    return Column(
      children: [
        // Info bar
        Container(
          color: AppTheme.primaryBlue,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            children: [
              Text(
                '${_verseList.length} verses',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const Spacer(),
              if (_highlightedVerse != null)
                const Text(
                  'Tap bookmark • share • copy above',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.accentGold,
                  ),
                )
              else
                Text(
                  widget.language == 'yoruba' ? 'Yoruba' : 'KJV English',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),

        // Verse list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _verseList.length,
            itemBuilder: (context, index) {
              final entry = _verseList[index];
              final verseNum = int.tryParse(entry.key) ?? 0;
              final isHighlighted = _highlightedVerse == verseNum;
              final isSaved = BibleVerseStorage.isVersesSaved(
                '${widget.language}_${widget.bookName}_${_currentChapter}_$verseNum',
              );
              return _buildVerseTile(
                verseNum: verseNum,
                text: entry.value,
                isHighlighted: isHighlighted,
                isSaved: isSaved,
              );
            },
          ),
        ),

        _buildNavBar(hasPrev, hasNext),
      ],
    );
  }

  Widget _buildVerseTile({
    required int verseNum,
    required String text,
    required bool isHighlighted,
    required bool isSaved,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_highlightedVerse == verseNum) {
            _highlightedVerse = null;
            _highlightedText = null;
          } else {
            _highlightedVerse = verseNum;
            _highlightedText = text;
          }
        });
      },
      onLongPress: () {
        _copyVerse('$verseNum', text);
        setState(() {
          _highlightedVerse = verseNum;
          _highlightedText = text;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? _accentColor.withOpacity(0.08)
              : isSaved
                  ? _accentColor.withOpacity(0.03)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isHighlighted
              ? Border.all(color: _accentColor.withOpacity(0.3))
              : isSaved
                  ? Border.all(color: _accentColor.withOpacity(0.15))
                  : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number
            SizedBox(
              width: 28,
              child: Text(
                '$verseNum',
                style: TextStyle(
                  fontSize: _fontSize - 4,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted
                      ? _accentColor
                      : isSaved
                          ? _accentColor.withOpacity(0.5)
                          : AppTheme.textHint,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Verse text
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: isHighlighted
                      ? AppTheme.textPrimary
                      : const Color(0xFF2D2D2D),
                  height: 1.7,
                  fontWeight: isHighlighted
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
            // Action icons on highlight
            if (isHighlighted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 6),
                  // Bookmark
                  GestureDetector(
                    onTap: () => _bookmarkVerse('$verseNum', text),
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_outline,
                      size: 18,
                      color: isSaved
                          ? _accentColor
                          : _accentColor.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share
                  GestureDetector(
                    onTap: () => _shareVerse('$verseNum', text),
                    child: Icon(
                      Icons.share_outlined,
                      size: 16,
                      color: _accentColor.withOpacity(0.7),
                    ),
                  ),
                ],
              )
            // Saved indicator (not highlighted)
            else if (isSaved)
              Icon(
                Icons.bookmark,
                size: 14,
                color: _accentColor.withOpacity(0.4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(bool hasPrev, bool hasNext) {
    final currentNum = int.tryParse(_currentChapter) ?? 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: hasPrev ? _prevChapter : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
              style: TextButton.styleFrom(
                foregroundColor:
                    hasPrev ? _accentColor : AppTheme.textHint,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Ch. $currentNum / ${widget.totalChapters}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: hasNext ? _nextChapter : null,
              icon: const Text('Next'),
              label: const Icon(Icons.chevron_right),
              style: TextButton.styleFrom(
                foregroundColor:
                    hasNext ? _accentColor : AppTheme.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.menu_book_outlined,
              size: 48, color: AppTheme.textHint),
          SizedBox(height: 12),
          Text(
            'No verses found',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap to highlight • Long-press to copy\nBookmark icon to save',
            style: TextStyle(color: AppTheme.textHint, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}




import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/bible_loader_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// BibleVersesScreen
// Displays all verses for a chapter
// Supports: verse highlight, font size, prev/next chapter
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
  double _fontSize = 16.0;
  late String _currentChapter;
  final ScrollController _scrollController = ScrollController();

  // OT = purple, NT = blue
  Color get _accentColor => widget.bookNumber <= 39
      ? const Color(0xFF6A1B9A)
      : const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _loadVerses();
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

    // Sort verses numerically
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
    });

    // Scroll to top on chapter change
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

  // ── Navigate to previous chapter ──────────────────────
  void _prevChapter() {
    final current = int.tryParse(_currentChapter) ?? 1;
    if (current <= 1) return;
    setState(() => _currentChapter = '${current - 1}');
    _loadVerses();
  }

  // ── Navigate to next chapter ───────────────────────────
  void _nextChapter() {
    final current = int.tryParse(_currentChapter) ?? 1;
    if (current >= widget.totalChapters) return;
    setState(() => _currentChapter = '${current + 1}');
    _loadVerses();
  }

  // ── Copy verse to clipboard ────────────────────────────
  void _copyVerse(String verseNum, String text) {
    final ref = '${widget.bookName} $_currentChapter:$verseNum';
    Clipboard.setData(ClipboardData(text: '"$text" — $ref'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$ref copied to clipboard'),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            onPressed: () {
              setState(() {
                if (_fontSize > 12) _fontSize -= 2;
              });
            },
            tooltip: 'Decrease font size',
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 20),
            onPressed: () {
              setState(() {
                if (_fontSize < 26) _fontSize += 2;
              });
            },
            tooltip: 'Increase font size',
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
        // ── Chapter Info Bar ─────────────────────────
        Container(
          color: AppTheme.primaryBlue,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            children: [
              Text(
                '${_verseList.length} verses',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
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

        // ── Verse List ───────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _verseList.length,
            itemBuilder: (context, index) {
              final entry = _verseList[index];
              final verseNum = int.tryParse(entry.key) ?? 0;
              final isHighlighted = _highlightedVerse == verseNum;
              return _buildVerseTile(
                verseNum: verseNum,
                text: entry.value,
                isHighlighted: isHighlighted,
              );
            },
          ),
        ),

        // ── Prev / Next Navigation ───────────────────
        _buildNavBar(hasPrev, hasNext),
      ],
    );
  }

  // ── Verse Tile ─────────────────────────────────────────
  Widget _buildVerseTile({
    required int verseNum,
    required String text,
    required bool isHighlighted,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _highlightedVerse = isHighlighted ? null : verseNum;
        });
      },
      onLongPress: () => _copyVerse('$verseNum', text),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlighted
              ? _accentColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isHighlighted
              ? Border.all(color: _accentColor.withOpacity(0.3))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$verseNum',
                style: TextStyle(
                  fontSize: _fontSize - 4,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted ? _accentColor : AppTheme.textHint,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
          ],
        ),
      ),
    );
  }

  // ── Prev / Next Nav Bar ────────────────────────────────
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
                foregroundColor: hasPrev ? _accentColor : AppTheme.textHint,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                foregroundColor: hasNext ? _accentColor : AppTheme.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'No verses found for ${widget.bookName} $_currentChapter',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Long-press any verse to copy it.',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/bible_loader_service.dart';
import '../../theme/app_theme.dart';
import 'bible_verses_screen.dart';

// ─────────────────────────────────────────────────────────
// BibleChaptersScreen
// Shows all chapters for a selected book as a grid
// ─────────────────────────────────────────────────────────
class BibleChaptersScreen extends StatefulWidget {
  final String language;
  final String bookName;
  final int bookNumber;

  const BibleChaptersScreen({
    super.key,
    required this.language,
    required this.bookName,
    required this.bookNumber,
  });

  @override
  State<BibleChaptersScreen> createState() => _BibleChaptersScreenState();
}

class _BibleChaptersScreenState extends State<BibleChaptersScreen> {
  List<String> _chapters = [];
  bool _loading = true;

  // OT = purple, NT = blue
  Color get _accentColor => widget.bookNumber <= 39
      ? const Color(0xFF6A1B9A)
      : const Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  void _loadChapters() {
    final chapters = BibleLoaderService.getChapters(
      widget.language,
      widget.bookName,
    );

    // Sort numerically
    chapters.sort((a, b) {
      final aNum = int.tryParse(a) ?? 0;
      final bNum = int.tryParse(b) ?? 0;
      return aNum.compareTo(bNum);
    });

    setState(() {
      _chapters = chapters;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Text(widget.bookName),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : _chapters.isEmpty
              ? _buildEmpty()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────
        Container(
          color: AppTheme.primaryBlue,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.bookName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_chapters.length} ${_chapters.length == 1 ? 'Chapter' : 'Chapters'}'
                ' · ${widget.language == 'yoruba' ? 'Yoruba' : 'English'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),

        // ── Chapter Grid ─────────────────────────────
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _chapters.length,
            itemBuilder: (context, index) {
              final chapter = _chapters[index];
              return _buildChapterTile(chapter);
            },
          ),
        ),
      ],
    );
  }

  // ── Chapter Tile ───────────────────────────────────────
  Widget _buildChapterTile(String chapter) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BibleVersesScreen(
              language: widget.language,
              bookName: widget.bookName,
              bookNumber: widget.bookNumber,
              chapter: chapter,
              totalChapters: _chapters.length,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: _accentColor.withOpacity(0.15),
          ),
        ),
        child: Center(
          child: Text(
            chapter,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _accentColor,
            ),
          ),
        ),
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
            'No chapters found for ${widget.bookName}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bible may still be loading.\nGo back and try again.',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

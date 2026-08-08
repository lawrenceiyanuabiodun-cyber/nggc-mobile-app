import 'package:flutter/material.dart';

import '../../services/bible_loader_service.dart';
import '../../theme/app_theme.dart';
import 'bible_verses_screen.dart';

// ─────────────────────────────────────────────────────────
// BibleSearchScreen
// Search across all offline Bible verses
// No internet needed — searches Hive directly
// ─────────────────────────────────────────────────────────
class BibleSearchScreen extends StatefulWidget {
  final String language;

  const BibleSearchScreen({super.key, required this.language});

  @override
  State<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends State<BibleSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<_VerseResult> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Search verses ──────────────────────────────────────
  Future<void> _search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || q == _lastQuery) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _lastQuery = q;
      _results = [];
    });

    // Search in background to avoid UI freeze
    final results = await Future.microtask(() => _searchVerses(q));

    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  // ── Core search logic ──────────────────────────────────
  List<_VerseResult> _searchVerses(String query) {
    final results = <_VerseResult>[];
    final books = BibleLoaderService.getBooks(widget.language);

    for (final book in books) {
      final chapters = BibleLoaderService.getChapters(
        widget.language,
        book,
      );
      for (final chapter in chapters) {
        final verses = BibleLoaderService.getVerses(
          widget.language,
          book,
          chapter,
        );
        for (final entry in verses.entries) {
          if (entry.value.toLowerCase().contains(query)) {
            results.add(_VerseResult(
              bookName: book,
              chapter: chapter,
              verseNum: entry.key,
              text: entry.value,
            ));
            // Limit to 100 results for performance
            if (results.length >= 100) return results;
          }
        }
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final langLabel = widget.language == 'yoruba' ? 'Yoruba' : 'English';

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search $langLabel Bible...',
              hintStyle: const TextStyle(color: Colors.white54),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _results = [];
                          _hasSearched = false;
                          _lastQuery = '';
                        });
                        _focusNode.requestFocus();
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.search, color: Colors.white70),
                      onPressed: () => _search(_searchController.text),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryBlue),
            const SizedBox(height: 16),
            Text(
              'Searching ${widget.language == 'yoruba' ? 'Yoruba' : 'English'} Bible...',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'This searches all 31,000+ verses',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 56,
                color: AppTheme.textHint.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Search the ${widget.language == 'yoruba' ? 'Yoruba' : 'English'} Bible',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Type a word or phrase and press search.\nShows up to 100 results.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textHint,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 56, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(
              'No results for "$_lastQuery"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different word or phrase',
              style: TextStyle(fontSize: 13, color: AppTheme.textHint),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count bar
        Container(
          color: AppTheme.primaryBlue.withOpacity(0.06),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              Text(
                '${_results.length}${_results.length == 100 ? '+' : ''} result${_results.length == 1 ? '' : 's'} for "$_lastQuery"',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (_results.length == 100) ...[
                const Spacer(),
                const Text(
                  'Showing first 100',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              return _buildResultCard(_results[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(_VerseResult result) {
    final isOT = _isOldTestament(result.bookName);
    final color = isOT
        ? const Color(0xFF6A1B9A)
        : const Color(0xFF1565C0);
    final ref = '${result.bookName} ${result.chapter}:${result.verseNum}';

    // Highlight search term in text
    final lowerText = result.text.toLowerCase();
    final lowerQuery = _lastQuery.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Get total chapters for navigation
          final chapters = BibleLoaderService.getChapters(
            widget.language,
            result.bookName,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BibleVersesScreen(
                language: widget.language,
                bookName: result.bookName,
                bookNumber: _getBookNumber(result.bookName),
                chapter: result.chapter,
                totalChapters: chapters.length,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reference
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ref,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textHint,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Verse text with highlight
              matchIndex >= 0
                  ? RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: result.text.substring(0, matchIndex),
                          ),
                          TextSpan(
                            text: result.text.substring(
                              matchIndex,
                              matchIndex + _lastQuery.length,
                            ),
                            style: TextStyle(
                              backgroundColor:
                                  color.withOpacity(0.2),
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: result.text
                                .substring(matchIndex + _lastQuery.length),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      result.text,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────
  bool _isOldTestament(String bookName) {
    final books = BibleLoaderService.getBooks(widget.language);
    final index = books.indexOf(bookName);
    return index < 39;
  }

  int _getBookNumber(String bookName) {
    final books = BibleLoaderService.getBooks(widget.language);
    return books.indexOf(bookName) + 1;
  }
}

// ── Result model ───────────────────────────────────────
class _VerseResult {
  final String bookName;
  final String chapter;
  final String verseNum;
  final String text;

  const _VerseResult({
    required this.bookName,
    required this.chapter,
    required this.verseNum,
    required this.text,
  });
}

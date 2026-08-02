import 'package:flutter/material.dart';

import '../../services/bible_loader_service.dart';
import '../../theme/app_theme.dart';
import 'bible_chapters_screen.dart';
import 'bible_search_screen.dart';

// ─────────────────────────────────────────────────────────
// BibleBooksScreen
// Lists all books for selected language
// Grouped into Old Testament / New Testament
// ─────────────────────────────────────────────────────────
class BibleBooksScreen extends StatefulWidget {
  final String language;

  const BibleBooksScreen({super.key, required this.language});

  @override
  State<BibleBooksScreen> createState() => _BibleBooksScreenState();
}

class _BibleBooksScreenState extends State<BibleBooksScreen> {
  List<String> _books = [];
  List<String> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  static const int _oldTestamentCount = 39;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadBooks() {
    final books = BibleLoaderService.getBooks(widget.language);
    setState(() {
      _books = books;
      _filtered = books;
      _loading = false;
    });
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _books
          : _books
              .where((b) => b.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final langLabel = widget.language == 'yoruba' ? 'Yoruba' : 'English';

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Text('$langLabel Bible'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Deep Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BibleSearchScreen(language: widget.language),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Filter books...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.filter_list, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : _filtered.isEmpty
              ? _buildEmpty()
              : _buildBookList(),
    );
  }

  Widget _buildBookList() {
    if (_searchController.text.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          return _buildBookTile(_filtered[index], index + 1);
        },
      );
    }

    final ot = _books.length >= _oldTestamentCount
        ? _books.sublist(0, _oldTestamentCount)
        : _books;
    final nt = _books.length > _oldTestamentCount
        ? _books.sublist(_oldTestamentCount)
        : <String>[];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildSectionHeader(
          'Old Testament',
          '${ot.length} Books',
          const Color(0xFF6A1B9A),
        ),
        ...ot.asMap().entries.map(
              (e) => _buildBookTile(e.value, e.key + 1),
            ),
        const SizedBox(height: 8),
        if (nt.isNotEmpty) ...[
          _buildSectionHeader(
            'New Testament',
            '${nt.length} Books',
            const Color(0xFF1565C0),
          ),
          ...nt.asMap().entries.map(
                (e) => _buildBookTile(e.value, _oldTestamentCount + e.key + 1),
              ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookTile(String bookName, int bookNumber) {
    final isOT = bookNumber <= _oldTestamentCount;
    final color = isOT
        ? const Color(0xFF6A1B9A)
        : const Color(0xFF1565C0);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BibleChaptersScreen(
              language: widget.language,
              bookName: bookName,
              bookNumber: bookNumber,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.dividerColor),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$bookNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                bookName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(
            'No book found for "${_searchController.text}"',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

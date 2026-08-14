import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/bible_loader_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// BiblePassagePopup
// Shows a scrollable bottom-sheet with Bible verses
// Parses references like:
//   - "John 3:16"
//   - "Genesis 1:1-10"
//   - "1 Corinthians 13"
//   - "Romans 8:28-30"
//   - "John 3:16; Romans 8:28"  (multiple refs)
// ─────────────────────────────────────────────────────────
class BiblePassagePopup {
  BiblePassagePopup._();

  /// Show the popup
  static Future<void> show(
    BuildContext context, {
    required String passageRef,
    required String language,
  }) async {
    // Try English first if primary language fails
    final parsedRefs = _parseReferences(passageRef);

    if (parsedRefs.isEmpty) {
      _showSnack(context,
          'Could not read passage reference: $passageRef',
          isError: true);
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PopupContent(
        passageRef: passageRef,
        references: parsedRefs,
        language: language,
      ),
    );
  }

  static void _showSnack(BuildContext ctx, String msg,
      {bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppTheme.errorRed : AppTheme.primaryBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  /// Parse a passage string into structured references
  /// Handles semicolon-separated multiple refs: "John 3:16; Rom 8:28"
  static List<_ParsedRef> _parseReferences(String raw) {
    final result = <_ParsedRef>[];
    // Split by semicolons or "and" or newlines
    final parts = raw
        .replaceAll('\n', ';')
        .replaceAll(' and ', ';')
        .split(';');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final ref = _parseOne(trimmed);
      if (ref != null) result.add(ref);
    }
    return result;
  }

  /// Parse one reference like "1 John 3:16-18", "1samuel 25:1-42", "Isamuel 25"
  static _ParsedRef? _parseOne(String raw) {
    String normalized = raw.trim();

    // Normalize: insert space between leading digit and letter if missing
    // e.g. "1samuel" -> "1 samuel", "2kings" -> "2 kings"
    normalized = normalized.replaceAllMapped(
      RegExp(r'^(\d)([A-Za-z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // Normalize Roman-ish typos where user typed letter I/II/III instead of 1/2/3
    // e.g. "Isamuel 25:1" -> "1 samuel 25:1", "II kings 4" -> "2 kings 4"
    normalized = normalized.replaceAllMapped(
      RegExp(r'^(III|II|I)\s*([A-Za-z])'),
      (m) {
        final roman = m.group(1)!;
        final letter = m.group(2)!;
        final num = roman == 'III' ? '3' : (roman == 'II' ? '2' : '1');
        return '$num $letter';
      },
    );

    // Regex: (book) chapter[:verseStart[-verseEnd]]
    final regex = RegExp(
      r'^\s*(\d?\s*[A-Za-z][A-Za-z\s]*?)\s+(\d+)(?::(\d+)(?:\s*[-–]\s*(\d+))?)?\s*$',
      caseSensitive: false,
    );
    final m = regex.firstMatch(normalized);
    if (m == null) return null;

    final book = m.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
    final chapter = m.group(2)!;
    final vStart = m.group(3);
    final vEnd = m.group(4);

    return _ParsedRef(
      rawText: raw,
      book: book,
      chapter: chapter,
      verseStart: vStart,
      verseEnd: vEnd,
    );
  }

}

// ─────────────────────────────────────────────────────────
// Parsed reference model
// ─────────────────────────────────────────────────────────
class _ParsedRef {
  final String rawText;
  final String book;
  final String chapter;
  final String? verseStart;
  final String? verseEnd;

  _ParsedRef({
    required this.rawText,
    required this.book,
    required this.chapter,
    this.verseStart,
    this.verseEnd,
  });
}

// ─────────────────────────────────────────────────────────
// Popup UI Content
// ─────────────────────────────────────────────────────────
class _PopupContent extends StatefulWidget {
  final String passageRef;
  final List<_ParsedRef> references;
  final String language;

  const _PopupContent({
    required this.passageRef,
    required this.references,
    required this.language,
  });

  @override
  State<_PopupContent> createState() => _PopupContentState();
}

class _PopupContentState extends State<_PopupContent> {
  late String _currentLanguage;
  final Map<int, List<_VerseRow>> _versesByRef = {};
  final Map<int, String?> _errorByRef = {};

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.language.toLowerCase();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Make sure all Bible translations are loaded into Hive first
    final ready = await BibleLoaderService.ensureBiblesLoaded();
    if (!mounted) return;
    if (!ready) {
      setState(() {
        for (int i = 0; i < widget.references.length; i++) {
          _errorByRef[i] = 'Bible not available offline. Please try again.';
          _versesByRef[i] = [];
        }
      });
      return;
    }
    for (int i = 0; i < widget.references.length; i++) {
      _loadOne(i, widget.references[i]);
    }
  }

  void _loadOne(int index, _ParsedRef ref) {
    // Try to resolve the book name in current language
    final resolvedBook = _resolveBookName(ref.book, _currentLanguage);
    if (resolvedBook == null) {
      // Try fallback in English
      final enBook = _resolveBookName(ref.book, 'english');
      if (enBook == null) {
        setState(() {
          _errorByRef[index] = 'Book "${ref.book}" not found. Check the passage reference.';
          _versesByRef[index] = [];
        });
        return;
      }
      // Load English as fallback
      final verses = _fetchVerses(enBook, ref, 'english');
      setState(() {
        _errorByRef[index] = null;
        _versesByRef[index] = verses;
      });
      return;
    }

    final verses = _fetchVerses(resolvedBook, ref, _currentLanguage);
    setState(() {
      _errorByRef[index] = verses.isEmpty
          ? 'No verses found for "${ref.rawText}". Check the passage reference.'
          : null;
      _versesByRef[index] = verses;
    });
  }

  /// Try to find a book name in the given language (fuzzy match)
  String? _resolveBookName(String userInput, String language) {
    final books = BibleLoaderService.getBooks(language);
    if (books.isEmpty) return null;

    final normalized = userInput
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 1. Exact match (case-insensitive)
    for (final b in books) {
      if (b.toLowerCase() == normalized) return b;
    }

    // 2. StartsWith match
    for (final b in books) {
      if (b.toLowerCase().startsWith(normalized)) return b;
    }

    // 3. Contains match
    for (final b in books) {
      if (b.toLowerCase().contains(normalized)) return b;
    }

    // 4. Common abbreviations
    final abbrevMap = <String, String>{
      'gen': 'Genesis', 'ex': 'Exodus', 'exo': 'Exodus',
      'lev': 'Leviticus', 'num': 'Numbers', 'deut': 'Deuteronomy',
      'josh': 'Joshua', 'judg': 'Judges', 'ruth': 'Ruth',
      '1 sam': '1 Samuel', '2 sam': '2 Samuel',
      '1 ki': '1 Kings', '2 ki': '2 Kings',
      '1 chr': '1 Chronicles', '2 chr': '2 Chronicles',
      'neh': 'Nehemiah', 'est': 'Esther', 'ps': 'Psalms',
      'psalm': 'Psalms', 'prov': 'Proverbs', 'ecc': 'Ecclesiastes',
      'eccl': 'Ecclesiastes', 'song': 'Song of Solomon',
      'isa': 'Isaiah', 'jer': 'Jeremiah', 'lam': 'Lamentations',
      'ezek': 'Ezekiel', 'dan': 'Daniel', 'hos': 'Hosea',
      'obad': 'Obadiah', 'jon': 'Jonah', 'mic': 'Micah',
      'nah': 'Nahum', 'hab': 'Habakkuk', 'zeph': 'Zephaniah',
      'hag': 'Haggai', 'zech': 'Zechariah', 'mal': 'Malachi',
      'matt': 'Matthew', 'mt': 'Matthew', 'mk': 'Mark',
      'lk': 'Luke', 'jn': 'John', 'rom': 'Romans',
      '1 cor': '1 Corinthians', '2 cor': '2 Corinthians',
      'gal': 'Galatians', 'eph': 'Ephesians', 'phil': 'Philippians',
      'col': 'Colossians',
      '1 thess': '1 Thessalonians', '2 thess': '2 Thessalonians',
      '1 tim': '1 Timothy', '2 tim': '2 Timothy',
      'phlm': 'Philemon', 'heb': 'Hebrews', 'jas': 'James',
      '1 pet': '1 Peter', '2 pet': '2 Peter',
      '1 jn': '1 John', '2 jn': '2 John', '3 jn': '3 John',
      'rev': 'Revelation',
    };

    final abbrev = abbrevMap[normalized];
    if (abbrev != null) {
      for (final b in books) {
        if (b.toLowerCase() == abbrev.toLowerCase()) return b;
      }
    }

    return null;
  }

  /// Fetch verses for the parsed reference
  List<_VerseRow> _fetchVerses(
      String book, _ParsedRef ref, String language) {
    final chapterVerses =
        BibleLoaderService.getVerses(language, book, ref.chapter);
    if (chapterVerses.isEmpty) return [];

    final start = int.tryParse(ref.verseStart ?? '') ?? 1;
    final end = int.tryParse(ref.verseEnd ?? '') ??
        (ref.verseStart == null ? _lastVerseNumber(chapterVerses) : start);

    final result = <_VerseRow>[];
    for (int v = start; v <= end; v++) {
      final text = chapterVerses[v.toString()];
      if (text != null) {
        result.add(_VerseRow(
          number: v.toString(),
          text: text,
          book: book,
          chapter: ref.chapter,
        ));
      }
    }
    return result;
  }

  int _lastVerseNumber(Map<String, String> verses) {
    int max = 0;
    for (final k in verses.keys) {
      final n = int.tryParse(k) ?? 0;
      if (n > max) max = n;
    }
    return max;
  }

  void _copyPassage() {
    final buffer = StringBuffer();
    buffer.writeln(widget.passageRef);
    buffer.writeln();
    for (int i = 0; i < widget.references.length; i++) {
      final verses = _versesByRef[i] ?? [];
      for (final v in verses) {
        buffer.writeln('${v.number}. ${v.text}');
      }
      if (i < widget.references.length - 1) buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Passage copied to clipboard'),
      backgroundColor: AppTheme.successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _toggleLanguage() {
    setState(() {
      _currentLanguage =
          _currentLanguage == 'english' ? 'yoruba' : 'english';
      _versesByRef.clear();
      _errorByRef.clear();
    });
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book,
                          color: AppTheme.primaryBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BIBLE PASSAGE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                                letterSpacing: 1.5,
                              )),
                          const SizedBox(height: 2),
                          Text(widget.passageRef,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    // Language toggle
                    InkWell(
                      onTap: _toggleLanguage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.accentGold, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.translate,
                                color: AppTheme.accentGoldDark, size: 14),
                            const SizedBox(width: 4),
                            Text(
                                _currentLanguage == 'yoruba'
                                    ? 'YO'
                                    : 'EN',
                                style: const TextStyle(
                                  color: AppTheme.accentGoldDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: isDark
                              ? Colors.white54
                              : AppTheme.textHint),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Verses
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  itemCount: widget.references.length,
                  itemBuilder: (ctx, i) {
                    final ref = widget.references[i];
                    final verses = _versesByRef[i];
                    final error = _errorByRef[i];

                    if (verses == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: AppTheme.primaryBlue),
                              SizedBox(height: 16),
                              Text(
                                'Loading Bible passage...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.references.length > 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(ref.rawText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                )),
                          ),
                        ],
                        if (error != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.orange, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(error,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87)),
                                ),
                              ],
                            ),
                          )
                        else
                          ...verses.map((v) => _buildVerseRow(
                              v, isDark, textColor)),
                        if (i < widget.references.length - 1)
                          const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),

              // Footer with actions
              Container(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F0F1E)
                      : AppTheme.surfaceLight,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white12
                          : AppTheme.dividerColor,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyPassage,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          side: const BorderSide(
                              color: AppTheme.primaryBlue),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerseRow(
      _VerseRow v, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            padding: const EdgeInsets.only(top: 2),
            child: Text(v.number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentGoldDark,
                )),
          ),
          Expanded(
            child: Text(v.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: textColor,
                )),
          ),
        ],
      ),
    );
  }
}

class _VerseRow {
  final String number;
  final String text;
  final String book;
  final String chapter;

  _VerseRow({
    required this.number,
    required this.text,
    required this.book,
    required this.chapter,
  });
}
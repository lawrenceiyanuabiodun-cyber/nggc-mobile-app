import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_config.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// SavedVerse model
// ─────────────────────────────────────────────────────────
class SavedVerse {
  final String bookName;
  final String chapter;
  final String verseNum;
  final String text;
  final String language;
  final DateTime savedAt;

  SavedVerse({
    required this.bookName,
    required this.chapter,
    required this.verseNum,
    required this.text,
    required this.language,
    required this.savedAt,
  });

  String get reference => '$bookName $chapter:$verseNum';
  String get key => '${language}_${bookName}_${chapter}_$verseNum';

  Map<String, dynamic> toJson() => {
        'bookName': bookName,
        'chapter': chapter,
        'verseNum': verseNum,
        'text': text,
        'language': language,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedVerse.fromJson(Map<String, dynamic> json) => SavedVerse(
        bookName: json['bookName'] ?? '',
        chapter: json['chapter'] ?? '',
        verseNum: json['verseNum'] ?? '',
        text: json['text'] ?? '',
        language: json['language'] ?? 'english',
        savedAt: DateTime.tryParse(json['savedAt'] ?? '') ?? DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────
// BibleVerseStorage
// Static helper to save/load/delete verses from Hive
// ─────────────────────────────────────────────────────────
class BibleVerseStorage {
  static Box get _box => Hive.box(AppConfig.verseBoxName);

  static Future<void> saveVerse(SavedVerse verse) async {
    await _box.put(verse.key, json.encode(verse.toJson()));
  }

  static Future<void> deleteVerse(String key) async {
    await _box.delete(key);
  }

  static bool isVersesSaved(String key) => _box.containsKey(key);

  static List<SavedVerse> getAllVerses() {
    final verses = <SavedVerse>[];
    for (final k in _box.keys) {
      try {
        final raw = _box.get(k);
        if (raw != null) {
          final map = json.decode(raw as String) as Map<String, dynamic>;
          verses.add(SavedVerse.fromJson(map));
        }
      } catch (_) {}
    }
    verses.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return verses;
  }
}

// ─────────────────────────────────────────────────────────
// BibleSavedVersesScreen
// Shows all saved Bible verses from Hive
// ─────────────────────────────────────────────────────────
class BibleSavedVersesScreen extends StatefulWidget {
  const BibleSavedVersesScreen({super.key});

  @override
  State<BibleSavedVersesScreen> createState() =>
      _BibleSavedVersesScreenState();
}

class _BibleSavedVersesScreenState extends State<BibleSavedVersesScreen> {
  List<SavedVerse> _verses = [];

  @override
  void initState() {
    super.initState();
    _loadVerses();
  }

  void _loadVerses() {
    setState(() {
      _verses = BibleVerseStorage.getAllVerses();
    });
  }

  Future<void> _deleteVerse(SavedVerse verse) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Remove Verse',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        content: Text(
          'Remove ${verse.reference} from saved verses?',
          style: const TextStyle(color: AppTheme.textSecondary),
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await BibleVerseStorage.deleteVerse(verse.key);
      _loadVerses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verse removed'),
            backgroundColor: AppTheme.primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _shareVerse(SavedVerse verse) {
    final shareText =
        '"${verse.text}"\n\n— ${verse.reference}\n\nShared from NGGC Sunday School App';
    Share.share(shareText, subject: verse.reference);
  }

  void _copyVerse(SavedVerse verse) {
    Clipboard.setData(
      ClipboardData(text: '"${verse.text}" — ${verse.reference}'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${verse.reference} copied'),
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
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Saved Verses'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_verses.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Clear All Verses',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    content: const Text(
                      'Remove all saved verses? This cannot be undone.',
                      style: TextStyle(color: AppTheme.textSecondary),
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
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  for (final v in _verses) {
                    await BibleVerseStorage.deleteVerse(v.key);
                  }
                  _loadVerses();
                }
              },
            ),
        ],
      ),
      body: _verses.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _verses.length,
      itemBuilder: (context, index) {
        final verse = _verses[index];
        return _buildVerseCard(verse);
      },
    );
  }

  Widget _buildVerseCard(SavedVerse verse) {
    final isEnglish = verse.language == 'english';
    final color = isEnglish
        ? const Color(0xFF1565C0)
        : const Color(0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    verse.reference,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                // Language chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isEnglish ? 'EN' : 'YO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Verse text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '"${verse.text}"',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _shareVerse(verse),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share'),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copyVerse(verse),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.errorRed,
                    size: 18,
                  ),
                  onPressed: () => _deleteVerse(verse),
                  tooltip: 'Remove',
                ),
              ],
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
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 56,
            color: AppTheme.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No saved verses yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the bookmark icon on any verse\nwhile reading to save it here',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textHint,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

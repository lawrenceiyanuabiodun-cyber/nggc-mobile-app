import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/manuals_loader_service.dart';
import '../../services/progress_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/shimmer_widgets.dart';
import '../../widgets/lessons/bible_passage_popup.dart';

// ─────────────────────────────────────────────────────────
// LessonDetailScreen
// Renders full lesson content with language toggle
// ─────────────────────────────────────────────────────────
class LessonDetailScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final String title;

  const LessonDetailScreen({
    super.key,
    required this.lessonId,
    required this.title,
  });

  @override
  ConsumerState<LessonDetailScreen> createState() =>
      _LessonDetailScreenState();
}

class _LessonDetailScreenState
    extends ConsumerState<LessonDetailScreen> {
  Map<String, dynamic>? _lesson;
  Map<String, dynamic>? _siblingLesson;
  bool _isLoading = true;
  String? _error;
  late String _currentLessonId;
  late String _currentTitle;

  bool _isFavorited = false;
  bool _favoriteLoading = false;
  String? _favoriteId;

  bool _noteLoading = false;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _currentLessonId = widget.lessonId;
    _currentTitle = widget.title;
    _loadLesson();
    _checkFavorite();
    _trackProgress();
  }

  Future<void> _loadLesson() async {
    setState(() { _isLoading = true; _error = null; });

    final cached = ManualsLoaderService.getFullLesson(_currentLessonId);
    if (cached != null) {
      setState(() {
        _lesson = cached;
        _siblingLesson = ManualsLoaderService.findSiblingLesson(cached);
        _isLoading = false;
      });
    }

    try {
      final response =
          await ApiService.get('/lessons/$_currentLessonId/full');
      if (!mounted) return;
      if (response.isSuccess && response.asMap != null) {
        final data = response.asMap!;
        Map<String, dynamic>? lesson;
        if (data['lesson'] is Map) {
          lesson = Map<String, dynamic>.from(data['lesson'] as Map);
        } else if (data['id'] != null) {
          lesson = Map<String, dynamic>.from(data);
        }
        if (lesson != null) {
          await ManualsLoaderService.saveFullLesson(lesson);
          setState(() {
            _lesson = lesson;
            _siblingLesson =
                ManualsLoaderService.findSiblingLesson(lesson!);
            _isLoading = false;
          });
        }
      }
    } catch (_) {}

    if (mounted && _lesson == null) {
      setState(() {
        _error = 'Could not load lesson.\nPlease check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _switchLanguage() async {
    if (_siblingLesson == null) return;
    final sibling = _siblingLesson!;
    setState(() {
      _currentLessonId = sibling['id'].toString();
      _currentTitle = sibling['title']?.toString() ?? _currentTitle;
      _lesson = sibling;
      _siblingLesson = ManualsLoaderService.findSiblingLesson(sibling);
    });
    _checkFavorite();
    _trackProgress();
  }

  Future<void> _checkFavorite() async {
    final response =
        await ApiService.get('/favorites/check/$_currentLessonId');
    if (!mounted) return;
    if (response.isSuccess && response.asMap != null) {
      setState(() {
        _isFavorited = response.asMap!['is_favorited'] == true ||
            response.asMap!['favorited'] == true;
        _favoriteId = response.asMap!['favorite_id']?.toString();
      });
    }
  }

  Future<void> _trackProgress() async {
    await ProgressCacheService.saveProgress(_currentLessonId, 50);
    try {
      await ApiService.post('/progress/', body: {
        'lesson_id': _currentLessonId,
        'progress_percentage': 50,
        'is_completed': false,
      });
    } catch (_) {}
  }

  Future<void> _markAsComplete() async {
    await ProgressCacheService.saveProgress(_currentLessonId, 100);
    try {
      await ApiService.post('/progress/', body: {
        'lesson_id': _currentLessonId,
        'progress_percentage': 100,
        'is_completed': true,
      });
    } catch (_) {}
    if (mounted) {
      _showSnack('Lesson marked as complete', AppTheme.successGreen);
      setState(() {});
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() => _favoriteLoading = true);
    if (_isFavorited && _favoriteId != null) {
      final response = await ApiService.delete('/favorites/$_favoriteId');
      if (!mounted) return;
      if (response.isSuccess) {
        setState(() { _isFavorited = false; _favoriteId = null; });
        _showSnack('Removed from favorites', AppTheme.textSecondary);
      }
    } else {
      final response = await ApiService.post('/favorites/',
          body: {'lesson_id': _currentLessonId});
      if (!mounted) return;
      if (response.isSuccess) {
        setState(() {
          _isFavorited = true;
          _favoriteId = response.asMap?['id']?.toString() ??
              response.asMap?['favorite_id']?.toString();
        });
        _showSnack('Added to favorites', AppTheme.errorRed);
      }
    }
    if (mounted) setState(() => _favoriteLoading = false);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('$label copied!', AppTheme.primaryBlue);
  }

  /// Open the Bible passage popup
  void _openBiblePassage(String passage) {
    if (passage.trim().isEmpty) return;
    final user = ref.read(currentUserProvider);
    final language = user?.preferredLanguage ??
        (_lesson?['language']?.toString() ?? 'english');
    BiblePassagePopup.show(
      context,
      passageRef: passage,
      language: language,
    );
  }

  void _showAddNoteDialog() {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      color: AppTheme.accentGoldDark, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Note on: $_currentTitle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.primaryBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: noteController,
                  maxLines: 6,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Write your note here...',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : AppTheme.textHint,
                        fontSize: 14),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F0F1E)
                        : AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryBlue, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please write something';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _noteLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(ctx);
                          await _saveNote(noteController.text.trim());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Note',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote(String content) async {
    setState(() => _noteLoading = true);
    final response = await ApiService.post('/notes/',
        body: {'lesson_id': _currentLessonId, 'content': content});
    if (!mounted) return;
    setState(() => _noteLoading = false);
    if (response.isSuccess) {
      _showSnack('Note saved!', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed to save note', AppTheme.errorRed);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0F0F1E) : const Color(0xFFFAF8F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_currentTitle, style: const TextStyle(fontSize: 14)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_siblingLesson != null) _buildLanguageSwitchButton(),
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            onPressed: () =>
                setState(() { if (_fontSize > 13) _fontSize -= 1; }),
            tooltip: 'Smaller',
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 20),
            onPressed: () =>
                setState(() { if (_fontSize < 24) _fontSize += 1; }),
            tooltip: 'Larger',
          ),
          _favoriteLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _isFavorited
                        ? Icons.favorite
                        : Icons.favorite_outline,
                    color: _isFavorited
                        ? Colors.red.shade300
                        : Colors.white70,
                    size: 22,
                  ),
                  onPressed: _toggleFavorite,
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddNoteDialog,
        backgroundColor: AppTheme.accentGoldDark,
        foregroundColor: AppTheme.primaryBlueDark,
        icon: const Icon(Icons.edit_note),
        label: const Text('Add Note',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading && _lesson == null
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                ShimmerCard(height: 100),
                SizedBox(height: 16),
                ShimmerCard(height: 200),
                SizedBox(height: 16),
                ShimmerCard(height: 150),
              ],
            )
          : _error != null && _lesson == null
              ? _buildError(isDark)
              : _buildContent(isDark),
    );
  }

  Widget _buildLanguageSwitchButton() {
    final sibling = _siblingLesson!;
    final siblingLang =
        sibling['language']?.toString().toLowerCase() ?? 'english';
    final label = siblingLang == 'yoruba' ? 'YO' : 'EN';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: InkWell(
        onTap: _switchLanguage,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.accentGold.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentGold, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate,
                  color: AppTheme.accentGold, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_outlined,
                size: 56,
                color: isDark ? Colors.white38 : AppTheme.textHint),
            const SizedBox(height: 16),
            Text('Could not load lesson',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    fontSize: 13,
                    color:
                        isDark ? Colors.white60 : AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLesson,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final lesson = _lesson!;

    final String title = lesson['title']?.toString() ?? _currentTitle;
    final String topic = lesson['topic']?.toString() ?? '';
    final String biblePassage =
        lesson['bible_passage']?.toString() ?? '';
    final String memoryVerse =
        lesson['memory_verse']?.toString() ?? '';
    final String memoryVerseRef =
        lesson['memory_verse_reference']?.toString() ?? '';
    final String goldenText = lesson['golden_text']?.toString() ?? '';
    final String goldenTextRef =
        lesson['golden_text_reference']?.toString() ?? '';
    final String aim = _cleanField(lesson['lesson_aim']) ??
        _cleanField(lesson['aim']) ?? '';
    final String centralTruth =
        _cleanField(lesson['central_truth']) ?? '';
    final String objectives = _cleanField(lesson['objectives']) ?? '';
    final String introduction =
        _cleanField(lesson['introduction']) ?? '';
    final String application = _cleanField(lesson['application']) ?? '';
    final String assignment = _cleanField(lesson['assignment']) ?? '';
    final String conclusion = _cleanField(lesson['conclusion']) ?? '';
    final String discussionQuestions =
        _cleanField(lesson['discussion_questions']) ?? '';
    final String teacherNotes =
        _cleanField(lesson['teacher_notes']) ?? '';
    final String language =
        lesson['language']?.toString() ?? 'english';
    final String quarter = lesson['quarter']?.toString() ?? '';
    final String lessonNumber =
        lesson['lesson_number']?.toString() ?? '';
    final String lessonDate =
        lesson['lesson_date']?.toString() ?? '';

    final List<Map<String, dynamic>> outlineList =
        _parseOutline(lesson['outline']);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lessonNumber.isNotEmpty)
                  Text('LESSON $lessonNumber',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.4)),
                if (topic.isNotEmpty && topic != title) ...[
                  const SizedBox(height: 4),
                  Text(topic,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _buildChip(
                      language[0].toUpperCase() + language.substring(1),
                      Colors.white,
                      Colors.white24),
                  if (quarter.isNotEmpty)
                    _buildChip(quarter, AppTheme.accentGold,
                        AppTheme.accentGold.withOpacity(0.2)),
                  if (lessonDate.isNotEmpty)
                    _buildChip(_formatDate(lessonDate), Colors.white70,
                        Colors.white12),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 18),

          if (aim.isNotEmpty)
            _section(
              icon: Icons.flag_outlined,
              iconColor: AppTheme.successGreen,
              label: 'AIM',
              isDark: isDark,
              child: Text(aim,
                  style: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.6)),
            ),

          if (centralTruth.isNotEmpty)
            _section(
              icon: Icons.stars_outlined,
              iconColor: AppTheme.accentGoldDark,
              label: 'CENTRAL TRUTH',
              isDark: isDark,
              child: Text(centralTruth,
                  style: TextStyle(
                      fontSize: _fontSize,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.6)),
            ),

          // ═══════════ BIBLE PASSAGE (TAPPABLE!) ═══════════
          if (biblePassage.isNotEmpty)
            _section(
              icon: Icons.menu_book,
              iconColor: AppTheme.primaryBlue,
              label: 'BIBLE PASSAGE',
              isDark: isDark,
              trailing: _copyBtn(biblePassage, 'Bible passage', isDark),
              child: InkWell(
                onTap: () => _openBiblePassage(biblePassage),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(
                        isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            AppTheme.primaryBlue.withOpacity(0.3),
                        width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(biblePassage,
                            style: TextStyle(
                                fontSize: _fontSize,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.primaryBlue,
                                height: 1.5)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (memoryVerse.isNotEmpty)
            _memoryVerseCard(memoryVerse, memoryVerseRef, isDark),

          if (goldenText.isNotEmpty && goldenText != memoryVerse)
            _section(
              icon: Icons.format_quote,
              iconColor: AppTheme.accentGoldDark,
              label: 'GOLDEN TEXT',
              isDark: isDark,
              trailing: _copyBtn(goldenText, 'Golden text', isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"$goldenText"',
                      style: TextStyle(
                          fontSize: _fontSize,
                          fontStyle: FontStyle.italic,
                          color:
                              isDark ? Colors.white : AppTheme.textPrimary,
                          height: 1.6)),
                  if (goldenTextRef.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => _openBiblePassage(goldenTextRef),
                        child: Text('- $goldenTextRef',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentGoldDark,
                                decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          if (objectives.isNotEmpty)
            _section(
              icon: Icons.checklist_outlined,
              iconColor: AppTheme.primaryBlue,
              label: 'OBJECTIVES',
              isDark: isDark,
              child: Text(objectives,
                  style: TextStyle(
                      fontSize: _fontSize,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.7)),
            ),

          if (introduction.isNotEmpty)
            _section(
              icon: Icons.article_outlined,
              iconColor: AppTheme.primaryBlue,
              label: 'INTRODUCTION',
              isDark: isDark,
              child: Text(introduction,
                  style: TextStyle(
                      fontSize: _fontSize,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.7)),
            ),

          if (outlineList.isNotEmpty)
            _section(
              icon: Icons.format_list_numbered,
              iconColor: AppTheme.successGreen,
              label: 'LESSON OUTLINE',
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: outlineList.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final heading = item['heading']?.toString() ?? '';
                  final body = item['body']?.toString() ?? '';
                  final order = item['order']?.toString() ?? '${i + 1}';
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i == outlineList.length - 1 ? 0 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(order,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.successGreen,
                                    )),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(heading,
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                    height: 1.5,
                                  )),
                            ),
                          ],
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 34),
                            child: Text(body,
                                style: TextStyle(
                                  fontSize: _fontSize - 1,
                                  color: isDark
                                      ? Colors.white70
                                      : AppTheme.textSecondary,
                                  height: 1.7,
                                )),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          if (application.isNotEmpty)
            _section(
              icon: Icons.lightbulb_outline,
              iconColor: AppTheme.accentGoldDark,
              label: 'APPLICATION',
              isDark: isDark,
              child: Text(application,
                  style: TextStyle(
                      fontSize: _fontSize,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.7)),
            ),

          if (discussionQuestions.isNotEmpty)
            _section(
              icon: Icons.help_outline,
              iconColor: AppTheme.primaryBlue,
              label: 'DISCUSSION QUESTIONS',
              isDark: isDark,
              child: Text(discussionQuestions,
                  style: TextStyle(
                      fontSize: _fontSize,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.7)),
            ),

          if (conclusion.isNotEmpty)
            _section(
              icon: Icons.done_all,
              iconColor: AppTheme.successGreen,
              label: 'CONCLUSION',
              isDark: isDark,
              child: Text(conclusion,
                  style: TextStyle(
                      fontSize: _fontSize,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.7)),
            ),

          if (assignment.isNotEmpty)
            _section(
              icon: Icons.assignment_outlined,
              iconColor: Colors.deepOrange,
              label: 'ASSIGNMENT',
              isDark: isDark,
              child: Text(assignment,
                  style: TextStyle(
                      fontSize: _fontSize,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.7)),
            ),

          if (teacherNotes.isNotEmpty)
            _section(
              icon: Icons.person_outline,
              iconColor: Colors.purple,
              label: 'TEACHER NOTES',
              isDark: isDark,
              child: Text(teacherNotes,
                  style: TextStyle(
                      fontSize: _fontSize,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? Colors.white70
                          : AppTheme.textSecondary,
                      height: 1.7)),
            ),

          const SizedBox(height: 30),

          Center(
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 16),
                if (!ProgressCacheService.isCompleted(_currentLessonId))
                  ElevatedButton.icon(
                    onPressed: _markAsComplete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark as Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(220, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.successGreen),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: AppTheme.successGreen, size: 18),
                        SizedBox(width: 8),
                        Text('Completed',
                            style: TextStyle(
                                color: AppTheme.successGreen,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note,
                        size: 16,
                        color: isDark
                            ? Colors.white38
                            : AppTheme.textHint.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text('Tap "Add Note" to save your thoughts',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white38
                                : AppTheme.textHint.withOpacity(0.7))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memoryVerseCard(String verse, String ref, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentGold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote,
                  color: AppTheme.accentGoldDark, size: 20),
              const SizedBox(width: 8),
              const Text('MEMORY VERSE',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.accentGoldDark,
                      letterSpacing: 1.2)),
              const Spacer(),
              _copyBtn('"$verse"\n- $ref', 'Memory verse', isDark),
            ],
          ),
          const SizedBox(height: 10),
          Text('"$verse"',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: _fontSize,
                  height: 1.7,
                  color: isDark ? Colors.white : AppTheme.textPrimary)),
          if (ref.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => _openBiblePassage(ref),
                child: Text('- $ref',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGoldDark,
                        decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isDark,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: iconColor,
                      letterSpacing: 1.2)),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _copyBtn(String text, String label, bool isDark) {
    return IconButton(
      icon: Icon(Icons.copy,
          size: 16,
          color: isDark ? Colors.white38 : AppTheme.textHint),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => _copyToClipboard(text, label),
      tooltip: 'Copy',
    );
  }

  Widget _buildChip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor)),
    );
  }

  String _formatDate(String s) {
    try {
      final d = DateTime.parse(s);
      const m = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) {
      return s;
    }
  }

  String? _cleanField(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }

  List<Map<String, dynamic>> _parseOutline(dynamic raw) {
    if (raw == null) return [];
    try {
      final str = raw.toString().trim();
      if (str.isEmpty) return [];
      final decoded = json.decode(str);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
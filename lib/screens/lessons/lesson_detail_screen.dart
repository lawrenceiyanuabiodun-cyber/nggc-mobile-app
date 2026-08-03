import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../services/progress_cache_service.dart';
import '../../widgets/common/shimmer_widgets.dart';

// ─────────────────────────────────────────────────────────
// LessonDetailScreen
// Full lesson content with:
// - Favorite toggle (heart in AppBar)
// - Add Note (FAB)
// - Memory verse card
// - Reading progress tracking
// ─────────────────────────────────────────────────────────
class LessonDetailScreen extends StatefulWidget {
  final String lessonId;
  final String title;

  const LessonDetailScreen({
    super.key,
    required this.lessonId,
    required this.title,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  Map<String, dynamic>? _lesson;
  bool _isLoading = true;
  String? _error;

  // Favorite state
  bool _isFavorited = false;
  bool _favoriteLoading = false;
  String? _favoriteId;

  // Note state
  bool _noteLoading = false;

  // Font size
  double _fontSize = 17.0;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _checkFavorite();
    _trackProgress();
  }

  // ── Fetch lesson content ───────────────────────────────
  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response =
        await ApiService.get('/lessons/${widget.lessonId}/full');

    if (!mounted) return;

    if (response.isSuccess) {
      setState(() {
        _lesson = response.asMap;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load lesson content';
        _isLoading = false;
      });
    }
  }

  // ── Check if lesson is favorited ───────────────────────
  Future<void> _checkFavorite() async {
    final response = await ApiService.get(
      '/favorites/check/${widget.lessonId}',
    );
    if (!mounted) return;
    if (response.isSuccess && response.asMap != null) {
      setState(() {
        _isFavorited = response.asMap!['is_favorited'] == true ||
            response.asMap!['favorited'] == true;
        _favoriteId = response.asMap!['favorite_id']?.toString();
      });
    }
  }

  // ── Track reading progress ─────────────────────────────
  // Mark 50% on open (started), 100% only when explicitly completed
  Future<void> _trackProgress() async {
    // Save locally first (works offline)
    await ProgressCacheService.saveProgress(widget.lessonId, 50);
    // Then sync with API
    try {
      await ApiService.post(
        '/progress/',
        body: {
          'lesson_id': widget.lessonId,
          'progress_percentage': 50,
          'is_completed': false,
        },
      );
    } catch (_) {}
  }

  Future<void> _markAsComplete() async {
    await ProgressCacheService.saveProgress(widget.lessonId, 100);
    try {
      await ApiService.post(
        '/progress/',
        body: {
          'lesson_id': widget.lessonId,
          'progress_percentage': 100,
          'is_completed': true,
        },
      );
    } catch (_) {}
    if (mounted) {
      _showSnack('Lesson marked as complete ✓', AppTheme.successGreen);
      setState(() {});
    }
  }

  // ── Toggle favorite ────────────────────────────────────
  Future<void> _toggleFavorite() async {
    setState(() => _favoriteLoading = true);

    if (_isFavorited && _favoriteId != null) {
      // Remove favorite
      final response = await ApiService.delete('/favorites/$_favoriteId');
      if (!mounted) return;
      if (response.isSuccess) {
        setState(() {
          _isFavorited = false;
          _favoriteId = null;
        });
        _showSnack('Removed from favorites', AppTheme.textSecondary);
      } else {
        _showSnack(response.error ?? 'Failed to remove', AppTheme.errorRed);
      }
    } else {
      // Add favorite
      final response = await ApiService.post(
        '/favorites/',
        body: {'lesson_id': widget.lessonId},
      );
      if (!mounted) return;
      if (response.isSuccess) {
        final data = response.asMap;
        setState(() {
          _isFavorited = true;
          _favoriteId = data?['id']?.toString() ??
              data?['favorite_id']?.toString();
        });
        _showSnack('Added to favorites ❤️', AppTheme.errorRed);
      } else {
        _showSnack(response.error ?? 'Failed to add', AppTheme.errorRed);
      }
    }

    if (mounted) setState(() => _favoriteLoading = false);
  }

  // ── Show add note dialog ───────────────────────────────
  void _showAddNoteDialog() {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
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
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Row(
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      color: AppTheme.accentGoldDark,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note on: ${widget.title}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Note input
                TextFormField(
                  controller: noteController,
                  maxLines: 6,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write your note here...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
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
                        color: AppTheme.primaryBlue,
                        width: 2,
                      ),
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
                // Save button
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Note',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Save note to API ───────────────────────────────────
  Future<void> _saveNote(String content) async {
    setState(() => _noteLoading = true);

    final response = await ApiService.post(
      '/notes/',
      body: {
        'lesson_id': widget.lessonId,
        'content': content,
      },
    );

    if (!mounted) return;
    setState(() => _noteLoading = false);

    if (response.isSuccess) {
      _showSnack('Note saved! ✏️', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed to save note', AppTheme.errorRed);
    }
  }

  // ── Snackbar helper ────────────────────────────────────
  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Font size decrease
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            onPressed: () {
              setState(() {
                if (_fontSize > 13) _fontSize -= 2;
              });
            },
            tooltip: 'Decrease text size',
          ),
          // Font size increase
          IconButton(
            icon: const Icon(Icons.text_increase, size: 20),
            onPressed: () {
              setState(() {
                if (_fontSize < 24) _fontSize += 2;
              });
            },
            tooltip: 'Increase text size',
          ),
          // Favorite toggle
          _favoriteLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
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
                  tooltip: _isFavorited
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddNoteDialog,
        backgroundColor: AppTheme.accentGoldDark,
        foregroundColor: AppTheme.primaryBlueDark,
        icon: const Icon(Icons.edit_note),
        label: const Text(
          'Add Note',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
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
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  // ── Error State ────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_outlined,
              size: 56,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load lesson',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lesson Content ─────────────────────────────────────
  Widget _buildContent() {
    final lesson = _lesson!;
    final content =
        lesson['content']?.toString() ?? 'No content available.';
    final memoryVerse = lesson['memory_verse']?.toString() ?? '';
    final topic = lesson['topic']?.toString() ?? '';
    final quarter = lesson['quarter']?.toString() ?? '';
    final language = lesson['language']?.toString() ?? 'english';
    final weekNumber = lesson['week_number']?.toString() ??
        lesson['week']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Lesson meta info ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                if (topic.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    topic,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (language.isNotEmpty)
                      _buildChip(
                        language[0].toUpperCase() +
                            language.substring(1),
                        AppTheme.primaryBlue,
                      ),
                    if (quarter.isNotEmpty)
                      _buildChip(quarter, AppTheme.accentGoldDark),
                    if (weekNumber.isNotEmpty)
                      _buildChip('Week $weekNumber', AppTheme.successGreen),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Memory verse ─────────────────────────────
          if (memoryVerse.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentGold,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.menu_book_outlined,
                        color: AppTheme.accentGoldDark,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'MEMORY VERSE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.primaryBlueDark,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    memoryVerse,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      height: 1.6,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Lesson content ────────────────────────────
          const Text(
            'LESSON CONTENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textHint,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.8,
              color: const Color(0xFF2D2D2D),
            ),
          ),

          const SizedBox(height: 40),

          // ── Bottom action hint ────────────────────────
          Center(
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 16,
                      color: AppTheme.textHint.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap "Add Note" to save your thoughts',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!ProgressCacheService.isCompleted(widget.lessonId))
                  ElevatedButton.icon(
                    onPressed: _markAsComplete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark as Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(220, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.successGreen),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.successGreen, size: 18),
                        SizedBox(width: 8),
                        Text('Completed',
                          style: TextStyle(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}



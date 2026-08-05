import 'package:flutter/material.dart';

import '../../services/manuals_loader_service.dart';
import '../../services/progress_cache_service.dart';
import '../../theme/app_theme.dart';
import '../lessons/lesson_detail_screen.dart';

// ─────────────────────────────────────────────────────────
// ManualDetailScreen
// Shows manual info + all lessons in the manual as a
// table-of-contents style list
// ─────────────────────────────────────────────────────────
class ManualDetailScreen extends StatefulWidget {
  final String manualId;
  final String manualTitle;

  const ManualDetailScreen({
    super.key,
    required this.manualId,
    required this.manualTitle,
  });

  @override
  State<ManualDetailScreen> createState() => _ManualDetailScreenState();
}

class _ManualDetailScreenState extends State<ManualDetailScreen> {
  Map<String, dynamic>? _manual;
  List<Map<String, dynamic>> _lessons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _manual = ManualsLoaderService.getManual(widget.manualId);
      _lessons = ManualsLoaderService.getLessonsForManual(widget.manualId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight;

    final year = _manual?['year']?.toString() ?? '';
    final period = _manual?['period']?.toString() ?? '';
    final language = _manual?['language']?.toString() ?? 'english';
    final description = _manual?['description']?.toString() ?? '';

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // ── Collapsing header with manual info ──
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.manualTitle,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlueDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          period.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlueDark,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        year,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            language.toLowerCase() == 'english'
                                ? Icons.language
                                : Icons.translate,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            language[0].toUpperCase() +
                                language.substring(1) +
                                ' • ${_lessons.length} lessons',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Description card ──
          if (description.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white12
                          : AppTheme.dividerColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: isDark
                            ? Colors.white54
                            : AppTheme.textHint,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Lessons list header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Text(
                    'TABLE OF CONTENTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white60
                          : AppTheme.textHint,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_lessons.length} lessons',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white38
                          : AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Lessons list ──
          _lessons.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmpty(isDark),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildLessonTile(_lessons[index], isDark),
                    childCount: _lessons.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildLessonTile(Map<String, dynamic> lesson, bool isDark) {
    final id = lesson['id']?.toString() ?? '';
    final number = lesson['lesson_number']?.toString() ?? '';
    final title = lesson['title']?.toString() ?? 'Untitled';
    final biblePassage = lesson['bible_passage']?.toString() ?? '';
    final lessonDate = lesson['lesson_date']?.toString() ?? '';
    final isCompleted = ProgressCacheService.isCompleted(id);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LessonDetailScreen(
              lessonId: id,
              title: title,
            ),
          ),
        ).then((_) {
          if (mounted) setState(() {});
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Lesson number circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.successGreen.withOpacity(0.15)
                    : AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: isCompleted
                    ? Border.all(
                        color: AppTheme.successGreen.withOpacity(0.4))
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_circle,
                        color: AppTheme.successGreen, size: 22)
                    : Text(
                        number,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + passage
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (biblePassage.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.menu_book,
                            size: 11,
                            color: isDark
                                ? Colors.white38
                                : AppTheme.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            biblePassage,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (lessonDate.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(lessonDate),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white38
                            : AppTheme.textHint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : AppTheme.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined,
              size: 48,
              color: isDark ? Colors.white24 : AppTheme.textHint),
          const SizedBox(height: 12),
          Text(
            'No lessons in this manual yet',
            style: TextStyle(
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
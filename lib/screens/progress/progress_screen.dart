import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../lessons/lesson_detail_screen.dart';

// ─────────────────────────────────────────────────────────
// ProgressScreen
// Shows reading progress stats + continue reading
// Uses /progress/stats and /progress/continue APIs
// ─────────────────────────────────────────────────────────
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _continueLesson;
  List<dynamic> _recentProgress = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = await Future.wait([
      ApiService.get('/progress/stats'),
      ApiService.get('/progress/continue'),
      ApiService.get('/progress/'),
    ]);

    if (!mounted) return;

    final statsResponse = results[0];
    final continueResponse = results[1];
    final progressResponse = results[2];

    if (statsResponse.isSuccess) {
      _stats = statsResponse.asMap;
    }
    if (continueResponse.isSuccess) {
      _continueLesson = continueResponse.asMap;
    }
    if (progressResponse.isSuccess) {
      _recentProgress = progressResponse.asList ?? [];
    }

    if (statsResponse.isError && continueResponse.isError) {
      setState(() {
        _error = statsResponse.error ?? 'Failed to load progress';
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Reading Progress'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProgress,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryBlue),
                  SizedBox(height: 16),
                  Text(
                    'Loading progress...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _fetchProgress,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(),
            const SizedBox(height: 20),
            if (_continueLesson != null) ...[
              _buildSectionTitle('Continue Reading'),
              _buildContinueCard(),
              const SizedBox(height: 20),
            ],
            if (_recentProgress.isNotEmpty) ...[
              _buildSectionTitle('Recent Activity'),
              _buildRecentList(),
            ],
            if (_continueLesson == null && _recentProgress.isEmpty)
              _buildEmptyProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final total = _stats?['total_lessons']?.toString() ?? '0';
    final completed = _stats?['completed']?.toString() ?? '0';
    final inProgress = _stats?['in_progress']?.toString() ?? '0';
    final percentage = _stats?['completion_percentage'] ??
        _stats?['percentage'] ?? 0;
    final percentNum = (percentage is num)
        ? percentage.toDouble()
        : double.tryParse(percentage.toString()) ?? 0.0;

    return Container(
      color: AppTheme.primaryBlue,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Progress',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              Text(
                '${percentNum.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percentNum / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.accentGold,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatTile('Total', total,
                  Icons.menu_book_outlined, Colors.white60),
              const SizedBox(width: 12),
              _buildStatTile('Completed', completed,
                  Icons.check_circle_outline, AppTheme.accentGold),
              const SizedBox(width: 12),
              _buildStatTile('In Progress', inProgress,
                  Icons.hourglass_bottom_outlined, Colors.lightBlueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildContinueCard() {
    final lesson = _continueLesson!;
    final title = lesson['title']?.toString() ?? 'Continue Reading';
    final topic = lesson['topic']?.toString() ?? '';
    final id = lesson['id']?.toString() ??
        lesson['lesson_id']?.toString() ?? '';
    final progress = lesson['progress_percentage'] ??
        lesson['percentage'] ?? 0;
    final progressNum = (progress is num)
        ? progress.toDouble()
        : double.tryParse(progress.toString()) ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: id.isNotEmpty
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LessonDetailScreen(lessonId: id, title: title),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.play_circle_outline,
                      color: AppTheme.accentGold, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Pick up where you left off',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (topic.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  topic,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (progressNum / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.accentGold),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${progressNum.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Continue →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlueDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      itemCount: _recentProgress.length,
      itemBuilder: (context, index) {
        final item = _recentProgress[index] as Map<String, dynamic>;
        return _buildProgressTile(item);
      },
    );
  }

  Widget _buildProgressTile(Map<String, dynamic> item) {
    final title = item['title']?.toString() ??
        item['lesson_title']?.toString() ?? 'Lesson';
    final id = item['lesson_id']?.toString() ??
        item['id']?.toString() ?? '';
    final progress = item['progress_percentage'] ??
        item['percentage'] ?? 0;
    final progressNum = (progress is num)
        ? progress.toDouble()
        : double.tryParse(progress.toString()) ?? 0.0;
    final isCompleted =
        progressNum >= 100 || item['is_completed'] == true;
    final updatedAt = item['updated_at']?.toString() ?? '';
    final formattedDate = _formatDate(updatedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: id.isNotEmpty
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LessonDetailScreen(lessonId: id, title: title),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.successGreen.withOpacity(0.1)
                      : AppTheme.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.hourglass_bottom,
                  color: isCompleted
                      ? AppTheme.successGreen
                      : AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  (progressNum / 100).clamp(0.0, 1.0),
                              backgroundColor: AppTheme.dividerColor,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted
                                    ? AppTheme.successGreen
                                    : AppTheme.primaryBlue,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${progressNum.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? AppTheme.successGreen
                                : AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    if (formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textHint),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppTheme.textHint, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 56,
              color: AppTheme.textHint.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No reading activity yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start reading lessons and your\nprogress will appear here',
              style: TextStyle(fontSize: 13, color: AppTheme.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 56, color: AppTheme.textHint),
            const SizedBox(height: 16),
            const Text(
              'Could not load progress',
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
                  fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchProgress,
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

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }
}

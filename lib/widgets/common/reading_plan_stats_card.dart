import 'package:flutter/material.dart';

import '../../services/reading_plan_service.dart';
import '../../theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────
/// ReadingPlanStatsCard
/// Displays user's Bible reading plan progress:
/// - Current streak (🔥)
/// - Total chapters read (📚)
/// - Longest streak (🏆)
/// - Year progress bar (X / 365)
/// ─────────────────────────────────────────────────────────
class ReadingPlanStatsCard extends StatefulWidget {
  const ReadingPlanStatsCard({super.key});

  @override
  State<ReadingPlanStatsCard> createState() => _ReadingPlanStatsCardState();
}

class _ReadingPlanStatsCardState extends State<ReadingPlanStatsCard> {
  bool _loading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await ReadingPlanService.getProgress();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue,
                  strokeWidth: 2,
                ),
              ),
            )
          : _stats == null
              ? _buildError(isDark)
              : _buildContent(isDark),
    );
  }

  Widget _buildError(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            color: isDark ? Colors.white38 : AppTheme.textHint,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load reading progress.',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white70 : AppTheme.primaryBlue,
            ),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final totalRead = (_stats!['total_read'] ?? 0) as int;
    final currentStreak = (_stats!['current_streak'] ?? 0) as int;
    final longestStreak = (_stats!['longest_streak'] ?? 0) as int;
    final year = (_stats!['year'] ?? DateTime.now().year) as int;
    final daysRead = _stats!['days_read_this_year'] as List<dynamic>? ?? [];
    final daysReadCount = daysRead.length;
    final yearProgress = (daysReadCount / 365).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_stories,
                  color: AppTheme.accentGoldDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bible Reading Plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Your $year journey through Scripture',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.refresh,
                  color: isDark ? Colors.white54 : AppTheme.textHint,
                  size: 18,
                ),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  isDark: isDark,
                  emoji: '🔥',
                  value: '$currentStreak',
                  label: 'Day Streak',
                  color: currentStreak > 0
                      ? const Color(0xFFEF6C00)
                      : (isDark ? Colors.white38 : AppTheme.textHint),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  isDark: isDark,
                  emoji: '📚',
                  value: '$totalRead',
                  label: totalRead == 1 ? 'Chapter Read' : 'Chapters Read',
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (isDark
                      ? AppTheme.accentGold
                      : AppTheme.accentGoldDark)
                  .withOpacity(isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Longest streak',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : AppTheme.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '$longestStreak ${longestStreak == 1 ? "day" : "days"}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.accentGoldDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '$year Progress',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                '$daysReadCount / 365',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: yearProgress,
              minHeight: 8,
              backgroundColor:
                  isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.accentGoldDark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(yearProgress * 100).toStringAsFixed(1)}% complete',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required bool isDark,
    required String emoji,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.25 : 0.20),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
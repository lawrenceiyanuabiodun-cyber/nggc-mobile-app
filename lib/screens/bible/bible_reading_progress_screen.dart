import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common/reading_plan_stats_card.dart';
import '../../services/reading_plan_service.dart';
import 'reading_plan_reader_screen.dart';

/// ─────────────────────────────────────────────────────────
/// BibleReadingProgressScreen
/// Full-page view of user's Bible reading plan progress.
/// Includes: stats card + calendar of past reads + quick actions.
/// ─────────────────────────────────────────────────────────
class BibleReadingProgressScreen extends ConsumerStatefulWidget {
  const BibleReadingProgressScreen({super.key});

  @override
  ConsumerState<BibleReadingProgressScreen> createState() =>
      _BibleReadingProgressScreenState();
}

class _BibleReadingProgressScreenState
    extends ConsumerState<BibleReadingProgressScreen> {
  bool _loadingToday = false;

  Future<void> _openToday() async {
    if (_loadingToday) return;
    setState(() => _loadingToday = true);
    final reading = await ReadingPlanService.getToday();
    if (!mounted) return;
    setState(() => _loadingToday = false);

    if (reading == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not load today's reading. Try again."),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (reading['is_rest_day'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rest day 🌿 — no scheduled reading today.'),
          backgroundColor: AppTheme.primaryBlue,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingPlanReaderScreen(reading: reading),
      ),
    );
    if (mounted) setState(() {}); // trigger stats refresh via new widget instance
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Reading Progress'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats card (fetches fresh data on mount)
            const ReadingPlanStatsCard(),

            const SizedBox(height: 20),

            _buildSectionTitle('Actions', isDark),
            _buildActionCard(
              isDark: isDark,
              icon: Icons.menu_book,
              iconColor: AppTheme.primaryBlue,
              title: "Today's Reading",
              subtitle: 'Open the chapter for today',
              loading: _loadingToday,
              onTap: _openToday,
            ),

            const SizedBox(height: 20),

            _buildSectionTitle('About the Plan', isDark),
            _buildInfoCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white54 : AppTheme.textHint,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool loading = false,
  }) {
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
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryBlue,
                      ),
                    )
                  : Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white38 : AppTheme.textHint,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            isDark,
            Icons.calendar_today_outlined,
            '365 chapters',
            'One curated chapter for every day of the year',
          ),
          const SizedBox(height: 12),
          _infoRow(
            isDark,
            Icons.local_fire_department_outlined,
            'Build a streak',
            'Mark each day as read to keep your streak alive',
          ),
          const SizedBox(height: 12),
          _infoRow(
            isDark,
            Icons.notifications_outlined,
            'Daily reminder',
            'Push notification arrives at 7:00 AM Lagos time',
          ),
          const SizedBox(height: 12),
          _infoRow(
            isDark,
            Icons.replay_outlined,
            'Yearly cycle',
            'Plan restarts January 1st every year',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(bool isDark, IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white54 : AppTheme.primaryBlue,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
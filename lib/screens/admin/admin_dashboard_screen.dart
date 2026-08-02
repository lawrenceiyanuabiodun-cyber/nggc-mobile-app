import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'admin_announcements_screen.dart';
import 'admin_events_screen.dart';
import 'admin_lessons_screen.dart';
import 'admin_users_screen.dart';

// ─────────────────────────────────────────────────────────
// AdminDashboardScreen
// Main admin panel — shows stats + quick actions
// Only accessible when user.isAdmin == true
// ─────────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await ApiService.get('/admin/stats/overview');

    if (!mounted) return;

    if (response.isSuccess) {
      setState(() {
        _stats = response.asMap;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load stats';
        _isLoading = false;
      });
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppTheme.primaryBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryBlue,
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Admin Header ─────────────────────────
              _buildHeader(user?.firstName ?? 'Admin'),

              const SizedBox(height: 20),

              // ── Stats Cards ──────────────────────────
              _buildSectionTitle('Overview'),
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    )
                  : _error != null
                      ? _buildStatsError()
                      : _buildStatsGrid(),

              const SizedBox(height: 20),

              // ── Quick Actions ────────────────────────
              _buildSectionTitle('Manage'),
              _buildAdminActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────
  Widget _buildHeader(String name) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryBlueDark,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentGold),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: AppTheme.accentGold, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'ADMINISTRATOR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Welcome, $name',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'NGGC Sunday School Admin Panel',
            style: TextStyle(fontSize: 13, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  // ── Section Title ──────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textHint,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Stats Grid ─────────────────────────────────────────
  Widget _buildStatsGrid() {
    final totalUsers = _stats?['total_users']?.toString() ?? '0';
    final totalLessons = _stats?['total_lessons']?.toString() ?? '0';
    final totalAnnouncements =
        _stats?['total_announcements']?.toString() ?? '0';
    final totalEvents = _stats?['total_events']?.toString() ?? '0';
    final activeUsers = _stats?['active_users']?.toString() ?? '0';
    final totalManuals = _stats?['total_manuals']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _buildStatCard('Total Users', totalUsers,
              Icons.people_outline, const Color(0xFF1565C0)),
          _buildStatCard('Active Users', activeUsers,
              Icons.person_pin_outlined, const Color(0xFF2E7D32)),
          _buildStatCard('Lessons', totalLessons,
              Icons.school_outlined, const Color(0xFF6A1B9A)),
          _buildStatCard('Announcements', totalAnnouncements,
              Icons.campaign_outlined, const Color(0xFFE65100)),
          _buildStatCard('Events', totalEvents,
              Icons.event_outlined, const Color(0xFF00838F)),
          _buildStatCard('Manuals', totalManuals,
              Icons.book_outlined, const Color(0xFF4E342E)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_outlined,
              size: 40, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Admin Actions ──────────────────────────────────────
  Widget _buildAdminActions() {
    final actions = [
      _AdminAction(
        icon: Icons.campaign,
        label: 'Announcements',
        subtitle: 'Create, pin, delete',
        color: const Color(0xFFE65100),
        onTap: () => _navigateTo(const AdminAnnouncementsScreen()),
      ),
      _AdminAction(
        icon: Icons.event,
        label: 'Events',
        subtitle: 'Create, feature, delete',
        color: const Color(0xFF00838F),
        onTap: () => _navigateTo(const AdminEventsScreen()),
      ),
      _AdminAction(
        icon: Icons.school,
        label: 'Lessons',
        subtitle: 'View and manage lessons',
        color: const Color(0xFF6A1B9A),
        onTap: () => _navigateTo(const AdminLessonsScreen()),
      ),
      _AdminAction(
        icon: Icons.people,
        label: 'Users',
        subtitle: 'View users and roles',
        color: const Color(0xFF1565C0),
        onTap: () => _navigateTo(const AdminUsersScreen()),
      ),
    ];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: actions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              final isLast = index == actions.length - 1;
              return _buildActionTile(action, isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(_AdminAction action, bool isLast) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            )
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppTheme.dividerColor),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    action.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
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
}

class _AdminAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

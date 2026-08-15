import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/unread_tracker.dart';
import '../../theme/app_theme.dart';
import '../announcements/announcements_screen.dart';
import '../sermons/sermons_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  bool _verseUnread = false;
  bool _readingUnread = false;
  Map<String, dynamic>? _verseData;
  Map<String, dynamic>? _readingData;
  List<Map<String, dynamic>> _unreadAnnouncements = [];
  List<Map<String, dynamic>> _unreadSermons = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    // Check unread flags first (fast, local)
    final verseUnread = await UnreadTracker.isVerseUnread();
    final readingUnread = await UnreadTracker.isReadingUnread();

    // Fetch all in parallel
    final results = await Future.wait([
      verseUnread ? ApiService.get('/verses/daily') : Future.value(null),
      readingUnread ? ApiService.get('/reading-plan/today') : Future.value(null),
      ApiService.get('/announcements'),
      ApiService.get('/sermons?limit=100'),
    ]);

    Map<String, dynamic>? verseData;
    Map<String, dynamic>? readingData;
    List<Map<String, dynamic>> unreadAnn = [];
    List<Map<String, dynamic>> unreadSer = [];

    if (verseUnread && results[0] != null) {
      final r = results[0] as ApiResponse;
      if (r.isSuccess) verseData = r.asMap;
    }
    if (readingUnread && results[1] != null) {
      final r = results[1] as ApiResponse;
      if (r.isSuccess) readingData = r.asMap;
    }
    if (results[2] != null) {
      final r = results[2] as ApiResponse;
      if (r.isSuccess) {
        final list = r.asList ?? [];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty && await UnreadTracker.isAnnouncementUnread(id)) {
              unreadAnn.add(item);
            }
          }
        }
      }
    }
    if (results[3] != null) {
      final r = results[3] as ApiResponse;
      if (r.isSuccess) {
        final list = r.asList ?? [];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty && await UnreadTracker.isSermonUnread(id)) {
              unreadSer.add(item);
            }
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _verseUnread = verseUnread;
      _readingUnread = readingUnread;
      _verseData = verseData;
      _readingData = readingData;
      _unreadAnnouncements = unreadAnn;
      _unreadSermons = unreadSer;
      _isLoading = false;
    });
  }

  Future<void> _openVerse() async {
    await UnreadTracker.markVerseSeen();
    if (!mounted) return;
    final ref = _verseData?['reference']?.toString() ?? '';
    final text = _verseData?['text']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(text, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    setState(() => _verseUnread = false);
  }

  Future<void> _openReading() async {
    await UnreadTracker.markReadingSeen();
    if (!mounted) return;
    setState(() => _readingUnread = false);
    // Navigate to today's reading if you have a route
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marked as read. Open Bible tab for full reading.'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  Future<void> _openAnnouncement(Map<String, dynamic> a) async {
    final id = a['id']?.toString() ?? '';
    if (id.isNotEmpty) await UnreadTracker.markAnnouncementRead(id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
    );
  }

  Future<void> _openSermon(Map<String, dynamic> s) async {
    final id = s['id']?.toString() ?? '';
    if (id.isNotEmpty) await UnreadTracker.markSermonViewed(id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SermonsScreen()),
    );
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      return DateFormat('MMM d, y').format(d);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = (_verseUnread ? 1 : 0) +
        (_readingUnread ? 1 : 0) +
        _unreadAnnouncements.length +
        _unreadSermons.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight,
      appBar: AppBar(
        title: Text('Notifications${total > 0 ? " ($total)" : ""}'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : total == 0
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_verseUnread && _verseData != null)
                        _buildTile(
                          icon: Icons.menu_book,
                          color: const Color(0xFF6A1B9A),
                          title: 'Daily Bible Verse',
                          subtitle: _verseData!['reference']?.toString() ?? '',
                          onTap: _openVerse,
                        ),
                      if (_readingUnread)
                        _buildTile(
                          icon: Icons.auto_stories,
                          color: AppTheme.successGreen,
                          title: 'Daily Bible Reading',
                          subtitle: _readingData?['reference']?.toString() ??
                              'Today\'s reading is ready',
                          onTap: _openReading,
                        ),
                      ..._unreadAnnouncements.map((a) => _buildTile(
                            icon: Icons.campaign,
                            color: AppTheme.primaryBlue,
                            title: a['title']?.toString() ?? 'Announcement',
                            subtitle: _formatDate(
                                a['created_at']?.toString() ?? ''),
                            onTap: () => _openAnnouncement(a),
                          )),
                      ..._unreadSermons.map((s) {
                        final mt = s['media_type']?.toString() ?? 'audio';
                        return _buildTile(
                          icon: mt == 'video' ? Icons.play_circle : Icons.mic,
                          color: AppTheme.accentGoldDark,
                          title: s['title']?.toString() ?? 'New Sermon',
                          subtitle:
                              '${mt == 'video' ? 'Video' : 'Audio'} - ${_formatDate(s['sermon_date']?.toString() ?? '')}',
                          onTap: () => _openSermon(s),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.notifications_none, size: 72, color: AppTheme.textHint),
          SizedBox(height: 16),
          Text('All caught up!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('No new notifications.',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppTheme.errorRed,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
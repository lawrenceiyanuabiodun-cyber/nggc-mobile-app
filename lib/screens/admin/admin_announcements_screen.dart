import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// AdminAnnouncementsScreen
// Create, pin, delete announcements
// ─────────────────────────────────────────────────────────
class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends State<AdminAnnouncementsScreen> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() { _isLoading = true; _error = null; });
    final response = await ApiService.get('/announcements/all');
    if (!mounted) return;
    if (response.isSuccess) {
      setState(() {
        _announcements = response.asList ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load';
        _isLoading = false;
      });
    }
  }

  // ── Toggle pin ─────────────────────────────────────────
  Future<void> _togglePin(String id) async {
    final response =
        await ApiService.post('/announcements/$id/toggle-pin');
    if (!mounted) return;
    if (response.isSuccess) {
      _fetchAnnouncements();
      _showSnack('Pin status updated', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed', AppTheme.errorRed);
    }
  }

  // ── Toggle active ──────────────────────────────────────
  Future<void> _toggleActive(String id) async {
    final response =
        await ApiService.post('/announcements/$id/toggle-active');
    if (!mounted) return;
    if (response.isSuccess) {
      _fetchAnnouncements();
      _showSnack('Status updated', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed', AppTheme.errorRed);
    }
  }

  // ── Delete ─────────────────────────────────────────────
  Future<void> _delete(String id, String title) async {
    final confirm = await _confirmDialog('Delete "$title"?',
        'This cannot be undone.');
    if (confirm != true) return;
    final response = await ApiService.delete('/announcements/$id');
    if (!mounted) return;
    if (response.isSuccess) {
      _fetchAnnouncements();
      _showSnack('Deleted', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed', AppTheme.errorRed);
    }
  }

  // ── Create ─────────────────────────────────────────────
  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    bool isPinned = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('New Announcement',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isPinned,
                      onChanged: (v) =>
                          setDlgState(() => isPinned = v ?? false),
                      activeColor: AppTheme.primaryBlue,
                    ),
                    const Text('Pin this announcement'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    bodyCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final response = await ApiService.post(
                  '/announcements',
                  body: {
                    'title': titleCtrl.text.trim(),
                    'body': bodyCtrl.text.trim(),
                    'is_pinned': isPinned,
                  },
                );
                if (!mounted) return;
                if (response.isSuccess) {
                  _fetchAnnouncements();
                  _showSnack('Announcement created!',
                      AppTheme.successGreen);
                } else {
                  _showSnack(
                      response.error ?? 'Failed', AppTheme.errorRed);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: AppTheme.primaryBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnnouncements,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue))
          : _error != null
              ? _buildError()
              : _announcements.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _fetchAnnouncements,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final item = _announcements[index] as Map<String, dynamic>;
          return _buildCard(item);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    final body = item['body']?.toString() ??
        item['content']?.toString() ?? '';
    final isPinned = item['is_pinned'] == true;
    final isActive = item['is_active'] != false;
    final createdAt = item['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPinned)
                  const Icon(Icons.push_pin,
                      size: 14, color: AppTheme.accentGoldDark),
                if (isPinned) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.successGreen.withOpacity(0.1)
                        : AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textHint),
              ),
            ],
            const SizedBox(height: 10),
            // Action buttons
            Row(
              children: [
                _actionBtn(
                  icon: isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  label: isPinned ? 'Unpin' : 'Pin',
                  color: AppTheme.accentGoldDark,
                  onTap: () => _togglePin(id),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  label: isActive ? 'Hide' : 'Show',
                  color: AppTheme.primaryBlue,
                  onTap: () => _toggleActive(id),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.errorRed, size: 20),
                  onPressed: () => _delete(id, title),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined,
              size: 48, color: AppTheme.textHint),
          SizedBox(height: 12),
          Text('No announcements yet',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchAnnouncements,
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

  Future<bool?> _confirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue)),
        content: Text(message,
            style: const TextStyle(color: AppTheme.textSecondary)),
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }
}

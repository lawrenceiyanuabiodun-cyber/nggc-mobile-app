import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() { _isLoading = true; _error = null; });
    final response = await ApiService.get('/events/all');
    if (!mounted) return;
    if (response.isSuccess) {
      setState(() {
        _events = response.asList ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load events';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFeature(String id) async {
    final response = await ApiService.post('/events/$id/toggle-feature');
    if (!mounted) return;
    if (response.isSuccess) {
      _fetchEvents();
      _showSnack('Feature status updated', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed', AppTheme.errorRed);
    }
  }

  Future<void> _delete(String id, String title) async {
    final confirm = await _confirmDialog('Delete "$title"?', 'This cannot be undone.');
    if (confirm != true) return;
    final response = await ApiService.delete('/events/$id');
    if (!mounted) return;
    if (response.isSuccess) {
      _fetchEvents();
      _showSnack('Event deleted', AppTheme.successGreen);
    } else {
      _showSnack(response.error ?? 'Failed', AppTheme.errorRed);
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    bool isFeatured = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Event',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Date & Time (YYYY-MM-DD HH:MM)',
                    border: OutlineInputBorder(),
                    hintText: '2025-01-15 10:00',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isFeatured,
                      onChanged: (v) => setDlgState(() => isFeatured = v ?? false),
                      activeColor: AppTheme.primaryBlue,
                    ),
                    const Text('Feature this event'),
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
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final response = await ApiService.post(
                  '/events',
                  body: {
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'location': locationCtrl.text.trim(),
                    'event_date': dateCtrl.text.trim(),
                    'is_featured': isFeatured,
                  },
                );
                if (!mounted) return;
                if (response.isSuccess) {
                  _fetchEvents();
                  _showSnack('Event created!', AppTheme.successGreen);
                } else {
                  _showSnack(response.error ?? 'Failed', AppTheme.errorRed);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create'),
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
        title: const Text('Events'),
        backgroundColor: AppTheme.primaryBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchEvents),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : _error != null
              ? _buildError()
              : _events.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _fetchEvents,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index] as Map<String, dynamic>;
          return _buildCard(event);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> event) {
    final id = event['id']?.toString() ?? '';
    final title = event['title']?.toString() ?? '';
    final location = event['location']?.toString() ?? '';
    final isFeatured = event['is_featured'] == true;
    final rsvpCount = event['rsvp_count'] ?? 0;
    final rawDate = event['event_date']?.toString() ?? event['date']?.toString() ?? '';
    final formattedDate = _formatDate(rawDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                ),
                if (isFeatured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Featured',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentGoldDark)),
                  ),
              ],
            ),
            if (formattedDate.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppTheme.primaryBlue),
                const SizedBox(width: 4),
                Text(formattedDate,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.primaryBlue)),
              ]),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.people_outline,
                  size: 12, color: AppTheme.textHint),
              const SizedBox(width: 4),
              Text('$rsvpCount attending',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textHint)),
            ]),
            const SizedBox(height: 10),
            Row(
              children: [
                _actionBtn(
                  icon: isFeatured ? Icons.star : Icons.star_outline,
                  label: isFeatured ? 'Unfeature' : 'Feature',
                  color: AppTheme.accentGoldDark,
                  onTap: () => _toggleFeature(id),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.errorRed, size: 20),
                  onPressed: () => _delete(id, title),
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
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
          Icon(Icons.event_outlined, size: 48, color: AppTheme.textHint),
          SizedBox(height: 12),
          Text('No events yet', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchEvents,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (_) { return raw; }
  }
}

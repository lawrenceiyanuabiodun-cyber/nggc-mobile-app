import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// EventsScreen
// Shows church events from /events API
// Supports RSVP via /events/{id}/rsvp
// ─────────────────────────────────────────────────────────
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;
  String? _error;

  // Track which events are being RSVP'd (to show per-card loading)
  final Set<String> _rsvpLoading = {};

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await ApiService.get('/events');

    if (!mounted) return;

    if (response.isSuccess) {
      final list = response.asList ?? [];
      // Sort by event date ascending (soonest first)
      list.sort((a, b) {
        final aDate = a['event_date']?.toString() ??
            a['date']?.toString() ?? '';
        final bDate = b['event_date']?.toString() ??
            b['date']?.toString() ?? '';
        return aDate.compareTo(bDate);
      });
      setState(() {
        _events = list;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load events';
        _isLoading = false;
      });
    }
  }

  // ── RSVP to event ──────────────────────────────────────
  Future<void> _rsvp(String eventId) async {
    setState(() => _rsvpLoading.add(eventId));

    final response = await ApiService.post('/events/$eventId/rsvp');

    if (!mounted) return;
    setState(() => _rsvpLoading.remove(eventId));

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('RSVP confirmed!'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      // Refresh list to show updated RSVP count
      _fetchEvents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'RSVP failed. Try again.'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ── Cancel RSVP ────────────────────────────────────────
  Future<void> _cancelRsvp(String eventId) async {
    setState(() => _rsvpLoading.add(eventId));

    final response = await ApiService.post('/events/$eventId/cancel');

    if (!mounted) return;
    setState(() => _rsvpLoading.remove(eventId));

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RSVP cancelled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Church Events'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
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
                    'Loading events...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Server may take up to 60s to wake up',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? _buildError()
              : _events.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
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
              'Could not load events',
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
              onPressed: _fetchEvents,
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

  // ── Empty State ────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_outlined,
            size: 56,
            color: AppTheme.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No upcoming events',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for church events',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  // ── Events List ────────────────────────────────────────
  Widget _buildList() {
    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _fetchEvents,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index] as Map<String, dynamic>;
          return _buildEventCard(event);
        },
      ),
    );
  }

  // ── Event Card ─────────────────────────────────────────
  Widget _buildEventCard(Map<String, dynamic> event) {
    final id = event['id']?.toString() ?? '';
    final title = event['title']?.toString() ?? 'Event';
    final description = event['description']?.toString() ?? '';
    final location = event['location']?.toString() ?? '';
    final isFeatured = event['is_featured'] == true;
    final rsvpCount = event['rsvp_count'] ?? event['rsvps_count'] ?? 0;
    final userRsvpd = event['user_rsvpd'] == true ||
        event['has_rsvpd'] == true;

    final rawDate = event['event_date']?.toString() ??
        event['date']?.toString() ?? '';
    final formattedDate = _formatDate(rawDate);
    final formattedTime = _formatTime(rawDate);
    final isUpcoming = _isUpcoming(rawDate);
    final isLoadingRsvp = _rsvpLoading.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isFeatured
            ? Border.all(color: AppTheme.accentGold, width: 1.5)
            : Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: isFeatured
                ? AppTheme.accentGold.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Top Strip ───────────────────────────
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: isFeatured
                  ? AppTheme.accentGold
                  : isUpcoming
                      ? AppTheme.primaryBlue
                      : AppTheme.textHint,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title Row ─────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (isFeatured)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Featured',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlueDark,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Date & Time ───────────────────────
                if (formattedDate.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (formattedTime.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),

                // ── Location ──────────────────────────
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Description ───────────────────────
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                // ── Footer: RSVP Count + Button ───────
                Row(
                  children: [
                    // RSVP count
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 15,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$rsvpCount attending',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // RSVP Button
                    if (isUpcoming && id.isNotEmpty)
                      SizedBox(
                        height: 36,
                        child: isLoadingRsvp
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryBlue,
                                ),
                              )
                            : userRsvpd
                                ? OutlinedButton.icon(
                                    onPressed: () => _cancelRsvp(id),
                                    icon: const Icon(Icons.check, size: 14),
                                    label: const Text('Going'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.successGreen,
                                      side: const BorderSide(
                                        color: AppTheme.successGreen,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () => _rsvp(id),
                                    icon: const Icon(Icons.add, size: 14),
                                    label: const Text('RSVP'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                      ),

                    // Past event badge
                    if (!isUpcoming)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.textHint.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Past Event',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────
  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('EEE, MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  bool _isUpcoming(String raw) {
    if (raw.isEmpty) return true;
    try {
      final dt = DateTime.parse(raw).toLocal();
      return dt.isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }
}

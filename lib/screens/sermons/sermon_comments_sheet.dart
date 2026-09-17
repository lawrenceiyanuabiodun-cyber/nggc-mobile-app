import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../services/sermon_interaction_service.dart';
import '../../theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────
/// SermonCommentsSheet
/// Interactive comments and reflections bottom sheet.
/// ─────────────────────────────────────────────────────────
class SermonCommentsSheet extends ConsumerStatefulWidget {
  final String sermonId;
  final String sermonTitle;

  const SermonCommentsSheet({
    super.key,
    required this.sermonId,
    required this.sermonTitle,
  });

  static Future<void> show(BuildContext context, String sermonId, String sermonTitle) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SermonCommentsSheet(
        sermonId: sermonId,
        sermonTitle: sermonTitle,
      ),
    );
  }

  @override
  ConsumerState<SermonCommentsSheet> createState() => _SermonCommentsSheetState();
}

class _SermonCommentsSheetState extends ConsumerState<SermonCommentsSheet> {
  final TextEditingController _textController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadComments() {
    setState(() {
      _comments = SermonInteractionService.getComments(widget.sermonId);
    });
  }

  Future<void> _postComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final userName = user != null && user.firstName.isNotEmpty
        ? user.fullName
        : 'Member';
    final userPhone = user?.phone ?? '';

    setState(() => _isPosting = true);

    await SermonInteractionService.addComment(
      sermonId: widget.sermonId,
      userName: userName,
      userPhone: userPhone,
      text: text,
    );

    _textController.clear();
    FocusScope.of(context).unfocus();

    if (!mounted) return;
    setState(() {
      _isPosting = false;
      _loadComments();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reflection posted! 🙏'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    await SermonInteractionService.deleteComment(widget.sermonId, commentId);
    if (!mounted) return;
    _loadComments();
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('MMM d, h:mma').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final userPhone = currentUser?.phone ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.forum_outlined, color: AppTheme.primaryBlue, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reflections & Comments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        widget.sermonTitle,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Comments List
          Expanded(
            child: _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: isDark ? Colors.white24 : Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No reflections yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Be the first to share what touched your heart!',
                          style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = _comments[index];
                      final name = c['user_name']?.toString() ?? 'Member';
                      final text = c['text']?.toString() ?? '';
                      final time = _formatDate(c['created_at']?.toString() ?? '');
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                      final isMine = userPhone.isNotEmpty && c['user_phone'] == userPhone;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A3E) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.primaryBlue.withOpacity(0.15),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : AppTheme.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textHint,
                                        ),
                                      ),
                                      if (isMine) ...[
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () => _deleteComment(c['id']?.toString() ?? ''),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            size: 14,
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : AppTheme.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Input Box
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Share your takeaway or reflection...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isPosting ? null : _postComment,
                  icon: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  color: AppTheme.primaryBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
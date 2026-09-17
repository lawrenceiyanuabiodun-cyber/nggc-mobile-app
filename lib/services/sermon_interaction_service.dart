import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// ─────────────────────────────────────────────────────────
/// SermonInteractionService
/// Manages emoji reactions and user comments on sermons.
/// ─────────────────────────────────────────────────────────
class SermonInteractionService {
  SermonInteractionService._();

  static const String _reactionsBox = 'sermon_reactions';
  static const String _commentsBox = 'sermon_comments';

  static const List<Map<String, String>> availableReactions = [
    {'key': 'amen', 'emoji': '🙏', 'label': 'Amen'},
    {'key': 'love', 'emoji': '❤️', 'label': 'Love'},
    {'key': 'fire', 'emoji': '🔥', 'label': 'Power'},
    {'key': 'praise', 'emoji': '🙌', 'label': 'Praise'},
    {'key': 'grace', 'emoji': '✝️', 'label': 'Grace'},
  ];

  static Future<void> ensureInitialized() async {
    if (!Hive.isBoxOpen(_reactionsBox)) await Hive.openBox(_reactionsBox);
    if (!Hive.isBoxOpen(_commentsBox)) await Hive.openBox(_commentsBox);
  }

  // ─── REACTIONS ──────────────────────────────────────────

  /// Get user's selected reaction for a sermon (e.g. 'amen', 'fire', or null)
  static String? getUserReaction(String sermonId) {
    if (!Hive.isBoxOpen(_reactionsBox)) return null;
    final box = Hive.box(_reactionsBox);
    return box.get('user_rx_$sermonId') as String?;
  }

  /// Get reaction counts map: {'amen': 12, 'love': 8, ...}
  static Map<String, int> getReactionCounts(String sermonId) {
    if (!Hive.isBoxOpen(_reactionsBox)) return {};
    final box = Hive.box(_reactionsBox);
    final raw = box.get('counts_$sermonId');
    if (raw is Map) {
      return Map<String, int>.from(
        raw.map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0)),
      );
    }
    return {};
  }

  /// Toggle reaction on a sermon
  static Future<void> toggleReaction(String sermonId, String reactionKey) async {
    await ensureInitialized();
    final box = Hive.box(_reactionsBox);
    final current = getUserReaction(sermonId);
    final counts = getReactionCounts(sermonId);

    if (current == reactionKey) {
      // Remove reaction
      await box.delete('user_rx_$sermonId');
      counts[reactionKey] = (counts[reactionKey] ?? 1) - 1;
      if (counts[reactionKey]! <= 0) counts.remove(reactionKey);
    } else {
      // Change or set reaction
      if (current != null) {
        counts[current] = (counts[current] ?? 1) - 1;
        if (counts[current]! <= 0) counts.remove(current);
      }
      await box.put('user_rx_$sermonId', reactionKey);
      counts[reactionKey] = (counts[reactionKey] ?? 0) + 1;
    }

    await box.put('counts_$sermonId', counts);
  }

  // ─── COMMENTS ───────────────────────────────────────────

  /// Get all comments for a sermon
  static List<Map<String, dynamic>> getComments(String sermonId) {
    if (!Hive.isBoxOpen(_commentsBox)) return [];
    final box = Hive.box(_commentsBox);
    final raw = box.get('comments_$sermonId');
    if (raw == null) return [];
    try {
      final decoded = json.decode(raw as String);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (_) {}
    return [];
  }

  /// Add a comment to a sermon
  static Future<Map<String, dynamic>> addComment({
    required String sermonId,
    required String userName,
    required String userPhone,
    required String text,
  }) async {
    await ensureInitialized();
    final box = Hive.box(_commentsBox);
    final current = getComments(sermonId);

    final newComment = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sermon_id': sermonId,
      'user_name': userName,
      'user_phone': userPhone,
      'text': text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    current.insert(0, newComment);
    await box.put('comments_$sermonId', json.encode(current));
    return newComment;
  }

  /// Delete a comment
  static Future<void> deleteComment(String sermonId, String commentId) async {
    await ensureInitialized();
    final box = Hive.box(_commentsBox);
    final current = getComments(sermonId);
    current.removeWhere((c) => c['id']?.toString() == commentId);
    await box.put('comments_$sermonId', json.encode(current));
  }
}
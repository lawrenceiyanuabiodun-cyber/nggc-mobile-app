import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/favorites_cache_service.dart';
import '../../theme/app_theme.dart';
import '../lessons/lesson_detail_screen.dart';

// ─────────────────────────────────────────────────────
// FavoritesScreen
// Offline-viewable via FavoritesCacheService.
// Remove requires internet.
// ─────────────────────────────────────────────────────
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<dynamic> _favorites = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String? _error;
  final Set<String> _removingIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Step 1: Show cached data instantly
    final cached = FavoritesCacheService.getAll();
    if (cached.isNotEmpty) {
      setState(() {
        _favorites = cached;
        _isLoading = false;
      });
    }

    // Step 2: Try API refresh
    final response = await ApiService.get('/favorites/');

    if (!mounted) return;

    if (response.isSuccess) {
      final fresh = response.asList ?? [];
      await FavoritesCacheService.saveAll(fresh);
      setState(() {
        _favorites = fresh;
        _isLoading = false;
        _isOffline = false;
        _error = null;
      });
    } else {
      if (cached.isNotEmpty) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to load favorites';
          _isOffline = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFavorite(String favoriteId, String title) async {
    if (_isOffline) {
      _showOfflineMessage('remove');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Remove Favorite',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        content: Text(
          'Remove "$title" from your favorites?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _removingIds.add(favoriteId));

    final response = await ApiService.delete('/favorites/$favoriteId');

    if (!mounted) return;
    setState(() => _removingIds.remove(favoriteId));

    if (response.isSuccess) {
      setState(() {
        _favorites.removeWhere(
          (f) => f['id']?.toString() == favoriteId,
        );
      });
      await FavoritesCacheService.saveAll(_favorites);
      _showSnack('Removed from favorites', AppTheme.primaryBlue);
    } else {
      _showSnack(response.error ?? 'Failed to remove', AppTheme.errorRed);
    }
  }

  void _showOfflineMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'You are offline. Connect to the internet to $action favorites.'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),
          Expanded(
            child: _isLoading && _favorites.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryBlue),
                        SizedBox(height: 16),
                        Text(
                          'Loading favorites...',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : _error != null && _favorites.isEmpty
                    ? _buildError()
                    : _favorites.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Offline - showing saved favorites (read-only)',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _loadFavorites,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 24),
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final item = _favorites[index] as Map<String, dynamic>;
          return _buildFavoriteCard(item);
        },
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> item) {
    final favoriteId = item['id']?.toString() ?? '';
    final lesson = item['lesson'] as Map<String, dynamic>? ?? item;
    final lessonId = lesson['lesson_id']?.toString() ??
        lesson['id']?.toString() ?? '';
    final title = lesson['title']?.toString() ?? 'Untitled Lesson';
    final topic = lesson['topic']?.toString() ?? '';
    final language = lesson['language']?.toString() ?? 'english';
    final isRemoving = _removingIds.contains(favoriteId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isRemoving
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LessonDetailScreen(
                      lessonId: lessonId,
                      title: title,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: AppTheme.errorRed,
                  size: 22,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (topic.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        topic,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        language[0].toUpperCase() + language.substring(1),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isRemoving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.errorRed,
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: _isOffline
                            ? AppTheme.textHint
                            : AppTheme.errorRed,
                        size: 20,
                      ),
                      onPressed: () => _removeFavorite(favoriteId, title),
                      tooltip: _isOffline
                          ? 'Offline - cannot remove'
                          : 'Remove from favorites',
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_outline,
            size: 56,
            color: AppTheme.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Save lessons to read them later',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textHint,
            ),
          ),
        ],
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
            const Icon(
              Icons.wifi_off_outlined,
              size: 56,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load favorites',
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
              onPressed: _loadFavorites,
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
}
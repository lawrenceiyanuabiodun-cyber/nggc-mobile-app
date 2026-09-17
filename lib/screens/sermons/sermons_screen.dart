import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'web_player_stub.dart' if (dart.library.html) 'web_player_web.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class SermonsScreen extends StatefulWidget {
  const SermonsScreen({super.key});

  @override
  State<SermonsScreen> createState() => _SermonsScreenState();
}

class _SermonsScreenState extends State<SermonsScreen> {
  Map<String, dynamic>? _featured;
  List<dynamic> _sermons = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!forceRefresh && !_isLoading) {
      setState(() => _isLoading = true);
    }
    setState(() {
      _error = null;
    });

    try {
      final featuredFuture = ApiService.get('/sermons/featured');
      final allFuture = ApiService.get('/sermons?limit=100');

      final results = await Future.wait([featuredFuture, allFuture]);
      final featuredResponse = results[0];
      final allResponse = results[1];

      if (!mounted) return;

      if (featuredResponse.isSuccess) {
        final data = featuredResponse.asMap;
        if (data != null && data.containsKey('featured')) {
          setState(() {
            _featured = data['featured'] as Map<String, dynamic>?;
          });
        }
      }

      if (allResponse.isSuccess) {
        final data = allResponse.asMap;
        if (data != null && data['sermons'] is List) {
          setState(() {
            _sermons = data['sermons'] as List<dynamic>;
          });
        } else {
          setState(() {
            _sermons = [];
          });
        }
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = allResponse.error ?? 'Failed to load sermons';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _shareSermon(String title, String mediaUrl, String mediaType) async {
    final typeLabel = mediaType == 'video' ? 'Watch this sermon' : 'Listen to this sermon';
    final text = '$typeLabel from NGGC. $title - $mediaUrl - Get the app: https://nggcapp.vercel.app';
    try {
      await Share.share(text, subject: 'NGGC Sermon: $title');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  void _showMediaPlayer(String url, String mediaType, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaPlayerBottomSheet(
        url: url,
        mediaType: mediaType,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight,
        appBar: AppBar(
          title: const Text(
            'Sermons',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchData(forceRefresh: true),
              tooltip: 'Refresh',
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.accentGold,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.grid_view_rounded), text: 'All'),
              Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
              Tab(icon: Icon(Icons.play_circle_outline), text: 'Videos'),
            ],
          ),
        ),
        body: _isLoading
            ? _buildLoadingShimmer()
            : _error != null
                ? _buildError()
                : TabBarView(
                    children: [
                      _buildAllTabContent(),
                      _buildFilteredTabContent('audio'),
                      _buildFilteredTabContent('video'),
                    ],
                  ),
      ),
    );
  }

  /// ─── TAB 1: ALL SERMONS (MATCHES CHURCH WEBSITE) ──────────────────
  Widget _buildAllTabContent() {
    if (_sermons.isEmpty && _featured == null) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: () => _fetchData(forceRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.star, color: AppTheme.accentGold, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Featured Sermon',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSermonCard(_featured!, featured: true),
                  ],
                ),
              ),
            ),
          if (_sermons.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'All Sermons (${_sermons.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final sermon = _sermons[index] as Map<String, dynamic>;
                    final featuredId = _featured?['id'];
                    // If featured sermon is already shown at top, skip duplicate
                    if (featuredId != null && sermon['id'] == featuredId) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSermonCard(sermon, featured: false),
                    );
                  },
                  childCount: _sermons.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ─── TABS 2 & 3: FILTERED BY TYPE (AUDIO / VIDEO) ─────────────────
  Widget _buildFilteredTabContent(String mediaType) {
    final filtered = _sermons.where((s) {
      if (s is Map<String, dynamic>) {
        final mt = s['media_type']?.toString().toLowerCase() ?? '';
        return mt == mediaType;
      }
      return false;
    }).toList();

    final featuredMatches = _featured != null &&
        (_featured!['media_type']?.toString().toLowerCase() ?? '') == mediaType;

    if (filtered.isEmpty && !featuredMatches) {
      return _buildEmptyForType(mediaType);
    }

    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: () => _fetchData(forceRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (featuredMatches)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.star, color: AppTheme.accentGold, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Featured Sermon',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSermonCard(_featured!, featured: true),
                  ],
                ),
              ),
            ),
          if (filtered.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final sermon = filtered[index] as Map<String, dynamic>;
                    final featuredId = _featured?['id'];
                    if (featuredMatches && featuredId != null && sermon['id'] == featuredId) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSermonCard(sermon, featured: false),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyForType(String mediaType) {
    final label = mediaType == 'audio' ? 'audio sermons' : 'video sermons';
    final icon = mediaType == 'audio' ? Icons.audiotrack : Icons.videocam_off;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 64, color: AppTheme.textHint),
        const SizedBox(height: 16),
        Text(
          'No $label yet',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pull down to refresh or check back later',
          style: TextStyle(fontSize: 13, color: AppTheme.textHint),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => const ShimmerSermonCard(),
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
              'Could not load sermons',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Network error',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _fetchData(forceRefresh: true),
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

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 100),
        Icon(
          Icons.mic_off,
          size: 56,
          color: AppTheme.textHint,
        ),
        SizedBox(height: 16),
        Text(
          'No sermons available',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Check back later for new sermons',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textHint,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSermonCard(Map<String, dynamic> sermon, {bool featured = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    final title = sermon['title']?.toString() ?? 'Untitled';
    final description = sermon['description']?.toString() ?? '';
    final mediaType = sermon['media_type']?.toString().toLowerCase() ?? 'audio';
    final mediaUrl = sermon['media_url']?.toString();
    final dateRaw = sermon['sermon_date']?.toString() ?? '';
    final formattedDate = _formatDate(dateRaw);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: featured ? AppTheme.accentGold : (isDark ? Colors.white12 : AppTheme.dividerColor),
          width: featured ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: featured
                ? AppTheme.accentGold.withOpacity(0.15)
                : Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured)
            Container(
              height: 4,
              decoration: const BoxDecoration(
                color: AppTheme.accentGold,
                borderRadius: BorderRadius.only(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: featured ? 17 : 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: mediaType == 'video'
                            ? const Color(0xFFE65100)
                            : AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            mediaType == 'video' ? Icons.play_arrow : Icons.audiotrack,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            mediaType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: AppTheme.accentGoldDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppTheme.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: featured ? 4 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (mediaUrl != null && mediaUrl.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showMediaPlayer(
                            mediaUrl,
                            mediaType,
                            title,
                          ),
                          icon: Icon(
                            mediaType == 'video'
                                ? Icons.play_circle_fill
                                : Icons.headphones,
                            size: 18,
                          ),
                          label: Text(
                            mediaType == 'video' ? 'Watch Sermon' : 'Listen Now',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mediaType == 'video'
                                ? AppTheme.primaryBlue
                                : const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _shareSermon(title, mediaUrl, mediaType),
                        icon: const Icon(Icons.share, size: 20),
                        color: AppTheme.primaryBlue,
                        tooltip: 'Share sermon',
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                    if (mediaUrl == null || mediaUrl.isEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: const Text(
                            'No media available',
                            style: TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 12,
                            ),
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
}

class ShimmerSermonCard extends StatelessWidget {
  const ShimmerSermonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 50,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 12,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 36,
            width: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------
// MEDIA PLAYER BOTTOM SHEET (Supports YouTube + MP4 + Audio + Fallback WebView)
// -----------------------------------------------------------------

class MediaPlayerBottomSheet extends StatefulWidget {
  final String url;
  final String mediaType;
  final String title;

  const MediaPlayerBottomSheet({
    super.key,
    required this.url,
    required this.mediaType,
    required this.title,
  });

  @override
  State<MediaPlayerBottomSheet> createState() => _MediaPlayerBottomSheetState();
}

class _MediaPlayerBottomSheetState extends State<MediaPlayerBottomSheet> {
  // Audio
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  // Video (Direct MP4)
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // WebView (for YouTube + fallback)
  WebViewController? _webViewController;
  bool _isWebView = false;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  bool _isYouTubeUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('youtube-nocookie.com');
  }

  String _convertToEmbedUrl(String url) {
    if (url.contains('/embed/')) return url;
    final uri = Uri.parse(url);
    if (uri.host.contains('youtu.be')) {
      final id = uri.path.substring(1);
      return 'https://www.youtube.com/embed/$id';
    }
    final id = uri.queryParameters['v'];
    if (id != null && id.isNotEmpty) {
      return 'https://www.youtube.com/embed/$id';
    }
    return url;
  }

  Future<void> _initPlayer() async {
    try {
      // On web, use in-app HTML5 audio/video player via WebView-like widget
      if (kIsWeb) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (widget.mediaType == 'audio') {
        _audioPlayer = AudioPlayer();
        _audioPlayer!.onDurationChanged.listen((d) {
          if (mounted) setState(() => _audioDuration = d);
        });
        _audioPlayer!.onPositionChanged.listen((p) {
          if (mounted) setState(() => _audioPosition = p);
        });
        _audioPlayer!.onPlayerStateChanged.listen((state) {
          if (mounted) {
            setState(() => _isAudioPlaying = state == PlayerState.playing);
          }
        });
        await _audioPlayer!.play(UrlSource(widget.url));
        if (mounted) setState(() => _isLoading = false);
      } else if (widget.mediaType == 'video') {
        if (_isYouTubeUrl(widget.url)) {
          _isWebView = true;
          final embedUrl = _convertToEmbedUrl(widget.url);
          _webViewController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000))
            ..setNavigationDelegate(
              NavigationDelegate(
                onPageFinished: (url) {
                  if (mounted) setState(() => _isLoading = false);
                },
                onWebResourceError: (error) {
                  if (mounted) {
                    setState(() {
                      _error = 'Failed to load video: ${error.errorCode}';
                    });
                  }
                },
              ),
            )
            ..loadRequest(Uri.parse(embedUrl));
        } else {
          try {
            _videoController = VideoPlayerController.networkUrl(
              Uri.parse(widget.url),
            );
            await _videoController!.initialize();
            if (mounted) {
              setState(() {
                _isVideoInitialized = true;
                _isLoading = false;
              });
              _videoController!.play();
            }
          } catch (e) {
            _isWebView = true;
            _webViewController = WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setBackgroundColor(const Color(0x00000000))
              ..setNavigationDelegate(
                NavigationDelegate(
                  onPageFinished: (url) {
                    if (mounted) setState(() => _isLoading = false);
                  },
                  onWebResourceError: (error) {
                    if (mounted) {
                      setState(() {
                        _error = 'Failed to load video: ${error.errorCode}';
                      });
                    }
                  },
                ),
              )
              ..loadRequest(Uri.parse(widget.url));
          }
        }
      } else {
        if (mounted) setState(() => _error = 'Unsupported media type');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleAudioPlay() {
    if (_audioPlayer == null) return;
    if (_isAudioPlaying) {
      _audioPlayer!.pause();
    } else {
      _audioPlayer!.resume();
    }
  }

  void _seekAudio(Duration position) {
    _audioPlayer?.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 8),
            Text(
              'Error: $_error',
              style: const TextStyle(color: AppTheme.errorRed),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (kIsWeb) {
      return _buildWebHtml5Player();
    }

    if (widget.mediaType == 'audio') {
      return _buildAudioPlayer();
    } else if (widget.mediaType == 'video') {
      if (_isWebView) {
        return _buildWebViewPlayer();
      } else if (_isVideoInitialized) {
        return _buildVideoPlayer();
      } else {
        return const Center(child: Text('Video not available'));
      }
    } else {
      return const Center(child: Text('Unsupported media type'));
    }
  }

  Widget _buildWebHtml5Player() {
    return WebMediaPlayer.build(
      url: widget.url,
      mediaType: widget.mediaType,
      onCloseSheet: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  Widget _buildAudioPlayer() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 60,
                  color: AppTheme.primaryBlue.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  _formatDuration(_audioPosition),
                  style: const TextStyle(fontSize: 16),
                ),
                Slider(
                  value: _audioPosition.inMilliseconds.toDouble(),
                  min: 0,
                  max: _audioDuration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    _seekAudio(Duration(milliseconds: value.toInt()));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isAudioPlaying ? Icons.pause : Icons.play_arrow,
                        size: 48,
                      ),
                      onPressed: _toggleAudioPlay,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_isVideoInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36,
              ),
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebViewPlayer() {
    if (_webViewController == null) {
      return const Center(child: Text('WebView not initialized'));
    }
    return WebViewWidget(controller: _webViewController!);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
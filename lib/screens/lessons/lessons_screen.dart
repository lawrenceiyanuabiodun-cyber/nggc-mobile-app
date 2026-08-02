import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/progress_cache_service.dart';
import '../../services/cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/shimmer_widgets.dart';
import 'lesson_detail_screen.dart';

// ─────────────────────────────────────────────────────────
// LessonsScreen
// Lists all lessons from /lessons/ API
// Shows shimmer while loading
// ─────────────────────────────────────────────────────────
class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _allLessons = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String _selectedLang = 'all';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchLessons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      switch (_tabController.index) {
        case 0:
          _selectedLang = 'all';
          break;
        case 1:
          _selectedLang = 'english';
          break;
        case 2:
          _selectedLang = 'yoruba';
          break;
      }
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_selectedLang == 'all') {
      _filtered = List.from(_allLessons);
    } else {
      _filtered = _allLessons
          .where((l) =>
              l['language']?.toString().toLowerCase() == _selectedLang)
          .toList();
    }
  }

  Future<void> _fetchLessons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Show cached data instantly while fetching fresh
    final cached = CacheService.getLessons();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _allLessons = cached;
        _applyFilter();
        _isLoading = false;
      });
    }

    // Always fetch fresh from API unless cache is valid
    if (cached != null && !CacheService.isLessonsExpired()) return;

    final response = await ApiService.get('/lessons/');

    if (!mounted) return;

    if (response.isSuccess) {
      final list = response.asList ?? [];
      await CacheService.saveLessons(list);
      setState(() {
        _allLessons = list;
        _applyFilter();
        _isLoading = false;
      });
    } else {
      if (_allLessons.isEmpty) {
        setState(() {
          _error = response.error ?? 'Failed to load lessons';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Sunday School Lessons'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLessons,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'English'),
            Tab(text: 'Yoruba'),
          ],
        ),
      ),
      body: _isLoading
          ? const ShimmerLessonList(count: 8)
          : _error != null
              ? _buildError()
              : _filtered.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _fetchLessons,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          final lesson = _filtered[index] as Map<String, dynamic>;
          return _buildLessonCard(lesson, index);
        },
      ),
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson, int index) {
    final String title = lesson['title']?.toString() ?? 'Untitled Lesson';
    final String topic = lesson['topic']?.toString() ?? '';
    final String lang = lesson['language']?.toString() ?? 'english';
    final String id = lesson['id']?.toString() ?? '';
    final String quarter = lesson['quarter']?.toString() ?? '';
    final isEnglish = lang.toLowerCase() == 'english';
    final isCompleted = ProgressCacheService.isCompleted(id);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LessonDetailScreen(
                lessonId: id,
                title: title,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Number badge or completion badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.successGreen.withOpacity(0.1)
                      : isEnglish
                          ? AppTheme.primaryBlue.withOpacity(0.08)
                          : AppTheme.successGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: isCompleted
                      ? Border.all(
                          color: AppTheme.successGreen.withOpacity(0.4))
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(
                          Icons.check_circle,
                          color: AppTheme.successGreen,
                          size: 22,
                        )
                      : Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isEnglish
                                ? AppTheme.primaryBlue
                                : AppTheme.successGreen,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildChip(
                          isEnglish ? 'English' : 'Yoruba',
                          isEnglish
                              ? AppTheme.primaryBlue
                              : AppTheme.successGreen,
                        ),
                        if (quarter.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _buildChip(quarter, AppTheme.accentGoldDark),
                        ],
                      ],
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
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
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
            Icons.school_outlined,
            size: 56,
            color: AppTheme.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedLang == 'all'
                ? 'No lessons available yet'
                : 'No ${_selectedLang[0].toUpperCase()}${_selectedLang.substring(1)} lessons yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
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
              'Could not load lessons',
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
            const SizedBox(height: 8),
            const Text(
              'Server may take up to 60s to wake up',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchLessons,
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




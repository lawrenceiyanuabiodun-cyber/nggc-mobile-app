import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminLessonsScreen extends StatefulWidget {
  const AdminLessonsScreen({super.key});

  @override
  State<AdminLessonsScreen> createState() => _AdminLessonsScreenState();
}

class _AdminLessonsScreenState extends State<AdminLessonsScreen> {
  List<dynamic> _lessons = [];
  bool _isLoading = true;
  String? _error;
  String _selectedLang = 'all';

  @override
  void initState() {
    super.initState();
    _fetchLessons();
  }

  Future<void> _fetchLessons() async {
    setState(() { _isLoading = true; _error = null; });
    final response = await ApiService.get('/lessons/');
    if (!mounted) return;
    if (response.isSuccess) {
      setState(() {
        _lessons = response.asList ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load lessons';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    if (_selectedLang == 'all') return _lessons;
    return _lessons.where((l) =>
        l['language']?.toString().toLowerCase() == _selectedLang).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Text('Lessons (${_filtered.length})'),
        backgroundColor: AppTheme.primaryBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLessons),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['all', 'english', 'yoruba'].map((lang) {
              final isSelected = _selectedLang == lang;
              return GestureDetector(
                onTap: () => setState(() => _selectedLang = lang),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    lang[0].toUpperCase() + lang.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primaryBlueDark
                          : Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
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
          return _buildCard(lesson, index);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> lesson, int index) {
    final title = lesson['title']?.toString() ?? 'Untitled';
    final topic = lesson['topic']?.toString() ?? '';
    final lang = lesson['language']?.toString() ?? 'english';
    final quarter = lesson['quarter']?.toString() ?? '';
    final isEnglish = lang.toLowerCase() == 'english';
    final color = isEnglish ? AppTheme.primaryBlue : AppTheme.successGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (topic.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(topic,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    _chip(isEnglish ? 'English' : 'Yoruba', color),
                    if (quarter.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _chip(quarter, AppTheme.accentGoldDark),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 48, color: AppTheme.textHint),
          SizedBox(height: 12),
          Text('No lessons found',
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
          const Icon(Icons.error_outline, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchLessons,
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
}

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class LessonDetailScreen extends StatefulWidget {
  final String lessonId;
  final String title;

  const LessonDetailScreen({
    super.key, 
    required this.lessonId, 
    required this.title
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  Map<String, dynamic>? _lesson;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final response = await ApiService.get('/lessons/${widget.lessonId}/full');
    if (response.isSuccess) {
      setState(() {
        _lesson = response.asMap;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load lesson content';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final content = _lesson!['content'] ?? 'No content available.';
    final memoryVerse = _lesson!['memory_verse'] ?? '';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (memoryVerse.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentGold),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MEMORY VERSE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark)),
                  const SizedBox(height: 8),
                  Text(memoryVerse, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(content, style: const TextStyle(fontSize: 17, height: 1.6)),
        ],
      ),
    );
  }
}

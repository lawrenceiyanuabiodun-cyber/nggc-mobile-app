import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/manuals_loader_service.dart';
import '../../theme/app_theme.dart';
import 'manual_detail_screen.dart';

class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends State<ManualsScreen> {
  List<Map<String, dynamic>> _manuals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadManuals();
  }

  Future<void> _loadManuals() async {
    setState(() => _isLoading = true);

    final cached = ManualsLoaderService.getAllManuals();
    if (cached.isNotEmpty) {
      setState(() {
        _manuals = cached;
        _isLoading = false;
      });
    }

    try {
      final response = await ApiService.get('/manuals/');
      if (!mounted) return;
      if (response.isSuccess && response.asMap != null) {
        final data = response.asMap!;
        if (data['manuals'] is List) {
          await ManualsLoaderService.saveManuals(data['manuals']);
          final fresh = ManualsLoaderService.getAllManuals();
          if (fresh.isNotEmpty) {
            setState(() {
              _manuals = fresh;
              _isLoading = false;
            });
          }
        }
      }
    } catch (_) {
      // Silent - cached data is still shown
    }

    if (mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  String _formatPeriod(String period) {
    final value = period.trim();
    final upper = value.toUpperCase();

    if (upper.startsWith('Q1')) {
      return value.replaceFirst(RegExp(r'^Q1', caseSensitive: false), 'H1');
    }
    if (upper.startsWith('Q2')) {
      return value.replaceFirst(RegExp(r'^Q2', caseSensitive: false), 'H1');
    }
    if (upper.startsWith('Q3')) {
      return value.replaceFirst(RegExp(r'^Q3', caseSensitive: false), 'H2');
    }
    if (upper.startsWith('Q4')) {
      return value.replaceFirst(RegExp(r'^Q4', caseSensitive: false), 'H2');
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Sunday School Manuals'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadManuals,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : _manuals.isEmpty
              ? _buildEmpty(isDark)
              : RefreshIndicator(
                  color: AppTheme.primaryBlue,
                  onRefresh: _loadManuals,
                  child: _buildGrid(isDark),
                ),
    );
  }

  Widget _buildGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemCount: _manuals.length,
      itemBuilder: (context, index) {
        return _buildManualCard(_manuals[index], isDark, index);
      },
    );
  }

  Widget _buildManualCard(
    Map<String, dynamic> manual,
    bool isDark,
    int index,
  ) {
    final title = manual['title']?.toString() ?? 'Untitled Manual';
    final year = manual['year']?.toString() ?? '';
    final rawPeriod = manual['period']?.toString() ?? '';
    final period = _formatPeriod(rawPeriod);
    final language = manual['language']?.toString() ?? 'english';
    final isEnglish = language.toLowerCase() == 'english';

    final colors = [
      [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
      [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
      [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
      [const Color(0xFFE65100), const Color(0xFFBF360C)],
    ];
    final palette = colors[index % colors.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManualDetailScreen(
              manualId: manual['id'].toString(),
              manualTitle: title,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: palette,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 10,
                child: Icon(
                  Icons.church,
                  color: Colors.white.withOpacity(0.15),
                  size: 60,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            period,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlueDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'SUNDAY\nSCHOOL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.75),
                            letterSpacing: 2,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          year,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Colors.white24, height: 12),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isEnglish ? 'EN' : 'YO',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 64,
            color: isDark ? Colors.white24 : AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            'No manuals available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
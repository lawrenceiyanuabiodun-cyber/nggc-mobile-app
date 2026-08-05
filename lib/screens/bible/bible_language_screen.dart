import 'package:flutter/material.dart';

import '../../services/bible_loader_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import 'bible_books_screen.dart';

class BibleLanguageScreen extends StatefulWidget {
  const BibleLanguageScreen({super.key});

  @override
  State<BibleLanguageScreen> createState() => _BibleLanguageScreenState();
}

class _BibleLanguageScreenState extends State<BibleLanguageScreen> {
  String _lastUsed = 'english';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final lang = await PreferencesService.getBibleLanguage();
    if (mounted) {
      setState(() {
        _lastUsed = lang;
        _loading  = false;
      });
    }
  }

  Future<void> _selectTranslation(String translationKey) async {
    await PreferencesService.setBibleLanguage(translationKey);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleBooksScreen(language: translationKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Bible'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  color: AppTheme.primaryBlue,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: const Column(
                    children: [
                      Icon(Icons.menu_book,
                          color: AppTheme.accentGold, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Holy Bible',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Select a translation',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // English translations section
                      _sectionLabel('English Translations', isDark),
                      const SizedBox(height: 10),
                      ...BibleLoaderService.translations
                          .where((t) => t['key'] != 'yoruba')
                          .map((t) => _buildCard(t, isDark))
                          .toList(),

                      const SizedBox(height: 20),

                      // Yoruba section
                      _sectionLabel('Yoruba', isDark),
                      const SizedBox(height: 10),
                      ...BibleLoaderService.translations
                          .where((t) => t['key'] == 'yoruba')
                          .map((t) => _buildCard(t, isDark))
                          .toList(),

                      const SizedBox(height: 20),

                      // Offline note
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.offline_bolt_outlined,
                              size: 14, color: AppTheme.textHint),
                          SizedBox(width: 6),
                          Text(
                            'All translations available offline',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textHint),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.history,
                              size: 13, color: AppTheme.textHint),
                          SizedBox(width: 5),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: isDark ? Colors.white38 : AppTheme.textHint,
      ),
    );
  }

  Widget _buildCard(Map<String, String> t, bool isDark) {
    final key       = t['key']!;
    final label     = t['label']!;
    final fullName  = t['fullName']!;
    final year      = t['year']!;
    final isLastUsed = _lastUsed == key;
    final isYoruba  = key == 'yoruba';

    final color = isYoruba
        ? const Color(0xFF2E7D32)
        : AppTheme.primaryBlue;

    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return GestureDetector(
      onTap: () => _selectTranslation(key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: isLastUsed
              ? Border.all(color: color, width: 2)
              : Border.all(
                  color: color.withOpacity(isDark ? 0.15 : 0.12)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.15 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  isYoruba ? '🇳🇬' : label,
                  style: TextStyle(
                    fontSize: isYoruba ? 26 : 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : color,
                        ),
                      ),
                      if (isLastUsed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Last used',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    year.isNotEmpty ? '$label · $year' : label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white38
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white24 : color.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
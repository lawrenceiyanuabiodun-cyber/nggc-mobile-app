import 'package:flutter/material.dart';

import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import 'bible_books_screen.dart';

// ─────────────────────────────────────────────────────────
// BibleLanguageScreen
// Entry point to Bible — user picks English or Yoruba
// Remembers last used language via PreferencesService
// ─────────────────────────────────────────────────────────
class BibleLanguageScreen extends StatefulWidget {
  const BibleLanguageScreen({super.key});

  @override
  State<BibleLanguageScreen> createState() => _BibleLanguageScreenState();
}

class _BibleLanguageScreenState extends State<BibleLanguageScreen> {
  String _lastUsedLanguage = 'english';
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
        _lastUsedLanguage = lang;
        _loading = false;
      });
    }
  }

  Future<void> _selectLanguage(String language) async {
    await PreferencesService.setBibleLanguage(language);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleBooksScreen(language: language),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
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
                // ── Header ──────────────────────────────
                Container(
                  color: AppTheme.primaryBlue,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.menu_book,
                        color: AppTheme.accentGold,
                        size: 48,
                      ),
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
                        'Select your preferred language',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Language Cards ───────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildLanguageCard(
                        language: 'english',
                        title: 'English',
                        subtitle: 'King James Version (KJV)',
                        flag: '🇬🇧',
                        color: const Color(0xFF1565C0),
                        isLastUsed: _lastUsedLanguage == 'english',
                      ),
                      const SizedBox(height: 16),
                      _buildLanguageCard(
                        language: 'yoruba',
                        title: 'Yoruba',
                        subtitle: 'Bibeli Mimo (Yoruba Translation)',
                        flag: '🇳🇬',
                        color: const Color(0xFF2E7D32),
                        isLastUsed: _lastUsedLanguage == 'yoruba',
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Last used hint ────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history,
                        size: 13,
                        color: AppTheme.textHint,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Last used: ${_lastUsedLanguage == 'yoruba' ? 'Yoruba' : 'English'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Offline note ─────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.offline_bolt_outlined,
                        size: 14,
                        color: AppTheme.textHint,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Full Bible available offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLanguageCard({
    required String language,
    required String title,
    required String subtitle,
    required String flag,
    required Color color,
    required bool isLastUsed,
  }) {
    return GestureDetector(
      onTap: () => _selectLanguage(language),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: isLastUsed
              ? Border.all(color: color, width: 2)
              : Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            // Flag
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (isLastUsed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/support_service.dart';
import '../../theme/app_theme.dart';

/// SupportScreen (Modal Bottom Sheet)
/// Two-step flow:
///   Step 1: User picks a reason
///   Step 2: User picks contact method (WhatsApp or Email)
/// Called via: showSupportSheet(context)
class SupportSheet extends StatefulWidget {
  const SupportSheet({super.key});

  @override
  State<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<SupportSheet> {
  String? _selectedReason;
  bool _showMethods = false;

  final List<_ReasonOption> _reasons = const [
    _ReasonOption(
      icon: Icons.volunteer_activism,
      label: 'Prayer Request',
      color: Color(0xFF6A1B9A),
    ),
    _ReasonOption(
      icon: Icons.favorite,
      label: 'Salvation / New Believer',
      color: Color(0xFFC62828),
    ),
    _ReasonOption(
      icon: Icons.groups,
      label: 'Membership',
      color: Color(0xFF1565C0),
    ),
    _ReasonOption(
      icon: Icons.bug_report_outlined,
      label: 'Report App Issue',
      color: Color(0xFFE65100),
    ),
    _ReasonOption(
      icon: Icons.chat_bubble_outline,
      label: 'General Question',
      color: Color(0xFF2E7D32),
    ),
  ];

  void _pickReason(String reason) {
    setState(() {
      _selectedReason = reason;
      _showMethods = true;
    });
  }

  void _backToReasons() {
    setState(() {
      _showMethods = false;
    });
  }

  Future<void> _openWhatsApp() async {
    if (_selectedReason == null) return;
    Navigator.pop(context);
    await SupportService.openWhatsApp(
      reason: _selectedReason!,
      context: context,
    );
  }

  Future<void> _openEmail() async {
    if (_selectedReason == null) return;
    Navigator.pop(context);
    await SupportService.openEmail(
      reason: _selectedReason!,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final titleColor = isDark ? Colors.white : AppTheme.primaryBlue;
    final subColor = isDark ? Colors.white70 : AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              if (_showMethods)
                IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: titleColor, size: 22),
                  onPressed: _backToReasons,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (_showMethods) const SizedBox(width: 8),
              Icon(
                _showMethods ? Icons.contact_support : Icons.support_agent,
                color: AppTheme.primaryBlue,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _showMethods ? 'How to Reach Us' : 'How Can We Help?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: subColor, size: 22),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Subtitle
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _showMethods
                  ? 'About: ${_selectedReason ?? ""}'
                  : "What's this about?",
              style: TextStyle(
                fontSize: 13,
                color: subColor,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Body
          if (!_showMethods)
            _buildReasonsList(isDark)
          else
            _buildMethodsList(isDark),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ─── Reasons List ─────────────────────────────────────
  Widget _buildReasonsList(bool isDark) {
    return Column(
      children: _reasons.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _pickReason(r.label),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : r.color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: r.color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: r.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(r.icon, color: r.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white38 : AppTheme.textHint,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Methods List (WhatsApp + Email) ──────────────────
  Widget _buildMethodsList(bool isDark) {
    return Column(
      children: [
        // WhatsApp
        _buildMethodTile(
          isDark: isDark,
          icon: Icons.chat,
          iconColor: const Color(0xFF25D366),
          title: 'WhatsApp',
          subtitle: 'Message us on WhatsApp',
          onTap: _openWhatsApp,
        ),
        const SizedBox(height: 12),
        // Email
        _buildMethodTile(
          isDark: isDark,
          icon: Icons.email_outlined,
          iconColor: const Color(0xFFEA4335),
          title: 'Email',
          subtitle: 'Send us an email',
          onTap: _openEmail,
        ),
        const SizedBox(height: 16),
        // Note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : AppTheme.primaryBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: isDark ? Colors.white54 : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your message will be pre-filled. Just add your details and send.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : iconColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: iconColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: iconColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonOption {
  final IconData icon;
  final String label;
  final Color color;

  const _ReasonOption({
    required this.icon,
    required this.label,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────
// Helper function to open the support sheet from anywhere
// Usage: showSupportSheet(context);
// ─────────────────────────────────────────────────────────
Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SupportSheet(),
  );
}
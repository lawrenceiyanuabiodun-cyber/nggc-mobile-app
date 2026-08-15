import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/update_service.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/battery_optimization_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../bible/bible_reading_progress_screen.dart';
import '../bible/bible_saved_verses_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notes/notes_screen.dart';
import '../search/search_screen.dart';
import 'change_pin_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _appVersion = '';
  bool _batteryOptimizationDisabled = false;
  bool _notificationsEnabled = false;
  bool _sendingTest = false;
  bool _checkingUpdate = false;
  double _downloadProgress = 0.0;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadNotificationStatus();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = 'v${info.version}');
    } catch (_) {
      setState(() => _appVersion = 'v1.0.0');
    }
  }

  Future<void> _loadNotificationStatus() async {
    final battery = await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    final notif = await NotificationService.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _batteryOptimizationDisabled = battery;
      _notificationsEnabled = notif;
    });
  }

  Future<void> _sendTestNotification() async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    try {
      await NotificationService.showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification panel.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send. Check notification permissions.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  Future<void> _scheduleTestIn1Minute() async {
    try {
      await NotificationService.scheduleTestIn1Minute();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification scheduled for 1 minute from now.'),
          backgroundColor: AppTheme.primaryBlue,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to schedule test notification.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _requestBatteryExemption() async {
    final granted = await BatteryOptimizationService.requestBatteryExemption();
    if (!mounted) return;
    setState(() => _batteryOptimizationDisabled = granted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(granted
            ? 'Battery optimization disabled. Notifications will work reliably.'
            : 'Permission not granted. Notifications may be delayed.'),
        backgroundColor: granted ? AppTheme.successGreen : AppTheme.errorRed,
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await BatteryOptimizationService.requestNotificationPermission();
    if (!mounted) return;
    setState(() => _notificationsEnabled = granted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(granted ? 'Notifications enabled!' : 'Notification permission denied.'),
        backgroundColor: granted ? AppTheme.successGreen : AppTheme.errorRed,
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    try {
      final update = await UpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() => _checkingUpdate = false);

      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('You have the latest version!'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Show update dialog
      _showUpdateDialog(update);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not check for updates: \${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo update) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      barrierDismissible: !_downloading,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.system_update,
                    color: AppTheme.accentGoldDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Update Available!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.download, size: 16, color: AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          '\${update.sizeMb} MB',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          update.formattedDate,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "What's new:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      update.releaseNotes.isEmpty
                          ? 'Bug fixes and improvements'
                          : update.releaseNotes,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                  if (_downloading) ...[
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Downloading... \${(_downloadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          color: AppTheme.primaryBlue,
                          backgroundColor: AppTheme.primaryBlue.withOpacity(0.15),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please wait — you will be signed out after install.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: _downloading
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Later'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        setDialog(() => _downloading = true);
                        setState(() => _downloading = true);

                        final filePath = await UpdateService.downloadApk(
                          downloadUrl: update.downloadUrl,
                          onProgress: (p) {
                            setDialog(() => _downloadProgress = p);
                            setState(() => _downloadProgress = p);
                          },
                        );

                        if (!mounted) return;

                        if (filePath == null) {
                          setDialog(() => _downloading = false);
                          setState(() => _downloading = false);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Download failed. Please try again.'),
                              backgroundColor: AppTheme.errorRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        // Mark this SHA as installed
                        await UpdateService.markInstalled(update.remoteSha);

                        // Sign out user (so they log in fresh on new version)
                        await ref.read(authProvider.notifier).logout();

                        // Launch installer
                        await UpdateService.installApk(filePath);

                        // Close dialog
                        if (mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download & Install'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }

  Future<void> _launchAdminUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open admin page.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }


  Future<void> _logout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A237E))),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1E) : AppTheme.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _navigateTo(const SearchScreen()),
            tooltip: 'Search Lessons',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(user),
            const SizedBox(height: 24),
            _buildSection(title: 'My Activity', children: [
              _buildNavTile(
                icon: Icons.bookmark_outline,
                label: 'Saved Verses',
                subtitle: 'Bible verses you have bookmarked',
                color: const Color(0xFF6A1B9A),
                onTap: () => _navigateTo(const BibleSavedVersesScreen()),
              ),
              _buildNavTile(
                icon: Icons.favorite_outline,
                label: 'My Favorites',
                subtitle: 'Lessons you have saved',
                color: AppTheme.errorRed,
                onTap: () => _navigateTo(const FavoritesScreen()),
              ),
              _buildNavTile(
                icon: Icons.sticky_note_2_outlined,
                label: 'My Notes',
                subtitle: 'Personal lesson notes',
                color: AppTheme.accentGoldDark,
                onTap: () => _navigateTo(const NotesScreen()),
              ),
              _buildNavTile(
                icon: Icons.auto_stories_outlined,
                label: 'Reading Progress',
                subtitle: 'Track your Bible reading streak',
                color: AppTheme.successGreen,
                onTap: () => _navigateTo(const BibleReadingProgressScreen()),
                isLast: true,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection(title: 'Notifications', children: [
              _buildStatusTile(
                icon: Icons.notifications_active,
                label: 'Notification Permission',
                subtitle: _notificationsEnabled ? 'Enabled - You will receive verses' : 'Disabled - Tap to enable',
                color: _notificationsEnabled ? AppTheme.successGreen : AppTheme.errorRed,
                statusOk: _notificationsEnabled,
                onTap: _notificationsEnabled ? null : _requestNotificationPermission,
              ),
              _buildStatusTile(
                icon: Icons.battery_charging_full,
                label: 'Battery Optimization',
                subtitle: _batteryOptimizationDisabled ? 'Disabled - Reliable delivery' : 'Enabled - May delay notifications',
                color: _batteryOptimizationDisabled ? AppTheme.successGreen : AppTheme.accentGoldDark,
                statusOk: _batteryOptimizationDisabled,
                onTap: _batteryOptimizationDisabled ? null : _requestBatteryExemption,
              ),
              _buildActionTile(
                icon: Icons.send,
                label: 'Send Test Notification',
                subtitle: 'Shows notification immediately',
                color: AppTheme.primaryBlue,
                loading: _sendingTest,
                onTap: _sendTestNotification,
              ),
              _buildActionTile(
                icon: Icons.timer_outlined,
                label: 'Test in 1 Minute',
                subtitle: 'Schedule test notification for 1 min',
                color: AppTheme.primaryBlueLight,
                onTap: _scheduleTestIn1Minute,
                isLast: true,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection(title: 'Settings', children: [
              _buildNavTile(
                icon: Icons.lock_reset_outlined,
                label: 'Change PIN',
                subtitle: 'Update your 4-digit login PIN',
                color: AppTheme.primaryBlueDark,
                onTap: () => _navigateTo(const ChangePinScreen()),
              ),
              _buildToggleTile(
                icon: isDark ? Icons.dark_mode : Icons.light_mode_outlined,
                label: 'Dark Mode',
                subtitle: isDark ? 'Currently dark' : 'Currently light',
                color: isDark ? const Color(0xFF5C6BC0) : AppTheme.accentGoldDark,
                value: isDark,
                onChanged: (val) {
                  ref.read(themeProvider.notifier).toggleDarkMode(val);
                },
                isLast: true,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection(title: 'Account Info', children: [
              _buildInfoTile(icon: Icons.person_outline, label: 'Full Name', value: user?.fullName ?? '-'),
              _buildInfoTile(icon: Icons.phone_outlined, label: 'Phone Number', value: user?.phone ?? '-'),
              _buildInfoTile(
                icon: Icons.shield_outlined,
                label: 'Role',
                value: user?.isAdmin == true ? 'Administrator' : 'Member',
                valueColor: user?.isAdmin == true ? AppTheme.accentGoldDark : AppTheme.successGreen,
              ),
              _buildInfoTile(
                icon: Icons.language_outlined,
                label: 'Preferred Language',
                value: user?.preferredLanguage != null ? _capitalize(user!.preferredLanguage!) : 'Not set',
                isLast: true,
              ),
            ]),
            const SizedBox(height: 16),
            if (user?.isAdmin == true)
              _buildSection(title: 'Admin Panel', children: [
                _buildNavTile(
                  icon: Icons.upload_file_outlined,
                  label: 'Upload Sermons',
                  subtitle: 'Add sermon videos, audio & YouTube links',
                  color: const Color(0xFF6A1B9A),
                  onTap: () => _launchAdminUrl('https://nggcwebsite.vercel.app/admin.html'),
                ),
                _buildNavTile(
                  icon: Icons.menu_book_outlined,
                  label: 'Manage Sunday School',
                  subtitle: 'Upload and manage lesson materials',
                  color: AppTheme.primaryBlue,
                  onTap: () => _launchAdminUrl('https://nggc-api.onrender.com/admin'),
                  isLast: true,
                ),
              ]),
            if (user?.isAdmin == true) const SizedBox(height: 16),
            if (!kIsWeb)
              _buildSection(title: 'App Update', children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.system_update,
                              color: AppTheme.accentGoldDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Get the latest version',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Check for new features & bug fixes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white54
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _checkingUpdate ? null : _checkForUpdate,
                          icon: _checkingUpdate
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 18),
                          label: Text(_checkingUpdate ? 'Checking...' : 'Check for Updates'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            if (!kIsWeb) const SizedBox(height: 16),
            _buildSection(title: 'App Info', children: [
              _buildInfoTile(icon: Icons.info_outline, label: 'App Version', value: _appVersion),
              _buildInfoTile(icon: Icons.church_outlined, label: 'Church', value: 'New Generation Gospel Church'),
              _buildInfoTile(icon: Icons.school_outlined, label: 'Ministry', value: 'Sunday School Department'),
              _buildInfoTile(
                icon: Icons.code_outlined,
                label: 'Developed by',
                value: 'L.I.A CONCEPT',
                valueColor: AppTheme.primaryBlueLight,
                isLast: true,
              ),
            ]),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(user) {
    final initial = user?.initial ?? '?';
    final fullName = user?.fullName ?? 'Member';
    final isAdmin = user?.isAdmin == true;
    return Container(
      width: double.infinity,
      color: AppTheme.primaryBlue,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accentGold,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryBlueDark)),
            ),
          ),
          const SizedBox(height: 14),
          Text(fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isAdmin ? AppTheme.accentGold.withOpacity(0.2) : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isAdmin ? AppTheme.accentGold : Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              isAdmin ? 'Administrator' : 'Member',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isAdmin ? AppTheme.accentGold : Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : AppTheme.textHint, letterSpacing: 1.2)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : AppTheme.dividerColor;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: dividerColor))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textHint)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isDark ? Colors.white38 : AppTheme.textHint, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool statusOk,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : AppTheme.dividerColor;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: dividerColor))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textHint)),
                ],
              ),
            ),
            Icon(statusOk ? Icons.check_circle : Icons.error_outline, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool loading = false,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : AppTheme.dividerColor;
    return InkWell(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: dividerColor))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textHint)),
                ],
              ),
            ),
            loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(Icons.arrow_forward, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : AppTheme.dividerColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: dividerColor))),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textHint)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: AppTheme.accentGold),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : AppTheme.dividerColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: dividerColor))),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white70 : AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : AppTheme.textSecondary))),
          Flexible(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? (isDark ? Colors.white : AppTheme.textPrimary)),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';

/// Handles Android battery optimization exemption
/// Some manufacturers (Xiaomi, Huawei, Oppo) kill scheduled notifications
/// unless the app is exempted from battery optimization
class BatteryOptimizationService {
  BatteryOptimizationService._();

  static const String _promptedKey = 'battery_optimization_prompted';

  /// Check if we already asked the user
  static bool wasAlreadyPrompted() {
    try {
      final box = Hive.box(AppConfig.settingsBoxName);
      return box.get(_promptedKey, defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  /// Mark as prompted
  static Future<void> markAsPrompted() async {
    try {
      final box = Hive.box(AppConfig.settingsBoxName);
      await box.put(_promptedKey, true);
    } catch (_) {}
  }

  /// Reset (so we can prompt again)
  static Future<void> resetPromptStatus() async {
    try {
      final box = Hive.box(AppConfig.settingsBoxName);
      await box.delete(_promptedKey);
    } catch (_) {}
  }

  /// Check current permission status
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request battery optimization exemption
  /// Returns true if granted
  static Future<bool> requestBatteryExemption() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request notification permission (Android 13+)
  static Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Show first-time prompt to user (call after successful login)
  static Future<void> showFirstTimePromptIfNeeded(BuildContext context) async {
    if (wasAlreadyPrompted()) return;

    // Request notification permission first
    await requestNotificationPermission();

    final isGranted = await isIgnoringBatteryOptimizations();
    if (isGranted) {
      await markAsPrompted();
      return;
    }

    if (!context.mounted) return;

    await _showDialog(context);
    await markAsPrompted();
  }

  /// Show a dialog explaining why we need battery exemption
  static Future<void> _showDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: Color(0xFFFFD700),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Never Miss a Verse',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A237E),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To send you a daily Bible verse at 6 AM and 12 PM, please allow the app to run in the background.',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFFFD700),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'On the next screen, tap "Allow"',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A237E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await requestBatteryExemption();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Open device settings (for manual toggle)
  static Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }
}
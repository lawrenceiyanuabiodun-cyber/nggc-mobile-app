import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─────────────────────────────────────────────────────────
// NotificationService
// Handles local notifications for daily Bible verse
// Uses flutter_local_notifications ^17.2.3
// ─────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ── Notification IDs ───────────────────────────────────
  static const int _dailyVerseId = 1001;
  static const int _generalId = 1002;

  // ── Channel details ────────────────────────────────────
  static const String _channelId = 'nggc_channel';
  static const String _channelName = 'NGGC Notifications';
  static const String _channelDesc =
      'Daily Bible verse and church notifications';

  // ── Initialize ─────────────────────────────────────────
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  // ── Request permissions (Android 13+) ─────────────────
  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  // ── Show immediate notification ────────────────────────
  static Future<void> showNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1A237E),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id ?? _generalId,
      title,
      body,
      details,
    );
  }

  // ── Show daily verse notification ──────────────────────
  static Future<void> showDailyVerseNotification({
    required String verse,
    required String reference,
  }) async {
    await showNotification(
      id: _dailyVerseId,
      title: '📖 Verse of the Day',
      body: '"$verse" — $reference',
    );
  }

  // ── Schedule daily verse at specific time ──────────────
  static Future<void> scheduleDailyVerse({
    required String verse,
    required String reference,
    int hour = 8,
    int minute = 0,
  }) async {
    if (!_initialized) await initialize();

    // Cancel existing daily verse notification first
    await _plugin.cancel(_dailyVerseId);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1A237E),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show immediately (scheduled daily requires timezone plugin)
    // For now show as immediate — can upgrade to scheduled later
    await _plugin.show(
      _dailyVerseId,
      '📖 Verse of the Day',
      '"$verse" — $reference',
      details,
    );
  }

  // ── Cancel all notifications ───────────────────────────
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Cancel specific notification ───────────────────────
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  // ── Handle notification tap ────────────────────────────
  static void _onNotificationTap(NotificationResponse response) {
    // TODO: Navigate to relevant screen based on payload
    // For now just log the tap
    debugPrint('Notification tapped: ${response.payload}');
  }

  // ── Check if notifications are enabled ─────────────────
  static Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await android?.areNotificationsEnabled();
    return enabled ?? false;
  }
}

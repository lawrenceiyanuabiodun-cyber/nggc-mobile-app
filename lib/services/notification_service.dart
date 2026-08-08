import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'daily_verse_service.dart';

/// NotificationService
/// Daily Bible verse notifications at 6 AM and 12 PM
/// Uses offline Hive cache from DailyVerseService
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const int _dailyVerse6AmId = 1001;
  static const int _dailyVerse12PmId = 1002;
  static const int _generalId = 2001;

  // New channel with custom voice sound. A new channel ID is required
  // because Android locks a channel's sound the first time it's created
  // on a device - changing the sound in code alone won't affect existing
  // installs already using the old channel.
  static const String _channelId = 'nggc_daily_verse_v2';
  static const String _channelName = 'Daily Bible Verse';
  static const String _channelDesc =
      'Get a daily Bible verse at 6 AM and 12 PM';

  static const String _notificationTitle = 'Bible Verse of the Day';

  static const List<Map<String, String>> _fallbackVerses = [
    {'text': 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.', 'ref': 'John 3:16'},
    {'text': 'I can do all things through Christ which strengtheneth me.', 'ref': 'Philippians 4:13'},
    {'text': 'The Lord is my shepherd; I shall not want.', 'ref': 'Psalm 23:1'},
    {'text': 'Trust in the Lord with all thine heart; and lean not unto thine own understanding.', 'ref': 'Proverbs 3:5'},
    {'text': 'And we know that all things work together for good to them that love God.', 'ref': 'Romans 8:28'},
    {'text': 'Be strong and of a good courage; be not afraid.', 'ref': 'Joshua 1:9'},
    {'text': 'Come unto me, all ye that labour and are heavy laden, and I will give you rest.', 'ref': 'Matthew 11:28'},
  ];

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
    }

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

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('bible_verse_alert'),
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
    return granted ?? false;
  }

  static Map<String, String> _getTodaysVerse() {
    final cached = DailyVerseService.getTodaysVerse();
    if (cached != null &&
        (cached['text'] ?? '').isNotEmpty &&
        (cached['reference'] ?? '').isNotEmpty) {
      return {
        'text': cached['text']!,
        'ref': cached['reference']!,
      };
    }

    final now = DateTime.now();
    final dayOfYear =
        now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final v = _fallbackVerses[dayOfYear % _fallbackVerses.length];
    return {'text': v['text']!, 'ref': v['ref']!};
  }

  static Future<void> scheduleDailyVerseNotifications() async {
    if (!_initialized) await initialize();

    await _plugin.cancel(_dailyVerse6AmId);
    await _plugin.cancel(_dailyVerse12PmId);

    final verse = _getTodaysVerse();
    final body = '"${verse['text']}"\n\n- ${verse['ref']}';

    await _scheduleAtTime(
      id: _dailyVerse6AmId,
      hour: 6,
      minute: 0,
      title: _notificationTitle,
      body: body,
    );

    await _scheduleAtTime(
      id: _dailyVerse12PmId,
      hour: 12,
      minute: 0,
      title: _notificationTitle,
      body: body,
    );

    debugPrint('Daily verse notifications scheduled: 6 AM + 12 PM');
  }

  static Future<void> _scheduleAtTime({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1A237E),
      playSound: true,
      sound: RawResourceAndroidNotificationSound('bible_verse_alert'),
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'bible_verse_alert.mp3',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledTime = _nextInstanceOfTime(hour, minute);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Show test notification immediately (for debug button)
  static Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    final verse = _getTodaysVerse();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1A237E),
      playSound: true,
      sound: RawResourceAndroidNotificationSound('bible_verse_alert'),
      styleInformation: BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'bible_verse_alert.mp3',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _generalId,
      '$_notificationTitle (Test)',
      '"${verse['text']}"\n\n- ${verse['ref']}',
      details,
    );
  }

  /// Schedule a test notification in 1 minute (for testing)
  static Future<void> scheduleTestIn1Minute() async {
    if (!_initialized) await initialize();
    final verse = _getTodaysVerse();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1A237E),
      playSound: true,
      sound: RawResourceAndroidNotificationSound('bible_verse_alert'),
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'bible_verse_alert.mp3',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

    await _plugin.zonedSchedule(
      9999,
      'Test - Verse in 1 minute',
      '"${verse['text']}"\n\n- ${verse['ref']}',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

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
    await _plugin.show(id ?? _generalId, title, body, details);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> cancelDailyVerse() async {
    await _plugin.cancel(_dailyVerse6AmId);
    await _plugin.cancel(_dailyVerse12PmId);
  }

  static Future<bool> areNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await android?.areNotificationsEnabled();
    return enabled ?? false;
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }
}
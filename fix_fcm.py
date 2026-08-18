with open(r'C:\dev\nggc\mobile_app\lib\services\fcm_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

original = content

# ─── FIX 1: Register the FCM notification channel on init ───
old_init_step5 = "      // 5. Setup message handlers\n      _setupMessageHandlers();"
new_init_step5 = """      // 5. Register Android notification channel BEFORE handlers
      if (!kIsWeb) {
        await _registerFcmChannel();
      }

      // 6. Setup message handlers
      _setupMessageHandlers();"""

if old_init_step5 in content:
    content = content.replace(old_init_step5, new_init_step5, 1)
    print("Fix 1: init step 5 patched (register channel)")
else:
    print("Fix 1: skipped")

# ─── FIX 2: Add _registerFcmChannel method ───
old_channel_anchor = "  // Request notification permissions\n  static Future<void> _requestPermissions() async {"
new_channel_method = """  // Register Android channel for FCM notifications
  static Future<void> _registerFcmChannel() async {
    try {
      const channel = AndroidNotificationChannel(
        'nggc_fcm_channel',
        'NGGC Push Notifications',
        description: 'Announcements, events, and church updates',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      // Also request permission (Android 13+)
      await androidPlugin?.requestNotificationsPermission();
      debugPrint('FCM notification channel registered');
    } catch (e) {
      debugPrint('Failed to register FCM channel: $e');
    }
  }

  // Request notification permissions
  static Future<void> _requestPermissions() async {"""

if old_channel_anchor in content and "_registerFcmChannel" not in content:
    content = content.replace(old_channel_anchor, new_channel_method, 1)
    print("Fix 2: _registerFcmChannel method added")
else:
    print("Fix 2: skipped")

# ─── FIX 3: Initialize the local notifications plugin on init ───
# Need to add plugin.initialize() call before creating channel
old_channel_call = "  static Future<void> _registerFcmChannel() async {\n    try {\n      const channel = AndroidNotificationChannel("
new_channel_call = """  static Future<void> _registerFcmChannel() async {
    try {
      // Initialize local notifications plugin (needed for the channel + display)
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(initSettings);

      const channel = AndroidNotificationChannel("""

if old_channel_call in content:
    content = content.replace(old_channel_call, new_channel_call, 1)
    print("Fix 3: plugin initialization added")
else:
    print("Fix 3: skipped")

# ─── FIX 4: Fix _showLocalNotification to use proper settings ───
old_show = """  // Show a local notification when FCM arrives in foreground (mobile only)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'nggc_fcm_channel',
      'NGGC Push Notifications',
      channelDescription: 'Bible verses and church updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'NGGC',
      notification.body ?? '',
      details,
    );
  }"""

new_show = """  // Show a local notification when FCM arrives in foreground (mobile only)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final notification = message.notification;
    // Also handle data-only messages
    final title = notification?.title ??
        message.data['title']?.toString() ??
        'NGGC';
    final body = notification?.body ??
        message.data['body']?.toString() ??
        '';

    if (title.isEmpty && body.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'nggc_fcm_channel',
      'NGGC Push Notifications',
      channelDescription: 'Announcements, events, and church updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1A237E),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }"""

if old_show in content:
    content = content.replace(old_show, new_show, 1)
    print("Fix 4: _showLocalNotification improved (handles data-only + colors)")
else:
    print("Fix 4: skipped")

# ─── FIX 5: Add Color import if missing ───
if "package:flutter/material.dart" not in content and "Color(" in content:
    # add import at top
    old_import = "import 'package:flutter/foundation.dart';"
    new_import = "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart' show Color;"
    if old_import in content:
        content = content.replace(old_import, new_import, 1)
        print("Fix 5: Color import added")

# Save
if content != original:
    with open(r'C:\dev\nggc\mobile_app\lib\services\fcm_service.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print()
    print(f"SUCCESS: fcm_service.dart saved ({len(original)} -> {len(content)} chars)")
else:
    print()
    print("WARNING: nothing changed")

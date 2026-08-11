import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// FcmService
/// Handles Firebase Cloud Messaging (FCM) push notifications
/// on Mobile (Android/iOS) AND Web.
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _fcmTokenBoxName = 'fcm_tokens';
  static const String _fcmTokenKey = 'device_fcm_token';
  static const String _tokenRegisteredKey = 'token_registered_with_backend';

  // VAPID key from Firebase Console -> Cloud Messaging -> Web Push certificates
  static const String _vapidKey =
      'BCO4xeM_l_DnhE9_oXZiLqibeAlJeZ_NpbWzpgU96Kmx1v1GF2XpusPWfumjcIrqguf52i2RU4GGlEVcSQyUo8Q';

  // Firebase Web configuration
  static const FirebaseOptions _webOptions = FirebaseOptions(
    apiKey: 'AIzaSyALpgooEVOSXwsixboRKiMEvD7H2nncfoA',
    authDomain: 'nggc-sunday-school.firebaseapp.com',
    projectId: 'nggc-sunday-school',
    storageBucket: 'nggc-sunday-school.firebasestorage.app',
    messagingSenderId: '584254133766',
    appId: '1:584254133766:web:52dd0f60444d10e3af1587',
  );

  static String? _cachedToken;

  // Initialize Firebase + FCM
  static Future<void> initialize() async {
    try {
      // 1. Initialize Firebase - pass explicit options on web
      if (kIsWeb) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: _webOptions);
        }
      } else {
        await Firebase.initializeApp();
      }

      // 2. Open Hive box for storing FCM token
      if (!Hive.isBoxOpen(_fcmTokenBoxName)) {
        await Hive.openBox(_fcmTokenBoxName);
      }

      // 3. Request notification permissions
      await _requestPermissions();

      // 4. Get FCM token (uses VAPID key on web)
      await _getAndCacheToken();

      // 5. Setup message handlers
      _setupMessageHandlers();

      // 6. Setup token refresh listener
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token refreshed: ${newToken.substring(0, 20)}...');
        _cachedToken = newToken;
        await _saveToken(newToken);
        final box = Hive.box(_fcmTokenBoxName);
        await box.put(_tokenRegisteredKey, false);
      });

      debugPrint('FCM Service initialized successfully (web=${kIsWeb})');
    } catch (e) {
      debugPrint('FCM Service initialization failed: $e');
    }
  }

  // Request notification permissions
  static Future<void> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
          'Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }

  // Get and cache FCM token (VAPID key on web)
  static Future<String?> _getAndCacheToken() async {
    try {
      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: _vapidKey)
          : await _messaging.getToken();

      if (token != null) {
        _cachedToken = token;
        await _saveToken(token);
        debugPrint('FCM Token: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
      return null;
    }
  }

  // Save token to Hive
  static Future<void> _saveToken(String token) async {
    try {
      final box = Hive.box(_fcmTokenBoxName);
      await box.put(_fcmTokenKey, token);
    } catch (e) {
      debugPrint('Failed to save FCM token to Hive: $e');
    }
  }

  // Get current FCM token
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      final box = Hive.box(_fcmTokenBoxName);
      final saved = box.get(_fcmTokenKey) as String?;
      if (saved != null) {
        _cachedToken = saved;
        return saved;
      }
    } catch (_) {}
    return await _getAndCacheToken();
  }

  // Register FCM token with backend
  static Future<bool> registerTokenWithBackend({
    required String jwt,
    bool forceReRegister = false,
  }) async {
    try {
      final box = Hive.box(_fcmTokenBoxName);
      final alreadyRegistered =
          box.get(_tokenRegisteredKey, defaultValue: false) as bool;

      if (alreadyRegistered && !forceReRegister) {
        debugPrint('FCM token already registered with backend');
        return true;
      }

      final token = await getToken();
      if (token == null || token.isEmpty) {
        debugPrint('No FCM token available to register');
        return false;
      }

      final platform = kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

      final url =
          Uri.parse('${AppConfig.baseUrl}/users/register-fcm-token');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode({
              'fcm_token': token,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await box.put(_tokenRegisteredKey, true);
        debugPrint('FCM token registered with backend successfully');
        return true;
      } else {
        debugPrint(
            'Backend registration failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Failed to register FCM token with backend: $e');
      return false;
    }
  }

  // Setup message handlers
  static void _setupMessageHandlers() {
    // Foreground: app is open and visible
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground FCM: ${message.notification?.title}');
      // On web, the browser shows the notification automatically via service worker
      // On mobile, we manually show a local notification
      if (!kIsWeb) {
        _showLocalNotification(message);
      }
    });

    // Background/Tapped: user taps notification while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification: ${message.notification?.title}');
    });

    // Terminated: user taps notification while app is killed (mobile only)
    if (!kIsWeb) {
      _messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint(
              'App launched from terminated notification: ${message.notification?.title}');
        }
      });
    }
  }

  // Show a local notification when FCM arrives in foreground (mobile only)
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
  }

  // Reset registration status (call on logout)
  static Future<void> resetRegistration() async {
    try {
      final box = Hive.box(_fcmTokenBoxName);
      await box.put(_tokenRegisteredKey, false);
    } catch (_) {}
  }
}

// Top-level handler for background messages (mobile only)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background FCM: ${message.notification?.title}');
}
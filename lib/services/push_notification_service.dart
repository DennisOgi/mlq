import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';
import 'push_notification_platform.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  final PushNotificationPlatform _platform = PushNotificationPlatform();

  bool _initialized = false;
  bool _tzInitialized = false;
  bool _tokenSynced = false;
  String? _lastSyncedToken;
  bool _tokenRefreshListenerRegistered = false;

  // Fixed notification IDs for scheduling
  static const int _dailyReminderId = 1001;
  static const String _fcmTokenKey = 'fcm_token_last_synced';
  static const String _fcmTokenValueKey = 'fcm_token_value';

  Future<void> initialize({
    void Function(dynamic)? onMessageOpenedApp,
  }) async {
    if (_initialized) return;

    // Initialize local notifications first so we can display heads-up for foreground messages
    await _initLocalNotifications();

    // Initialize timezone database for zoned scheduling
    await _ensureTimezoneInitialized();

    // Initialize platform-specific push notifications (mobile only)
    await _platform.initialize();

    // Request notification permission (iOS/Android 13+)
    await _requestPermissions();

    // Obtain and persist FCM token (mobile only)
    await _syncFcmTokenToProfile();

    // Foreground messages -> show local notification (mobile only)
    _platform.onMessage((message) {
      _showLocalFromRemote(message);
    });

    // App opened from notification (mobile only)
    if (onMessageOpenedApp != null) {
      _platform.onMessageOpenedApp(onMessageOpenedApp);
    }

    _initialized = true;
  }

  // Schedule a single daily goal reminder at the user's preferred local time.
  Future<void> scheduleDailyGoalReminder({
    required TimeOfDay time,
    String? timezone, // unused now; kept for API compatibility
    String title = 'Set Your Daily Goals',
    String body = 'Hey! Don\'t forget to set your goals for today! 🎯',
  }) async {
    await _ensureTimezoneInitialized();

    // If a specific timezone is provided, try to set it for this schedule only.
    tz.TZDateTime nextInstance() {
      // We schedule in UTC to avoid requiring platform timezone. Convert the user's selected
      // local time to a UTC wall-clock time for the next occurrence.
      final nowLocal = DateTime.now();
      var scheduledLocal = DateTime(
          nowLocal.year, nowLocal.month, nowLocal.day, time.hour, time.minute);
      if (scheduledLocal.isBefore(nowLocal)) {
        scheduledLocal = scheduledLocal.add(const Duration(days: 1));
      }
      final scheduledUtc = scheduledLocal.toUtc();
      return tz.TZDateTime.from(scheduledUtc, tz.getLocation('UTC'));
    }

    const androidDetails = AndroidNotificationDetails(
      'mlq_high_importance',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon', // Use Questor robot icon
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _fln.zonedSchedule(
      _dailyReminderId,
      title,
      body,
      nextInstance(),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Note: Using UTC for matching may differ from user's local timezone during DST changes.
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '{"type":"goal"}',
    );
  }

  Future<void> cancelDailyGoalReminder() async {
    await _fln.cancel(_dailyReminderId);
  }

  Future<void> _requestPermissions() async {
    try {
      await _platform.requestPermission();

      // Android-specific settings for heads-up notifications
      if (Platform.isAndroid) {
        final androidFln = _fln.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidFln
            ?.createNotificationChannel(const AndroidNotificationChannel(
          'mlq_high_importance',
          'High Importance Notifications',
          importance: Importance.max,
          description: 'Heads-up notifications for important updates',
        ));
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Permission request failed: $e');
    }
  }

  Future<void> _syncFcmTokenToProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint(
            '[PushNotificationService] No authenticated user, skipping FCM token sync');
        return;
      }

      final token = await _platform.getToken();
      if (token == null) {
        debugPrint('[PushNotificationService] FCM token is null, cannot sync');
        return;
      }

      // Check if we already synced this exact token for this user
      final prefs = await SharedPreferences.getInstance();
      final lastSyncedToken = prefs.getString(_fcmTokenValueKey);
      final lastSyncedUserId = prefs.getString('${_fcmTokenKey}_user_id');

      if (lastSyncedToken == token && lastSyncedUserId == user.id) {
        debugPrint(
            '[PushNotificationService] FCM token already synced for this user');
        _tokenSynced = true;
        _lastSyncedToken = token;
        return;
      }

      await SupabaseService.instance.client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', user.id);

      // Save the synced token locally
      await prefs.setString(_fcmTokenValueKey, token);
      await prefs.setString('${_fcmTokenKey}_user_id', user.id);
      _tokenSynced = true;
      _lastSyncedToken = token;

      debugPrint(
          '[PushNotificationService] ✅ FCM token synced to profile for user ${user.id}');

      // Listen for token refresh (only register once)
      _registerTokenRefreshListener();
    } catch (e) {
      debugPrint('[PushNotificationService] ❌ Token sync failed: $e');
    }
  }

  /// Register token refresh listener (only once)
  void _registerTokenRefreshListener() {
    if (_tokenRefreshListenerRegistered) return;
    _tokenRefreshListenerRegistered = true;

    _platform.onTokenRefresh((newToken) async {
      debugPrint(
          '[PushNotificationService] Token refresh detected, syncing...');
      await syncFcmToken();
    });
  }

  /// Public method to sync FCM token - call this after user authentication
  Future<void> syncFcmToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint(
            '[PushNotificationService] syncFcmToken: No authenticated user');
        return;
      }

      final token = await _platform.getToken();
      if (token == null) {
        debugPrint('[PushNotificationService] syncFcmToken: FCM token is null');
        return;
      }

      // Skip if already synced this exact token
      if (_lastSyncedToken == token && _tokenSynced) {
        debugPrint(
            '[PushNotificationService] syncFcmToken: Token already synced');
        return;
      }

      await SupabaseService.instance.client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', user.id);

      // Save the synced token locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenValueKey, token);
      await prefs.setString('${_fcmTokenKey}_user_id', user.id);
      _tokenSynced = true;
      _lastSyncedToken = token;

      debugPrint(
          '[PushNotificationService] ✅ FCM token synced via syncFcmToken() for user ${user.id}');

      // Ensure token refresh listener is registered
      _registerTokenRefreshListener();
    } catch (e) {
      debugPrint('[PushNotificationService] ❌ syncFcmToken failed: $e');
    }
  }

  /// Check if FCM token is synced for current user
  bool get isTokenSynced => _tokenSynced;

  /// Clear token sync state (call on logout)
  Future<void> clearTokenState() async {
    _tokenSynced = false;
    _lastSyncedToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenValueKey);
      await prefs.remove('${_fcmTokenKey}_user_id');
      debugPrint('[PushNotificationService] Token state cleared');
    } catch (e) {
      debugPrint('[PushNotificationService] Error clearing token state: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    // Use the standard launcher icon for notifications to avoid resource mismatches
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _fln.initialize(initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap for local notifications
    });
  }

  Future<void> _ensureTimezoneInitialized() async {
    if (_tzInitialized) return;
    try {
      // Initialize timezone database and default to UTC. We avoid querying platform timezone
      // to remove dependency issues and ensure stable scheduling.
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
      _tzInitialized = true;
    } catch (_) {
      // If even UTC fails, keep _tzInitialized false; scheduling will no-op.
    }
  }

  Future<void> _showLocalFromRemote(dynamic message) async {
    // Extract notification data from platform-specific message
    final notification = _platform.getNotificationFromMessage(message);
    if (notification == null) return;

    final androidBitmap = await _loadNotificationBitmap();
    final styleInfo = androidBitmap != null
        ? BigPictureStyleInformation(
            androidBitmap,
            largeIcon: androidBitmap,
            hideExpandedLargeIcon: false,
          )
        : null;

    final androidDetails = AndroidNotificationDetails(
      'mlq_high_importance',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon', // Use Questor robot icon
      largeIcon: androidBitmap,
      styleInformation: styleInfo,
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final messageData = _platform.getDataFromMessage(message);
    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification['title'] ?? 'New Notification',
      notification['body'] ?? '',
      details,
      payload: messageData.isNotEmpty ? jsonEncode(messageData) : null,
    );
  }

  // Exposes a simple way to preview how a push looks via local notifications
  Future<void> showTestNotification({
    String title = 'New Challenge Available!',
    String body = 'Premium challenge: Test Challenge',
    String type = 'challenge',
    String relatedId = 'test',
  }) async {
    final androidBitmap = await _loadNotificationBitmap();
    final styleInfo = androidBitmap != null
        ? BigPictureStyleInformation(
            androidBitmap,
            largeIcon: androidBitmap,
            hideExpandedLargeIcon: false,
          )
        : null;

    final androidDetails = AndroidNotificationDetails(
      'mlq_high_importance',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon', // Use Questor robot icon
      largeIcon: androidBitmap,
      styleInformation: styleInfo,
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload = jsonEncode({'type': type, 'related_id': relatedId});

    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<AndroidBitmap<Object>?> _loadNotificationBitmap() async {
    try {
      // Use the Questor brand image from assets
      const assetPath = 'assets/images/questor 9.png';
      final bytes = await rootBundle.load(assetPath);
      return ByteArrayAndroidBitmap(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint(
          '[PushNotificationService] Failed to load notification image: $e');
      return null;
    }
  }
}

import 'dart:io';

import 'push_notification_mobile.dart';
import 'push_notification_stub.dart';

/// Platform-aware push notification service
/// Routes to appropriate implementation based on platform
class PushNotificationPlatform {
  late final dynamic _impl;

  PushNotificationPlatform() {
    if (Platform.isAndroid || Platform.isIOS) {
      _impl = PushNotificationMobile();
    } else {
      _impl = PushNotificationStub();
    }
  }

  Future<void> initialize() async {
    await _impl.initialize();
  }

  void onMessage(void Function(dynamic) handler) {
    _impl.onMessage(handler);
  }

  void onMessageOpenedApp(void Function(dynamic) handler) {
    _impl.onMessageOpenedApp(handler);
  }

  Future<String?> getToken() async {
    return await _impl.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _impl.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _impl.unsubscribeFromTopic(topic);
  }

  Future<void> requestPermission() async {
    await _impl.requestPermission();
  }

  void onTokenRefresh(void Function(String) handler) {
    _impl.onTokenRefresh(handler);
  }

  Map<String, dynamic>? getNotificationFromMessage(dynamic message) {
    return _impl.getNotificationFromMessage(message);
  }

  Map<String, dynamic> getDataFromMessage(dynamic message) {
    return _impl.getDataFromMessage(message);
  }
}

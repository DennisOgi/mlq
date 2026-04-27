import 'package:firebase_messaging/firebase_messaging.dart';

/// Mobile implementation of push notifications using Firebase
class PushNotificationMobile {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void onMessage(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  void onMessageOpenedApp(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  Future<void> requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void onTokenRefresh(void Function(String) handler) {
    _messaging.onTokenRefresh.listen(handler);
  }

  Map<String, dynamic>? getNotificationFromMessage(dynamic message) {
    if (message is RemoteMessage) {
      final notification = message.notification;
      if (notification == null) return null;
      return {
        'title': notification.title,
        'body': notification.body,
      };
    }
    return null;
  }

  Map<String, dynamic> getDataFromMessage(dynamic message) {
    if (message is RemoteMessage) {
      return message.data;
    }
    return {};
  }
}

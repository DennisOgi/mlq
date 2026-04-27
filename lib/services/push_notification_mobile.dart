/// Stub implementation of push notifications for desktop platforms
/// Desktop platforms don't support Firebase Messaging
class PushNotificationMobile {
  Future<void> initialize() async {
    // No-op on desktop
  }

  void onMessage(void Function(dynamic) handler) {
    // No-op on desktop
  }

  void onMessageOpenedApp(void Function(dynamic) handler) {
    // No-op on desktop
  }

  Future<String?> getToken() async {
    return null; // No FCM token on desktop
  }

  Future<void> subscribeToTopic(String topic) async {
    // No-op on desktop
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    // No-op on desktop
  }

  Future<void> requestPermission() async {
    // No-op on desktop
  }

  void onTokenRefresh(void Function(String) handler) {
    // No-op on desktop
  }

  Map<String, dynamic>? getNotificationFromMessage(dynamic message) {
    return null; // No messages on desktop
  }

  Map<String, dynamic> getDataFromMessage(dynamic message) {
    return {}; // No data on desktop
  }
}

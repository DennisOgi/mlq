/// Stub implementation for platforms without push notification support
class PushNotificationStub {
  Future<void> initialize() async {
    // No-op for desktop platforms
  }

  void onMessage(void Function(Map<String, dynamic>) handler) {
    // No-op
  }

  void onMessageOpenedApp(void Function(Map<String, dynamic>) handler) {
    // No-op
  }

  Future<String?> getToken() async {
    return null;
  }

  Future<void> subscribeToTopic(String topic) async {
    // No-op
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    // No-op
  }

  Future<void> requestPermission() async {
    // No-op for desktop platforms
  }

  void onTokenRefresh(void Function(String) handler) {
    // No-op
  }

  Map<String, dynamic>? getNotificationFromMessage(dynamic message) {
    return null;
  }

  Map<String, dynamic> getDataFromMessage(dynamic message) {
    return {};
  }
}

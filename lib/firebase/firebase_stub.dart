/// Stub implementation for platforms that don't support Firebase
class FirebaseStub {
  static Future<void> initialize() async {
    // No-op for Windows / Desktop
    // Firebase is not available on these platforms
  }
}

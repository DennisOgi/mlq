import 'dart:io';

import 'firebase_mobile.dart';
import 'firebase_stub.dart';

/// Platform-aware Firebase initializer
/// Uses real Firebase on mobile, stub on desktop
class FirebaseInitializer {
  static Future<void> initialize() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await FirebaseMobile.initialize();
    } else {
      await FirebaseStub.initialize();
    }
  }
}

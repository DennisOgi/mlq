import 'dart:io';
import 'package:flutter/foundation.dart';

// Conditional import: use desktop stub on Windows/Linux/macOS, real Firebase on mobile
import 'firebase_mobile.dart'
    if (dart.library.io) 'firebase_mobile_desktop.dart';
import 'firebase_stub.dart';

/// Platform-aware Firebase initializer
/// Uses real Firebase on mobile, stub on desktop
class FirebaseInitializer {
  static Future<void> initialize() async {
    // Web platform doesn't need Firebase (push notifications not supported)
    if (kIsWeb) {
      debugPrint('✅ Skipping Firebase on web platform - not required');
      return;
    }
    
    // Desktop platforms (Windows, Linux, macOS) don't need Firebase
    // Firebase is only used for push notifications which are mobile-only
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('✅ Skipping Firebase on desktop platform - not required');
      return;
    }
    
    if (Platform.isAndroid || Platform.isIOS) {
      await FirebaseMobile.initialize();
    } else {
      await FirebaseStub.initialize();
    }
  }
}

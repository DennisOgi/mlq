import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Firebase implementation for mobile platforms (Android & iOS)
class FirebaseMobile {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

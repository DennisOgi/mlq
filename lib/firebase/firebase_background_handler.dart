import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firebase_mobile.dart';

/// Background message handler for Firebase Cloud Messaging
/// Must be a top-level function to work in background isolates
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background processing
  await FirebaseMobile.initialize();

  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint("Background message data: ${message.data}");

  // Here you could add logic to process the background message
  // For example, update local storage, show a local notification, etc.
}

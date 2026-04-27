import 'dart:io';
import 'push_notification_mobile_real.dart';
import 'push_notification_stub.dart';

/// Factory function for conditional import
dynamic createPushNotificationImpl() {
  if (Platform.isAndroid || Platform.isIOS) {
    return PushNotificationMobile();
  } else {
    return PushNotificationStub();
  }
}

import 'package:flutter/services.dart';

/// Quiz feedback audio — disabled for now; haptics only.
class QuizSoundEffects {
  QuizSoundEffects._();

  static Future<void> init() async {}

  static Future<void> stop() async {}

  static Future<void> playCorrect() async {
    HapticFeedback.lightImpact();
  }

  static Future<void> playWrong() async {
    HapticFeedback.mediumImpact();
  }

  static Future<void> playWin() async {
    HapticFeedback.heavyImpact();
  }
}

import 'package:flutter/foundation.dart';
import 'autonomous_coach_service.dart';

/// Simple test service to demonstrate autonomous coaching
class TestAutonomousCoach {
  static void triggerTestMessage() {
    debugPrint('Test: Triggering autonomous message...');
    
    // Create a test autonomous message
    final testMessage = AutonomousMessage(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      content: 'Hey there, champion! 🌟 This is a test of the autonomous coaching system. Keep up the great work!',
      timestamp: DateTime.now(),
      type: 'General',
      questorImage: 'assets/images/questor 2.png', // Happy Questor
    );
    
    // Send the message through the autonomous coach service
    AutonomousCoachService.instance.messageController.add(testMessage);
    
    debugPrint('Test: Autonomous message sent!');
  }
  
  static void triggerMorningMessage() {
    final morningMessage = AutonomousMessage(
      id: 'morning_${DateTime.now().millisecondsSinceEpoch}',
      content: 'Good morning, leader! 🌅 Ready to conquer your goals today? I believe in you!',
      timestamp: DateTime.now(),
      type: 'Morning Boost',
      questorImage: 'assets/images/questor 4.png', // Excited Questor
    );
    
    AutonomousCoachService.instance.messageController.add(morningMessage);
  }
  
  static void triggerEveningMessage() {
    final eveningMessage = AutonomousMessage(
      id: 'evening_${DateTime.now().millisecondsSinceEpoch}',
      content: 'Great job today! 🎉 Take a moment to reflect on what you accomplished. What are you grateful for?',
      timestamp: DateTime.now(),
      type: 'Evening Reflection',
      questorImage: 'assets/images/questor 2.png', // Happy Questor
    );
    
    AutonomousCoachService.instance.messageController.add(eveningMessage);
  }
}

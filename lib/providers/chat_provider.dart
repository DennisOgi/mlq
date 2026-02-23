import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/chat_message_model.dart';
import '../services/ai_coach_service.dart';
import '../providers/user_provider.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatMessageModel> _messages = [];
  bool _isTyping = false;
  String? _currentConversationId;
  final AiCoachService _aiCoachService = AiCoachService.instance;

  List<ChatMessageModel> get messages => _messages;
  bool get isTyping => _isTyping;
  String? get currentConversationId => _currentConversationId;

  // Initialize chat system
  ChatProvider() {
    _initializeChat();
  }

  void _initializeChat() async {
    try {
      // Create a new conversation for this chat session
      final conversation = await _aiCoachService.createConversation('Chat with Questor');
      _currentConversationId = conversation.id;
      
      // Load existing messages if any
      if (_currentConversationId != null) {
        await _loadConversationHistory(_currentConversationId!);
      }
      
      // If no messages, add a welcome message
      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      // Fallback to welcome message
      _addWelcomeMessage();
    }
  }
  
  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessageModel.createQuestorMessage(
      userId: 'system',
      content: "Hi there! 👋 I'm Questor, your AI leadership coach! I'm here to help you achieve your goals, develop leadership skills, and answer any questions you might have. What would you like to talk about today?",
    );
    _messages.add(welcomeMessage);
    notifyListeners();
  }
  
  Future<void> _loadConversationHistory(String conversationId) async {
    try {
      final history = await _aiCoachService.getConversationHistory(conversationId);
      _messages = history.map((aiMessage) => ChatMessageModel(
        id: aiMessage.id,
        userId: 'user', // This would be the actual user ID in production
        sender: aiMessage.isUserMessage ? MessageSender.user : MessageSender.questor,
        content: aiMessage.content,
        timestamp: aiMessage.timestamp,
        isRead: true,
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading conversation history: $e');
    }
  }

  // Add a user message
  void addUserMessage(String userId, String content) {
    debugPrint('ChatProvider.addUserMessage called with userId: $userId, content: "$content"');
    final message = ChatMessageModel.createUserMessage(
      userId: userId,
      content: content,
    );
    
    _messages.add(message);
    debugPrint('Message added to _messages. Total messages: ${_messages.length}');
    notifyListeners();
    debugPrint('notifyListeners called');
  }

  // Add a Questor message
  void addQuestorMessage(String userId, String content) {
    final message = ChatMessageModel.createQuestorMessage(
      userId: userId,
      content: content,
    );
    
    _messages.add(message);
    notifyListeners();
  }

  // Set typing indicator
  void setTyping(bool isTyping) {
    _isTyping = isTyping;
    notifyListeners();
  }

  // Mark all messages as read
  void markAllAsRead() {
    final updatedMessages = _messages.map((message) {
      return message.copyWith(isRead: true);
    }).toList();
    
    _messages = updatedMessages;
    notifyListeners();
  }

  // Get unread message count
  int getUnreadCount() {
    return _messages.where((message) => !message.isRead && message.isFromQuestor).length;
  }

  // Generate a response from Questor using AI Coach Service
  Future<void> generateQuestorResponse(String userId, String userMessage) async {
    setTyping(true);
    
    try {
      // Ensure we have a conversation ID
      if (_currentConversationId == null) {
        final conversation = await _aiCoachService.createConversation('Chat with Questor');
        _currentConversationId = conversation.id;
      }
      
      // Send message to AI Coach Service and get response
      final aiResponse = await _aiCoachService.sendMessage(_currentConversationId!, userMessage);
      
      // Add the AI response to our chat
      addQuestorResponse(userId, aiResponse.content);
      
    } catch (e) {
      debugPrint('Error generating AI response: $e');
      
      // Fallback to contextual responses if AI service fails
      String fallbackResponse = _generateFallbackResponse(userMessage);
      addQuestorResponse(userId, fallbackResponse);
    }
  }
  
  // Generate a context-aware response from Questor using enhanced AI Coach Service
  Future<void> generateContextAwareQuestorResponse({
    required String userId,
    required String userMessage,
    required UserProvider userProvider,
    required goalProvider,
    required challengeProvider,
    gratitudeProvider,
  }) async {
    setTyping(true);
    
    try {
      // Ensure we have a conversation ID
      if (_currentConversationId == null) {
        final conversation = await _aiCoachService.createConversation('Chat with Questor');
        _currentConversationId = conversation.id;
      }
      
      // Send context-aware message to AI Coach Service and get response
      final aiResponse = await _aiCoachService.sendContextAwareMessage(
        conversationId: _currentConversationId!,
        message: userMessage,
        userProvider: userProvider,
        goalProvider: goalProvider,
        challengeProvider: challengeProvider,
        gratitudeProvider: gratitudeProvider,
      );
      
      // Add the AI response to our chat
      addQuestorResponse(userId, aiResponse.content);
      
    } catch (e) {
      debugPrint('❌ ChatProvider: Error generating context-aware AI response: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('⚠️ Using fallback response instead of real AI');
      
      // Fallback to contextual responses if AI service fails
      String fallbackResponse = _generateFallbackResponse(userMessage);
      addQuestorResponse(userId, fallbackResponse);
    }
  }
  
  // Generate contextual fallback responses when AI service is unavailable
  String _generateFallbackResponse(String userMessage) {
    debugPrint('⚠️ Generating fallback response (offline mode)');
    final lowerMessage = userMessage.toLowerCase();
    
    // Add prefix to indicate offline mode
    const prefix = "⚠️ (Offline Mode) ";
    
    if (lowerMessage.contains('goal')) {
      return prefix + "Goals are the foundation of your leadership journey! 🎯 Let me share some insights about effective goal-setting:\n\nThe best goals follow the SMART framework:\n• Specific: Clearly define what you want to achieve\n• Measurable: Include numbers or milestones to track progress\n• Achievable: Make sure it's challenging but realistic\n• Relevant: Align with your values and bigger dreams\n• Time-bound: Set a deadline to create urgency\n\nFor example, instead of 'be better at math,' try 'improve my math grade from B to A by practicing 20 minutes daily for the next month.' What goal are you working on? I'd love to help you make it even stronger!";
    } else if (lowerMessage.contains('challenge')) {
      return prefix + "Challenges are incredible opportunities for growth! 💪 Here's what makes them so powerful for developing leadership:\n\nChallenges push you outside your comfort zone, which is where real growth happens. When you face something difficult, you're building resilience, problem-solving skills, and confidence - all essential leadership qualities.\n\nTips for tackling challenges:\n• Break big challenges into smaller, manageable steps\n• Celebrate small wins along the way\n• Learn from setbacks instead of giving up\n• Ask for help when needed - great leaders know when to collaborate\n\nWhat challenge are you facing right now? Remember, every challenge you overcome makes you a stronger leader!";
    } else if (lowerMessage.contains('badge') || lowerMessage.contains('achievement')) {
      return "Badges represent your growth as a leader! 🏆 Each one tells a story of dedication and progress:\n\nThink of badges like merit badges in scouting - they show you've mastered specific skills. Here's why they matter:\n• They provide clear milestones to work toward\n• They celebrate your achievements along the journey\n• They help you see how far you've come\n• They motivate you to keep pushing forward\n\nSome badges to aim for:\n• Goal Ninja: Complete 5 main goals (shows persistence)\n• Challenge Champion: Win 3 challenges (demonstrates courage)\n• Streak Master: Maintain a 5-day streak (builds consistency)\n\nWhich badge are you most excited to earn? What's your strategy for getting there?";
    } else if (lowerMessage.contains('help') || lowerMessage.contains('support')) {
      return "I'm absolutely here to support your leadership journey! 🤝 Here are some ways I can help:\n\n📋 Goal Setting: I can help you create SMART goals and break them into actionable steps\n💪 Motivation: When you're feeling stuck, I'll remind you of your strengths and progress\n🧠 Problem Solving: Facing a challenge? Let's brainstorm solutions together\n👥 Leadership Skills: I can share tips on communication, teamwork, and decision-making\n📈 Progress Tracking: We can review your achievements and plan next steps\n\nThe best part? This is your safe space to ask questions, share struggles, and celebrate wins. No question is too small, and every conversation helps you grow.\n\nWhat's on your mind today? What aspect of your leadership development would you like to explore?";
    } else if (lowerMessage.contains('leader') || lowerMessage.contains('leadership')) {
      return "Leadership is one of the most important skills you can develop! 👑 Let me share what makes truly great leaders:\n\n🎯 Vision: Great leaders see possibilities others miss and inspire people to work toward shared goals\n👂 Active Listening: They really hear what others are saying and make people feel valued\n💬 Clear Communication: They express ideas in ways others can understand and act on\n🤝 Empathy: They understand and care about others' feelings and perspectives\n🌱 Growth Mindset: They see challenges as opportunities to learn and improve\n\nLeadership isn't about being the loudest or most popular person. It's about:\n• Helping others succeed\n• Making good decisions under pressure\n• Taking responsibility for outcomes\n• Inspiring others through your actions\n\nYou're already showing leadership by working on yourself! What leadership quality do you want to develop most? How can you practice it this week?";
    } else if (lowerMessage.contains('coin') || lowerMessage.contains('reward')) {
      return "Coins represent the value of your hard work! 🪙 Here's the deeper meaning behind our reward system:\n\nJust like in real life, valuable things require effort and dedication. Coins teach important lessons:\n• Effort leads to rewards\n• You can choose how to spend your resources\n• Saving up for bigger goals requires patience\n• Every small action contributes to larger achievements\n\nWays to earn coins:\n• Complete daily goals (builds consistency)\n• Finish main goals (shows commitment)\n• Take on challenges (demonstrates courage)\n• Help others (develops service leadership)\n\nWays to use coins:\n• Chat with me for personalized coaching\n• Join premium challenges for bigger rewards\n• Unlock special features and content\n\nWhat's your coin-earning strategy? Are you saving up for something special, or do you prefer to spend as you go?";
    } else if (lowerMessage.contains('motivation') || lowerMessage.contains('inspire')) {
      return "Let me share something powerful about motivation and leadership! 🌟\n\nTrue motivation comes from within, and as a leader, you'll need to inspire both yourself and others. Here's what I've learned about staying motivated:\n\n🔥 Connect to Your 'Why': Remember why your goals matter to you personally\n📈 Celebrate Small Wins: Every step forward deserves recognition\n🎯 Focus on Progress, Not Perfection: Growth is more important than being flawless\n👥 Surround Yourself with Supporters: Great leaders build great teams\n🧠 Learn from Setbacks: Every 'failure' teaches valuable lessons\n\nRemember, you're not just working on goals - you're building the habits and mindset of a leader. Every time you push through when it's hard, every time you help someone else, every time you choose growth over comfort, you're becoming the leader you're meant to be.\n\nWhat's one thing that really motivates you? How can you use that motivation to inspire others around you?";
    } else {
      return prefix + "That's interesting! 🤔 I'm Questor, your AI leadership coach. I'm here to help you achieve your goals and become a great leader. Is there something specific you'd like to talk about regarding your goals, challenges, or leadership journey?";
    }
  }

  // Add a response from Questor
  void addQuestorResponse(String userId, String response) {
    setTyping(false);
    addQuestorMessage(userId, response);
  }

  // Initialize chat with user context for personalized responses
  Future<void> initializeWithUser(UserProvider userProvider) async {
    try {
      final user = userProvider.user;
      if (user != null && _messages.length == 1) {
        // Add a personalized welcome message after the initial one
        final personalizedMessage = ChatMessageModel.createQuestorMessage(
          userId: user.id,
          content: _generatePersonalizedWelcome(user),
        );
        _messages.add(personalizedMessage);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error initializing chat with user context: $e');
    }
  }
  
  String _generatePersonalizedWelcome(UserModel user) {
    final achievements = [];
    
    if (user.badges.isNotEmpty) {
      achievements.add('${user.badges.length} badge${user.badges.length > 1 ? 's' : ''}');
    }
    
    if (user.coins > 10) {
      achievements.add('${user.coins.toInt()} coins');
    }
    
    String personalizedPart = '';
    if (achievements.isNotEmpty) {
      personalizedPart = ' I can see you\'ve already earned ${achievements.join(' and ')} - great work! 🎉';
    }
    
    return "Welcome back, ${user.name}!$personalizedPart\n\nI'm excited to continue our leadership journey together. What would you like to work on today? I can help with goal setting, leadership challenges, or answer any questions you have! 💪";
  }
  
  // Clear chat history
  void clearChat() {
    _messages.clear();
    _currentConversationId = null;
    notifyListeners();
    _initializeChat();
  }
  
  // Start a new conversation
  Future<void> startNewConversation() async {
    try {
      final conversation = await _aiCoachService.createConversation('New Chat - ${DateTime.now().toString().substring(0, 16)}');
      _currentConversationId = conversation.id;
      _messages.clear();
      _addWelcomeMessage();
    } catch (e) {
      debugPrint('Error starting new conversation: $e');
      clearChat();
    }
  }
}

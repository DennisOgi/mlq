enum MessageSender { user, questor }

class ChatMessageModel {
  final String id;
  final String userId;
  final MessageSender sender;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.userId,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  bool get isFromUser => sender == MessageSender.user;
  bool get isFromQuestor => sender == MessageSender.questor;

  ChatMessageModel copyWith({
    String? id,
    String? userId,
    MessageSender? sender,
    String? content,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'sender': sender.index,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      userId: json['userId'],
      sender: MessageSender.values[json['sender']],
      content: json['content'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      isRead: json['isRead'] ?? false,
    );
  }

  // Create a user message
  static ChatMessageModel createUserMessage({
    required String userId,
    required String content,
  }) {
    return ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      sender: MessageSender.user,
      content: content,
      timestamp: DateTime.now(),
      isRead: true,
    );
  }

  // Create a Questor message
  static ChatMessageModel createQuestorMessage({
    required String userId,
    required String content,
  }) {
    return ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      sender: MessageSender.questor,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  // Mock chat messages for development
  static List<ChatMessageModel> mockChatMessages() {
    final userId = 'user123';
    final now = DateTime.now();
    
    return [
      ChatMessageModel(
        id: '1',
        userId: userId,
        sender: MessageSender.questor,
        content: 'Hi there! I\'m Questor, your AI coach. How can I help you with your goals today?',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '2',
        userId: userId,
        sender: MessageSender.user,
        content: 'I\'m having trouble with my math homework.',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 45)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '3',
        userId: userId,
        sender: MessageSender.questor,
        content: 'I understand math can be challenging! What specific part are you struggling with?',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 40)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '4',
        userId: userId,
        sender: MessageSender.user,
        content: 'Fractions. I don\'t understand how to add them.',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 30)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '5',
        userId: userId,
        sender: MessageSender.questor,
        content: 'Fractions can be tricky! Here\'s a simple way to think about adding fractions:\n\n1. Make sure the denominators (bottom numbers) are the same\n2. If they\'re not the same, find a common denominator\n3. Add the numerators (top numbers)\n4. Simplify the fraction if needed\n\nWould you like me to show you an example?',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 25)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '6',
        userId: userId,
        sender: MessageSender.user,
        content: 'Yes, please!',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 20)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '7',
        userId: userId,
        sender: MessageSender.questor,
        content: 'Let\'s add 1/4 + 2/4:\n\n1. The denominators are already the same (4)\n2. Add the numerators: 1 + 2 = 3\n3. So 1/4 + 2/4 = 3/4\n\nLet\'s try another: 1/3 + 1/2\n\n1. The denominators are different (3 and 2)\n2. Find a common denominator: 6 works for both\n3. Convert fractions: 1/3 = 2/6 and 1/2 = 3/6\n4. Add: 2/6 + 3/6 = 5/6\n\nDoes that help?',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 15)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '8',
        userId: userId,
        sender: MessageSender.user,
        content: 'That makes sense! Thank you!',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 10)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '9',
        userId: userId,
        sender: MessageSender.questor,
        content: 'You\'re welcome! I\'m glad I could help. Remember, practice makes perfect. Try a few examples on your own, and let me know if you have any more questions!',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 5)),
        isRead: true,
      ),
      ChatMessageModel(
        id: '10',
        userId: userId,
        sender: MessageSender.questor,
        content: 'By the way, I noticed you\'ve been making great progress on your academic goals! You\'ve completed 3 daily goals this week. Keep up the good work!',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: false,
      ),
    ];
  }
}

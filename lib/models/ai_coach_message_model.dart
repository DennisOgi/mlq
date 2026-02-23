class AiCoachMessageModel {
  final String id;
  final String conversationId;
  final String content;
  final bool isUserMessage;
  final DateTime timestamp;
  
  AiCoachMessageModel({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.isUserMessage,
    required this.timestamp,
  });
  
  factory AiCoachMessageModel.fromJson(Map<String, dynamic> json) {
    return AiCoachMessageModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      content: json['content'],
      isUserMessage: json['is_user_message'],
      timestamp: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'content': content,
      'is_user_message': isUserMessage,
      'created_at': timestamp.toIso8601String(),
    };
  }
}

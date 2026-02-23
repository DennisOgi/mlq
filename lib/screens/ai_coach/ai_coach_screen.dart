import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_coach_service.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({Key? key}) : super(key: key);

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _friendlyDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return 'Today';
  if (d == yesterday) return 'Yesterday';
  return '${date.day}/${date.month}/${date.year}';
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage(AppAssets.questorThinking),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neumorphicDark,
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: AppColors.neumorphicHighlight,
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ],
              border: Border.all(color: AppColors.tertiary, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(),
                const SizedBox(width: 4),
                _Dot(delay: 150),
                const SizedBox(width: 4),
                _Dot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward(from: widget.delay / 900)
      ..repeat();
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const CircleAvatar(radius: 3, backgroundColor: AppColors.textSecondary),
    );
  }
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final TextEditingController _messageController = TextEditingController();
  final AiCoachService _aiCoachService = AiCoachService();
  final ScrollController _scrollController = ScrollController();
  
  String? _currentConversationId;
  String _conversationTitle = 'Leadership Chat';
  List<AiCoachMessageModel> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _showScrollToBottom = false;
  
  @override
  void initState() {
    super.initState();
    _initializeConversation();
    _messageController.addListener(() => setState(() {}));
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final atBottom = _scrollController.position.pixels >=
          (_scrollController.position.maxScrollExtent - 32);
      final shouldShow = !atBottom;
      if (_showScrollToBottom != shouldShow) {
        setState(() {
          _showScrollToBottom = shouldShow;
        });
      }
    });
  }
  
  Future<void> _initializeConversation() async {
    setState(() => _isInitializing = true);
    
    try {
      // Get existing conversations
      final conversations = await _aiCoachService.getAllConversations();
      
      if (conversations.isNotEmpty) {
        // Use the most recent conversation
        final latestConversation = conversations.reduce((a, b) => 
          a.updatedAt.isAfter(b.updatedAt) ? a : b);
        _currentConversationId = latestConversation.id;
        _conversationTitle = latestConversation.title;
        
        // Get messages for this conversation
        _messages = await _aiCoachService.getConversationHistory(_currentConversationId!);
      } else {
        // Create a new conversation
        final conversation = await _aiCoachService.createConversation(_conversationTitle);
        _currentConversationId = conversation.id;
        
        // Add welcome message
        _messages.add(AiCoachMessageModel(
          id: 'welcome',
          conversationId: _currentConversationId!,
          content: 'Hi there! I\'m Questor, your leadership coach. How can I help you today?',
          isUserMessage: false,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('Error initializing conversation: $e');
      // Create a fallback conversation
      final conversation = await _aiCoachService.createConversation(_conversationTitle);
      _currentConversationId = conversation.id;
      
      // Add welcome message
      _messages.add(AiCoachMessageModel(
        id: 'welcome',
        conversationId: _currentConversationId!,
        content: 'Hi there! I\'m Questor, your leadership coach. How can I help you today?',
        isUserMessage: false,
        timestamp: DateTime.now(),
      ));
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    
    if (message.isEmpty || _isLoading || _currentConversationId == null) return;
    
    // Clear input field
    _messageController.clear();
    
    // Add user message to the list
    setState(() {
      _messages.add(AiCoachMessageModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: _currentConversationId!,
        content: message,
        isUserMessage: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    
    // Scroll to bottom
    _scrollToBottom();
    
    try {
      // Get response from AI coach
      final response = await _aiCoachService.sendMessage(_currentConversationId!, message);
      
      setState(() {
        _messages.add(response);
        _isLoading = false;
      });
      
      // Scroll to bottom again after response
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      setState(() {
        _messages.add(AiCoachMessageModel(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: _currentConversationId!,
          content: 'Sorry, I\'m having trouble right now. Please try again later.',
          isUserMessage: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      
      _scrollToBottom();
    }
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Future<void> _startNewConversation() async {
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => _NewConversationDialog(),
    );
    
    if (newTitle != null && newTitle.isNotEmpty) {
      setState(() {
        _isInitializing = true;
        _messages = [];
      });
      
      try {
        final conversation = await _aiCoachService.createConversation(newTitle);
        setState(() {
          _currentConversationId = conversation.id;
          _conversationTitle = conversation.title;
          _messages = [
            AiCoachMessageModel(
              id: 'welcome',
              conversationId: _currentConversationId!,
              content: 'Hi there! I\'m Questor, your leadership coach. How can I help you today?',
              isUserMessage: false,
              timestamp: DateTime.now(),
            ),
          ];
        });
      } catch (e) {
        debugPrint('Error creating new conversation: $e');
      } finally {
        setState(() => _isInitializing = false);
      }
    }
  }
  
  Future<void> _showConversationsList() async {
    final conversations = await _aiCoachService.getAllConversations();
    
    if (conversations.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous conversations found')),
        );
      }
      return;
    }
    
    if (context.mounted) {
      final selectedConversation = await showDialog<AiCoachConversationModel>(
        context: context,
        builder: (context) => _ConversationsListDialog(conversations: conversations),
      );
      
      if (selectedConversation != null) {
        setState(() {
          _isInitializing = true;
          _messages = [];
        });
        
        try {
          _currentConversationId = selectedConversation.id;
          _conversationTitle = selectedConversation.title;
          _messages = await _aiCoachService.getConversationHistory(_currentConversationId!);
          
          if (_messages.isEmpty) {
            _messages = [
              AiCoachMessageModel(
                id: 'welcome',
                conversationId: _currentConversationId!,
                content: 'This conversation was empty. How can I help you today?',
                isUserMessage: false,
                timestamp: DateTime.now(),
              ),
            ];
          }
        } catch (e) {
          debugPrint('Error loading conversation: $e');
        } finally {
          setState(() => _isInitializing = false);
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _conversationTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showConversationsList,
            tooltip: 'Previous conversations',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _startNewConversation,
            tooltip: 'New conversation',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Chat messages area
              Expanded(
                child: _isInitializing
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMessagesList(),
              ),
              
              // Bottom input area
              _buildInputArea(),
            ],
          ),
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 80,
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: AppTheme.getNeumorphicDecoration().copyWith(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward_rounded,
                      color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // Typing indicator last
        if (_isLoading && index == _messages.length) {
          return _TypingIndicator();
        }

        final message = _messages[index];
        // Date separator logic
        String? dateLabel;
        if (index == 0 || !_isSameDay(_messages[index - 1].timestamp, message.timestamp)) {
          dateLabel = _friendlyDate(message.timestamp);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dateLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: AppTheme.getNeumorphicDecoration().copyWith(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      dateLabel,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            _MessageBubble(message: message),
          ],
        );
      },
    );
  }
  
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: AppTheme.getNeumorphicDecoration().copyWith(color: AppColors.surface),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              decoration: AppTheme.getPressedNeumorphicDecoration().copyWith(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Ask Questor something...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Send button
          Container(
            decoration: AppTheme.getNeumorphicDecoration().copyWith(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _isLoading || _messageController.text.trim().isEmpty
                  ? null
                  : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiCoachMessageModel message;
  
  const _MessageBubble({
    Key? key,
    required this.message,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final isUser = message.isUserMessage;
    
    final bubble = GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: message.content));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message copied')),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isUser
              ? LinearGradient(
                  colors: [
                    AppColors.secondary,
                    AppColors.secondary.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser ? null : AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.neumorphicDark,
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: AppColors.neumorphicHighlight,
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
          ],
          border: isUser ? null : Border.all(color: AppColors.tertiary, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 16,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 10, color: (isUser ? Colors.white : AppColors.textSecondary).withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: (isUser ? Colors.white : AppColors.textSecondary).withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: isUser
            ? bubble
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage(AppAssets.questorDefault),
                  ),
                  const SizedBox(width: 8),
                  bubble,
                ],
              ),
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (today == messageDate) {
      // Today, show time only
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (today.subtract(const Duration(days: 1)) == messageDate) {
      // Yesterday
      return 'Yesterday, ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      // Other days
      return '${time.day}/${time.month}, ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _NewConversationDialog extends StatefulWidget {
  @override
  _NewConversationDialogState createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final TextEditingController _titleController = TextEditingController();
  
  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'New Conversation',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          hintText: 'Enter conversation title',
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          onPressed: () {
            Navigator.of(context).pop(_titleController.text.trim());
          },
          child: const Text(
            'Create',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _ConversationsListDialog extends StatelessWidget {
  final List<AiCoachConversationModel> conversations;
  
  const _ConversationsListDialog({
    Key? key,
    required this.conversations,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final sortedConversations = conversations
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    return AlertDialog(
      title: const Text(
        'Previous Conversations',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: sortedConversations.length,
          itemBuilder: (context, index) {
            final conversation = sortedConversations[index];
            return ListTile(
              title: Text(conversation.title),
              subtitle: Text(_formatDate(conversation.updatedAt)),
              onTap: () {
                Navigator.of(context).pop(conversation);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final conversationDate = DateTime(date.year, date.month, date.day);
    
    if (today == conversationDate) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (yesterday == conversationDate) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

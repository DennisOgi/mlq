import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _canSendMessage = true;

  @override
  void initState() {
    super.initState();
    // Initialize chat with user context when opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      debugPrint('AI Chat Screen initialized - User: ${userProvider.user?.name}, Authenticated: ${userProvider.isAuthenticated}');
      
      // Mark all messages as read
      chatProvider.markAllAsRead();
      
      // Initialize with user context for personalized responses
      chatProvider.initializeWithUser(userProvider);
      
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputFocus.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    debugPrint('_sendMessage called');
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    debugPrint('User: ${user?.name}, Coins: ${user?.coins}');
    if (user == null) {
      debugPrint('User is null, returning');
      // Show user-friendly message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait while we set up your account...',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }
    
    final message = _messageController.text.trim();
    debugPrint('Message: "$message"');
    if (message.isEmpty) {
      debugPrint('Message is empty, returning');
      return;
    }
    
    // Check if user has enough coins (0.2 coins per message)
    if (user.coins < 0.2) {
      debugPrint('Not enough coins: ${user.coins} < 0.2');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough coins! You need 0.2 coins to send a message.',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'Get Coins',
            textColor: Colors.white,
            onPressed: () {
              // Show coin shop dialog
              _showCoinShopDialog(context);
            },
          ),
        ),
      );
      return;
    }
    
    debugPrint('Spending 0.2 coins and sending message');
    // Spend 0.2 coins
    userProvider.spendCoins(0.2);
    
    // Add user message
    chatProvider.addUserMessage(user.id, message);
    _messageController.clear();
    debugPrint('Message sent and controller cleared');
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    
    // Set can't send message until response is received
    setState(() {
      _canSendMessage = false;
    });
    
    // Generate context-aware response from Questor
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
    final gratitudeProvider = Provider.of<GratitudeProvider>(context, listen: false);
    
    chatProvider.generateContextAwareQuestorResponse(
      userId: user.id,
      userMessage: message,
      userProvider: userProvider,
      goalProvider: goalProvider,
      challengeProvider: challengeProvider,
      gratitudeProvider: gratitudeProvider,
    ).then((_) {
      // Re-enable sending messages
      setState(() {
        _canSendMessage = true;
      });
      
      // Scroll to bottom again after response
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
  }

  static const _quickStarts = <({String emoji, String label, String prompt})>[
    (emoji: '🎯', label: 'Set a Goal', prompt: 'Help me set a goal for this week.'),
    (emoji: '🔥', label: 'Motivate Me', prompt: 'I need some motivation today.'),
    (
      emoji: '📘',
      label: "Explain Today's Lesson",
      prompt: "Explain today's mini course lesson in simple words."
    ),
    (
      emoji: '🧩',
      label: 'Solve a Problem',
      prompt: "Can you help me solve a problem I'm facing?"
    ),
    (emoji: '💪', label: 'Build Confidence', prompt: 'How can I build my confidence?'),
  ];

  final FocusNode _inputFocus = FocusNode();

  void _useQuickStart(String prompt) {
    _messageController.text = prompt;
    _messageController.selection =
        TextSelection.collapsed(offset: prompt.length);
    _inputFocus.requestFocus();
  }

  Future<void> _confirmNewChat(ChatProvider chatProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: const Text(
            'This will start a fresh conversation with Questor. Your current chat will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start New'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await chatProvider.startNewConversation();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final messages = chatProvider.messages;
    final isTyping = chatProvider.isTyping;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.plum,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondary.withOpacity(0.25),
              child: Image.asset(AppAssets.questorHappy, width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Questor',
                  style: AppTextStyles.heading3.copyWith(color: Colors.white),
                ),
                Text(
                  'Your leadership buddy',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => _confirmNewChat(chatProvider),
            tooltip: 'Start New Chat',
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on_rounded,
                    size: 16, color: AppColors.textOnGold),
                const SizedBox(width: 4),
                Text(
                  userProvider.user?.coins.toStringAsFixed(1) ?? '0.0',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textOnGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyChat()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(messages[index]);
                    },
                  ),
          ),
          if (messages.isNotEmpty) _buildQuickStartStrip(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _inputFocus,
                          decoration: InputDecoration(
                            hintText: 'Ask Questor anything…',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) {
                            if (_canSendMessage) _sendMessage();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: _canSendMessage
                            ? AppColors.primary
                            : AppColors.border,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white),
                          onPressed: _canSendMessage ? _sendMessage : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0.2 coins per message',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStartTile(({String emoji, String label, String prompt}) q,
      {double width = 128}) {
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _useQuickStart(q.prompt),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(q.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text(
                  q.label,
                  maxLines: 2,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStartStrip() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: _quickStarts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final q = _quickStarts[i];
          return ActionChip(
            onPressed: () => _useQuickStart(q.prompt),
            backgroundColor: AppColors.primarySoft,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            label: Text(
              '${q.emoji} ${q.label}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyChat() {
    final name =
        Provider.of<UserProvider>(context).user?.name.trim().split(' ').first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.plum, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi ${name == null || name.isEmpty ? 'there' : name}!',
                      style: AppTextStyles.heading2
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'I can help with your goals, lessons and tough days. Where shall we start?',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(AppAssets.questorHappy, height: 96)
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Quick starts', style: AppTextStyles.heading3),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickStarts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _quickStartTile(_quickStarts[i])
                .animate()
                .fadeIn(delay: (60 * i).ms, duration: 300.ms)
                .slideX(begin: 0.1, end: 0),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isFromUser = message.isFromUser;
    final name = Provider.of<UserProvider>(context).user?.name ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
              ),
              child: ClipOval(
                child: Image.asset(AppAssets.questorDefault, fit: BoxFit.cover),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isFromUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isFromUser ? 18 : 4),
                  bottomRight: Radius.circular(isFromUser ? 4 : 18),
                ),
                border: isFromUser ? null : Border.all(color: AppColors.border),
              ),
              child: Text(
                message.content,
                style: AppTextStyles.body.copyWith(
                  color: isFromUser ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isFromUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style:
                      AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Questor avatar
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                AppAssets.questorThinking,
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Typing indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scale(duration: 600.ms, begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0))
                  .then(duration: 600.ms),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scale(duration: 600.ms, begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), delay: 200.ms)
                  .then(duration: 600.ms),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scale(duration: 600.ms, begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), delay: 400.ms)
                  .then(duration: 600.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCoinShopDialog(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Mock coin packages
    final coinPackages = [
      {'coins': 100, 'price': '\$0.99', 'bonus': 0},
      {'coins': 250, 'price': '\$1.99', 'bonus': 25},
      {'coins': 500, 'price': '\$3.99', 'bonus': 75},
      {'coins': 1000, 'price': '\$6.99', 'bonus': 200},
    ];
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.monetization_on,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text('Coin Shop', style: AppTextStyles.heading3),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Balance: ${userProvider.user?.coins.toStringAsFixed(1) ?? '0.0'} coins',
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: 16),
                Text(
                  'Buy coins to chat with Questor and join premium challenges!',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 16),
                ...coinPackages.map((package) => _buildCoinPackage(
                  coins: package['coins'] as int,
                  price: package['price'] as String,
                  bonus: package['bonus'] as int,
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCoinPackage({
    required int coins,
    required String price,
    required int bonus,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Coin amount
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              coins.toString(),
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Package details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$coins Coins',
                  style: AppTextStyles.bodyBold,
                ),
                if (bonus > 0)
                  Text(
                    '+$bonus bonus coins',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          
          // Price and buy button
          QuestButton(
            text: price,
            type: QuestButtonType.primary,
            height: 36,
            onPressed: () {
              // In a real app, this would initiate a purchase
              // For now, just show a message
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Simulating purchase of $coins coins for $price',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                  backgroundColor: AppColors.secondary,
                ),
              );
              
              // Add coins to user's balance (simulated)
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              userProvider.addCoins(coins + bonus.toDouble());
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

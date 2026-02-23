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

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final messages = chatProvider.messages;
    final isTyping = chatProvider.isTyping;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondary.withOpacity(0.2),
              child: Image.asset(
                AppAssets.questorDefault,
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Questor',
              style: AppTextStyles.heading3.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        actions: [
          // New chat button
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Start New Chat'),
                  content: const Text('This will start a fresh conversation with Questor. Your current chat will be saved.'),
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
            },
            tooltip: 'Start New Chat',
          ),
          // Coin balance
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  size: 16,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                Text(
                  '${userProvider.user?.coins.toStringAsFixed(1) ?? '0.0'}',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Message explaining coin cost
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Each message costs 0.2 coins',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Chat messages
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyChat()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        // Typing indicator
                        return _buildTypingIndicator();
                      }
                      
                      final message = messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) {
                        if (_canSendMessage) {
                          _sendMessage();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: _canSendMessage ? AppColors.secondary : Colors.grey,
                    ),
                    onPressed: _canSendMessage ? () {
                      debugPrint('Send button pressed, _canSendMessage: $_canSendMessage');
                      _sendMessage();
                    } : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: Image.asset(
                  AppAssets.questorDefault,
                  fit: BoxFit.cover,
                ),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'Chat with Questor',
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'I can help you with your goals, give you advice, or just chat!',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            QuestButton(
              text: 'Start Chatting',
              type: QuestButtonType.primary,
              icon: Icons.chat,
              onPressed: () {
                // Focus the text field
                FocusScope.of(context).requestFocus(FocusNode());
                _messageController.text = 'Hi Questor!';
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isFromUser = message.isFromUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Questor avatar (only for Questor messages)
          if (!isFromUser)
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
                  AppAssets.questorDefault,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          
          // Message content
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isFromUser
                    ? LinearGradient(
                        colors: [
                          AppColors.secondary,
                          AppColors.accent2,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isFromUser ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
                border: isFromUser
                    ? null
                    : Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                        width: 1,
                      ),
              ),
              child: Text(
                message.content,
                style: AppTextStyles.body.copyWith(
                  color: isFromUser ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          
          // User avatar (only for user messages)
          if (isFromUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.2),
              ),
              child: Center(
                child: Text(
                  Provider.of<UserProvider>(context).user?.name.isNotEmpty == true
                      ? Provider.of<UserProvider>(context).user!.name[0].toUpperCase()
                      : 'U',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.primary,
                  ),
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

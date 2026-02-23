import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_leadership_quest/screens/ai_chat/ai_chat_screen.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/unified_autonomous_coach.dart';
import '../services/advanced_autonomous_coach.dart';
import '../theme/app_colors.dart';
import '../screens/ai_coach/ai_coach_screen.dart';

/// Advanced Floating Questor Widget with Emotional Intelligence and Predictive Coaching
class AdvancedFloatingQuestorWidget extends StatefulWidget {
  const AdvancedFloatingQuestorWidget({Key? key}) : super(key: key);

  @override
  State<AdvancedFloatingQuestorWidget> createState() => _AdvancedFloatingQuestorWidgetState();
}

class _AdvancedFloatingQuestorWidgetState extends State<AdvancedFloatingQuestorWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _expandController;
  late AnimationController _emotionalController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _expandAnimation;
  late Animation<Color?> _emotionalColorAnimation;
  
  StreamSubscription<dynamic>? _messageSubscription;
  AdvancedAutonomousMessage? _currentMessage;
  Timer? _messageDismissTimer;
  bool _isExpanded = false;
  bool _isShowingMessage = false;
  String _currentEmotionalTone = 'friendly';
  
  // Emotional color mapping
  final Map<String, Color> _emotionalColors = {
    'compassionate': Colors.purple.shade300,
    'celebratory': Colors.orange.shade400,
    'encouraging': AppColors.primary,
    'supportive': Colors.blue.shade400,
    'friendly': AppColors.primary,
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupAdvancedMessageListener();
  }

  void _initializeAnimations() {
    // Pulse animation for attention
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Expand animation for message display
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.elasticOut,
    );

    // Emotional color animation
    _emotionalController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _emotionalColorAnimation = ColorTween(
      begin: AppColors.primary,
      end: AppColors.primary,
    ).animate(_emotionalController);

    _pulseController.repeat(reverse: true);
  }

  void _setupAdvancedMessageListener() {
    // Listen to unified coach messages
    _messageSubscription = UnifiedAutonomousCoach.instance.unifiedMessageStream.listen((message) {
      if (!mounted) return;

      // Only show popups when this widget's route is the current route (i.e. user is on Home)
      final route = ModalRoute.of(context);
      if (route?.isCurrent != true) return;

      if (message is AdvancedAutonomousMessage) {
        _handleAdvancedMessage(message);
      }
    });
  }

  void _handleAdvancedMessage(AdvancedAutonomousMessage message) {
    setState(() {
      _currentMessage = message;
      _currentEmotionalTone = message.emotionalTone;
      _isShowingMessage = true;
    });

    // Update emotional color animation
    _updateEmotionalAnimation(message.emotionalTone);
    
    // Expand to show message
    _expandController.forward();
    
    // Auto-dismiss after 15 seconds (longer for advanced messages)
    _messageDismissTimer?.cancel();
    _messageDismissTimer = Timer(const Duration(seconds: 15), () {
      _dismissMessage();
    });

    // Trigger haptic feedback for important messages
    if (message.predictiveInsight?.priority == InsightPriority.urgent) {
      _triggerUrgentFeedback();
    }
  }

  void _updateEmotionalAnimation(String emotionalTone) {
    final targetColor = _emotionalColors[emotionalTone] ?? AppColors.primary;
    
    _emotionalColorAnimation = ColorTween(
      begin: _emotionalColorAnimation.value,
      end: targetColor,
    ).animate(_emotionalController);
    
    _emotionalController.forward();
  }

  void _triggerUrgentFeedback() {
    // Enhanced pulse for urgent messages
    _pulseController.stop();
    _pulseController.reset();
    
    // Rapid pulse sequence
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (mounted) {
          _pulseController.forward().then((_) => _pulseController.reverse());
        }
      });
    }
    
    // Resume normal pulse after urgent sequence
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  void _dismissMessage() {
    if (!mounted) return;
    
    _expandController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isShowingMessage = false;
          _currentMessage = null;
        });
      }
    });
    
    _messageDismissTimer?.cancel();
  }

  void _handleTap() {
    if (_isShowingMessage) {
      _dismissMessage();
    } else {
      // Navigate to full AI Chat experience when tapped
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AIChatScreen(),
        ),
      );
    }
  }

  void _handleLongPress() {
    // Navigate to full AI Coach screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AiCoachScreen(),
      ),
    );
  }

  Future<void> _triggerManualCoaching() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
      
      // Cache providers and trigger unified message
      UnifiedAutonomousCoach.instance.cacheProviders(
        userProvider: userProvider,
        goalProvider: goalProvider,
        challengeProvider: challengeProvider,
      );
      
      await UnifiedAutonomousCoach.instance.triggerUnifiedMessage(
        userProvider: userProvider,
        goalProvider: goalProvider,
        challengeProvider: challengeProvider,
      );
      
    } catch (e) {
      debugPrint('Error triggering manual coaching: $e');
      // Show fallback message if generation fails
      final fallbackMessage = AdvancedAutonomousMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: "Hi there! 👋 I'm here to help you on your leadership journey!",
        timestamp: DateTime.now(),
        type: 'Friendly Greeting',
        questorImage: 'assets/images/questor 3.png',
        emotionalTone: 'friendly',
        personalityState: {'enthusiasm': 7, 'wisdom': 'encouraging'},
      );
      _handleAdvancedMessage(fallbackMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 23,
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseAnimation,
            _expandAnimation,
            _emotionalColorAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: _buildAdvancedQuestorWidget(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdvancedQuestorWidget() {
    if (_isShowingMessage && _currentMessage != null) {
      return _buildExpandedMessageBubble();
    } else {
      return _buildFloatingQuestorBubble();
    }
  }

  Widget _buildFloatingQuestorBubble() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: _emotionalColorAnimation.value ?? AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (_emotionalColorAnimation.value ?? AppColors.primary).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          _getQuestorImageForCurrentState(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.psychology,
              color: Colors.white,
              size: 35,
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandedMessageBubble() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(
        maxWidth: 280,
        minWidth: 200,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: _emotionalColorAnimation.value ?? AppColors.primary,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message type indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_emotionalColorAnimation.value ?? AppColors.primary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getAdvancedMessageTypeLabel(_currentMessage!.type),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _emotionalColorAnimation.value ?? AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Message content
                  Text(
                    _currentMessage!.content,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  // Predictive insight indicator
                  if (_currentMessage!.predictiveInsight != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Predictive Insight',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Questor avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _emotionalColorAnimation.value ?? AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                _currentMessage!.questorImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 25,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getQuestorImageForCurrentState() {
    if (_currentMessage != null) {
      return _currentMessage!.questorImage;
    }
    
    // Default based on current emotional tone
    switch (_currentEmotionalTone) {
      case 'compassionate':
        return 'assets/images/questor 5.png'; // Compassionate Questor
      case 'celebratory':
        return 'assets/images/questor 4.png'; // Excited Questor
      case 'encouraging':
        return 'assets/images/questor 2.png'; // Happy Questor
      default:
        return 'assets/images/questor 3.png'; // Default Questor
    }
  }

  String _getAdvancedMessageTypeLabel(String type) {
    switch (type) {
      case 'Emotional Support':
        return '💜 Emotional Support';
      case 'Breakthrough Coaching':
        return '🚀 Breakthrough';
      case 'Goal Support':
        return '🎯 Goal Support';
      case 'Predictive Coaching':
        return '🔮 Predictive';
      case 'Morning Boost':
        return '🌅 Morning Boost';
      case 'Midday Check-in':
        return '☀️ Midday Check';
      case 'Evening Reflection':
        return '🌙 Evening';
      default:
        return '✨ Questor Says';
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _expandController.dispose();
    _emotionalController.dispose();
    _messageSubscription?.cancel();
    _messageDismissTimer?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/challenge_provider.dart';
import '../screens/ai_coach/ai_coach_screen.dart';
import '../services/autonomous_coach_service.dart';

class FloatingQuestorWidget extends StatefulWidget {
  const FloatingQuestorWidget({Key? key}) : super(key: key);

  @override
  State<FloatingQuestorWidget> createState() => _FloatingQuestorWidgetState();
}

class _FloatingQuestorWidgetState extends State<FloatingQuestorWidget>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late AnimationController _expandController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _expandAnimation;
  
  bool _isExpanded = false;
  AutonomousMessage? _currentMessage;
  Timer? _autoDismissTimer;
  StreamSubscription<AutonomousMessage>? _messageSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _expandAnimation = Tween<double>(
      begin: 60.0,
      end: 280.0,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
    ));
    
    // Start animations
    _startAnimations();
    _setupMessageListener();
  }
  
  void _startAnimations() {
    // Bounce animation every 5 seconds
    _bounceController.repeat(period: const Duration(seconds: 5));
    
    // Pulse animation every 3 seconds
    _pulseController.repeat(reverse: true, period: const Duration(seconds: 3));
  }
  
  void _setupMessageListener() {
    // Listen for autonomous messages
    _messageSubscription = AutonomousCoachService.instance.messageStream.listen((message) {
      if (message.type == 'trigger') {
        // Handle trigger message - generate actual coaching message
        _handleTriggerMessage();
      } else {
        // Show autonomous message
        _showAutonomousMessage(message);
      }
    });
  }
  
  void _handleTriggerMessage() async {
    // Get providers and trigger autonomous message generation
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
    
    await AutonomousCoachService.instance.triggerAutonomousMessage(
      userProvider: userProvider,
      goalProvider: goalProvider,
      challengeProvider: challengeProvider,
    );
  }
  
  void _showAutonomousMessage(AutonomousMessage message) {
    if (!mounted) return;
    
    setState(() {
      _currentMessage = message;
      _isExpanded = true;
    });
    
    // Start expand animation
    _expandController.forward();
    
    // Auto-dismiss after 12 seconds
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 12), () {
      _dismissMessage();
    });
  }
  
  void _dismissMessage() {
    if (!mounted) return;
    
    _expandController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isExpanded = false;
          _currentMessage = null;
        });
      }
    });
    
    _autoDismissTimer?.cancel();
  }
  
  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    _expandController.dispose();
    _autoDismissTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }
  
  void _onTap() {
    if (_isExpanded) {
      // If expanded, dismiss the message and go to chat
      _dismissMessage();
      Future.delayed(const Duration(milliseconds: 300), () {
        _navigateToAiCoach();
      });
    } else {
      // If collapsed, go directly to chat
      _navigateToAiCoach();
    }
  }
  
  void _navigateToAiCoach() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AiCoachScreen(),
      ),
    );
  }
  
  void _onLongPress() {
    // Trigger a test autonomous message
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
    
    AutonomousCoachService.instance.triggerAutonomousMessage(
      userProvider: userProvider,
      goalProvider: goalProvider,
      challengeProvider: challengeProvider,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: GestureDetector(
        onTap: _onTap,
        onLongPress: _onLongPress,
        child: AnimatedBuilder(
          animation: Listenable.merge([_bounceAnimation, _pulseAnimation]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -_bounceAnimation.value),
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: _buildQuestorBubble(),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildQuestorBubble() {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Container(
          width: _isExpanded ? _expandAnimation.value : 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isExpanded ? _buildExpandedContent() : _buildCollapsedContent(),
        );
      },
    );
  }
  
  Widget _buildCollapsedContent() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/questor3.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.smart_toy_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildExpandedContent() {
    if (_currentMessage == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Questor avatar with context-appropriate image
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Image.asset(
                _currentMessage!.questorImage,
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.smart_toy_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Message text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentMessage!.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getMessageTypeLabel(_currentMessage!.type),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Dismiss button
          GestureDetector(
            onTap: _dismissMessage,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getMessageTypeLabel(String type) {
    switch (type) {
      case 'Morning Boost':
        return 'Morning Boost';
      case 'Midday Check-in':
        return 'Midday Check-in';
      case 'Evening Reflection':
        return 'Evening Reflection';
      case 'General':
        return 'Questor Says';
      case 'trigger':
        return 'Coaching Time';
      default:
        return 'Questor Says';
    }
  }
}

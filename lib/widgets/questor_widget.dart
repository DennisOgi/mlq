import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../providers/providers.dart';
import '../screens/ai_chat/ai_chat_screen.dart';

enum QuestorMood { neutral, happy, thinking, excited, sad }

class QuestorWidget extends StatefulWidget {
  final String? message;
  final QuestorMood mood;
  final bool isFloating;
  final VoidCallback? onClose;

  const QuestorWidget({
    super.key,
    this.message,
    this.mood = QuestorMood.neutral,
    this.isFloating = true,
    this.onClose,
  });

  @override
  State<QuestorWidget> createState() => _QuestorWidgetState();
}

class _QuestorWidgetState extends State<QuestorWidget> {
  bool _isExpanded = false;
  bool _isDragging = false;
  Offset _position = const Offset(20, 100);

  String get _questorImage {
    switch (widget.mood) {
      case QuestorMood.happy:
        return AppAssets.questorHappy;
      case QuestorMood.thinking:
        return AppAssets.questorThinking;
      case QuestorMood.excited:
        return AppAssets.questorExcited;
      case QuestorMood.sad:
        return AppAssets.questorSad;
      case QuestorMood.neutral:
      default:
        return AppAssets.questorDefault;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final unreadCount = chatProvider.getUnreadCount();
    
    if (!widget.isFloating) {
      return _buildQuestorContent();
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        onTap: () {
          // Navigate to the AI Chat screen when Questor is tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AIChatScreen(),
            ),
          );
        },
        child: Stack(
          children: [
            // Questor bubble with message
            if (_isExpanded && widget.message != null)
              Positioned(
                right: 0,
                bottom: 60,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                    maxHeight: 200,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neumorphicDark,
                        offset: const Offset(4, 4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: AppColors.neumorphicHighlight,
                        offset: const Offset(-4, -4),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                    border: Border.all(color: AppColors.secondary, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message!,
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AIChatScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Chat with me',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 300.ms, curve: Curves.easeOut).slide(begin: const Offset(1.0, 0.0), end: const Offset(0.0, 0.0)),
              ),
            
            // Questor image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isDragging ? AppColors.primary.withOpacity(0.8) : AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(color: AppColors.secondary, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  _questorImage,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            // Unread messages indicator
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              
            // Close button when expanded
            if (_isExpanded && widget.onClose != null)
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestorContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: AppColors.secondary, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(
                _questorImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (widget.message != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questor',
                    style: AppTextStyles.bodyBold,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.message!,
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'quest_button.dart';

class ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final bool isParticipating;

  const ChallengeCard({
    super.key,
    required this.challenge,
    this.isParticipating = false,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final challengeProvider = Provider.of<ChallengeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    
    final isPremium = challenge.type == ChallengeType.premium;
    final cardColor = isPremium ? AppColors.accent1.withOpacity(0.08) : AppColors.surface;
    // Use blue for basic challenge header
    final accentColor = isPremium ? AppColors.accent1 : AppColors.academic;
    
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.pushNamed(
          context,
          '/challenge-detail',
          arguments: challenge.id,
        );
      },
      child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: AppTheme.getNeumorphicDecoration(
        color: cardColor,
        borderRadius: 20,
      ).copyWith(
        // Subtle gold border for premium to give a framed look
        border: isPremium
            ? Border.all(
                color: const Color(0xFFFFD54F), // soft gold
                width: 1.2,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with premium/basic badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // Gold gradient header for premium
              color: isPremium ? null : accentColor,
              gradient: isPremium
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPremium ? Icons.star : Icons.emoji_events,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isPremium ? 'Premium Challenge' : 'Basic Challenge',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    children: [
                      // Removed "Completed" tag - completion status now shown on button
                      if (isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.32),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Cost: ${challenge.coinsCost}',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              challenge.participantsCount.toString(),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Challenge content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: AppTextStyles.heading3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  challenge.description,
                  style: AppTextStyles.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                
                // Rewards section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rewards:',
                        style: AppTextStyles.bodyBold,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${challenge.coinReward} coins',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                      if (isPremium && challenge.realWorldPrize != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.card_giftcard,
                                color: AppColors.accent1,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                challenge.realWorldPrize!,
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Date range
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getDateRangeText(),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      // Show days remaining for challenges ending soon
                      if (challenge.daysRemaining <= 7 && challenge.daysRemaining > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: challenge.daysRemaining <= 3 
                                ? Colors.orange.withOpacity(0.1) 
                                : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: challenge.daysRemaining <= 3 
                                  ? Colors.orange.withOpacity(0.3) 
                                  : AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${challenge.daysRemaining} days left',
                            style: AppTextStyles.caption.copyWith(
                              color: challenge.daysRemaining <= 3 ? Colors.orange : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Join/Leave button
                if (isPremium)
                  QuestButton(
                    text: 'View Details',
                    type: QuestButtonType.secondary,
                    isFullWidth: true,
                    onPressed: () {
                      final isJoined = challengeProvider.isParticipatingIn(challenge.id);
                      if (!isJoined) {
                        Navigator.pushNamed(context, '/premium-unlock', arguments: challenge.id);
                      } else {
                        Navigator.pushNamed(context, '/challenge-detail', arguments: challenge.id);
                      }
                    },
                  )
                else
                  Builder(
                    builder: (context) {
                      final isCompleted = challengeProvider.isCompleted(challenge.id);
                      String buttonText;
                      QuestButtonType buttonType;
                      
                      if (isCompleted) {
                        buttonText = 'Completed';
                        buttonType = QuestButtonType.success;
                      } else if (isParticipating) {
                        buttonText = 'Go to Challenge';
                        buttonType = QuestButtonType.secondary;
                      } else {
                        buttonText = 'View Details';
                        buttonType = QuestButtonType.primary;
                      }
                      
                      return QuestButton(
                        text: buttonText,
                        type: buttonType,
                        isFullWidth: true,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/challenge-detail',
                            arguments: challenge.id,
                          );
                        },
                        isLoading: false,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  String _getDateRangeText() {
    final startDate = challenge.startDate;
    final endDate = challenge.endDate;
    
    final startMonth = startDate.month;
    final startDay = startDate.day;
    final endMonth = endDate.month;
    final endDay = endDate.day;
    
    if (startDate.year == endDate.year) {
      if (startMonth == endMonth) {
        return 'From $startMonth/$startDay to $endMonth/$endDay';
      } else {
        return 'From $startMonth/$startDay to $endMonth/$endDay';
      }
    } else {
      return 'From ${startDate.year}/$startMonth/$startDay to ${endDate.year}/$endMonth/$endDay';
    }
  }
}

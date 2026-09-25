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

    final isPremium = challenge.type == ChallengeType.premium;
    final cardColor =
        isPremium ? AppColors.accent1.withOpacity(0.08) : AppColors.surface;
    final accentColor = isPremium ? AppColors.accent1 : AppColors.academic;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasTightHeight =
            constraints.hasBoundedHeight && constraints.maxHeight < 520;

        return GestureDetector(
          onTap: onTap ??
              () {
                Navigator.pushNamed(
                  context,
                  '/challenge-detail',
                  arguments: challenge.id,
                );
              },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: hasTightHeight ? 0 : 8),
            decoration: AppTheme.getNeumorphicDecoration(
              color: cardColor,
              borderRadius: 20,
            ).copyWith(
              border: isPremium
                  ? Border.all(
                      color: const Color(0xFFFFD54F),
                      width: 1.2,
                    )
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isPremium, accentColor),
                if (hasTightHeight)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: _buildBody(
                        context,
                        challengeProvider,
                        isPremium,
                        compact: true,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: _buildBody(
                      context,
                      challengeProvider,
                      isPremium,
                      compact: false,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHeader(bool isPremium, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
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
        children: [
          Icon(
            isPremium ? Icons.star : Icons.emoji_events,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isPremium ? 'Premium Challenge' : 'Basic Challenge',
              style: AppTextStyles.bodyBold.copyWith(
                color: Colors.white,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPremium) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.32),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge.coinsCost}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white, size: 14),
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
    );
  }

  Widget _buildBody(
    BuildContext context,
    ChallengeProvider challengeProvider,
    bool isPremium, {
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          challenge.title,
          style: AppTextStyles.heading3.copyWith(fontSize: compact ? 16 : null),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          challenge.description,
          style: AppTextStyles.body.copyWith(fontSize: compact ? 13 : null),
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: compact ? 8 : 16),
        Container(
          padding: EdgeInsets.all(compact ? 8 : 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.monetization_on,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${challenge.coinReward} coins'
                  '${isPremium && challenge.realWorldPrize != null ? ' · ${challenge.realWorldPrize}' : ''}',
                  style: AppTextStyles.body.copyWith(fontSize: compact ? 13 : null),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getDateRangeText(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (challenge.daysRemaining <= 7 && challenge.daysRemaining > 0)
                Text(
                  '${challenge.daysRemaining}d left',
                  style: AppTextStyles.caption.copyWith(
                    color: challenge.daysRemaining <= 3
                        ? Colors.orange
                        : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        if (compact) const Spacer(),
        _buildActionButton(context, challengeProvider, isPremium),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    ChallengeProvider challengeProvider,
    bool isPremium,
  ) {
    if (isPremium) {
      return QuestButton(
        text: 'View Details',
        type: QuestButtonType.secondary,
        isFullWidth: true,
        onPressed: () {
          final isJoined =
              challengeProvider.isParticipatingIn(challenge.id);
          if (!isJoined) {
            Navigator.pushNamed(context, '/premium-unlock',
                arguments: challenge.id);
          } else {
            Navigator.pushNamed(context, '/challenge-detail',
                arguments: challenge.id);
          }
        },
      );
    }

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
  }

  String _getDateRangeText() {
    final startDate = challenge.startDate;
    final endDate = challenge.endDate;

    final startMonth = startDate.month;
    final startDay = startDate.day;
    final endMonth = endDate.month;
    final endDay = endDate.day;

    if (startDate.year == endDate.year) {
      return 'From $startMonth/$startDay to $endMonth/$endDay';
    }
    return 'From ${startDate.year}/$startMonth/$startDay to ${endDate.year}/$endMonth/$endDay';
  }
}

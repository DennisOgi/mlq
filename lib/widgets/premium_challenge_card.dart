import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_leadership_quest/models/challenge_model.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class PremiumChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final bool isUnlocked;
  final bool showSponsorRegistration;
  final VoidCallback? onTap;

  const PremiumChallengeCard({
    Key? key,
    required this.challenge,
    this.isUnlocked = false,
    this.showSponsorRegistration = false,
    this.onTap,
  }) : super(key: key);

  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  String _getPrizeOrRewardText() {
    final prize = (challenge.realWorldPrize ?? '').trim();
    if (prize.isNotEmpty) return prize;

    final parts = <String>[];
    if (challenge.coinReward > 0) parts.add('${challenge.coinReward} coins');
    if (challenge.xpReward > 0) parts.add('${challenge.xpReward} XP');
    if (parts.isEmpty) return '';
    return 'Rewards: ${parts.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: AppTheme.getNeumorphicDecoration(
        borderRadius: 16,
      ).copyWith(
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Organization header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Light gold-tinted header
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    challenge.organizationLogo,
                    height: 40,
                    width: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      challenge.organizationName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (challenge.isTeamChallenge)
                    Chip(
                      label: const Text('Team'),
                      backgroundColor: Colors.blue[100],
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    challenge.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Timeline
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          challenge.timeline,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prize
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.card_giftcard,
                            color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getPrizeOrRewardText(),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Criteria label and Join Cost chip in same row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Evaluation Criteria:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isUnlocked ? Colors.green[100] : Colors.amber[100],
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (isUnlocked ? Colors.green : Colors.amber)
                                  .withOpacity(0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUnlocked
                                  ? Icons.check_circle
                                  : Icons.monetization_on,
                              size: 20,
                              color: isUnlocked ? Colors.green : Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isUnlocked
                                  ? 'Joined'
                                  : 'Cost: ${challenge.coinsCost}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: challenge.criteria.map((criterion) {
                      return Chip(
                        label: Text(
                          criterion,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.grey[200],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Sponsor Link Section
                  if (showSponsorRegistration &&
                      challenge.externalJoinUrl != null &&
                      challenge.externalJoinUrl!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.link,
                                  color: Colors.purple[700], size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Sponsor Registration',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Access the sponsor portal to register and submit your challenge entry.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  challenge.externalJoinUrl!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[600],
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _launchURL(challenge.externalJoinUrl!),
                                icon: const Icon(Icons.open_in_new, size: 14),
                                label: const Text(
                                  'Open Portal',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Join Challenge button (premium gated elsewhere)
                  if (!isUnlocked)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.emoji_events_rounded),
                        label: const Text(
                          'Join Challenge',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

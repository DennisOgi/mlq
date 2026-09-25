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
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight =
            constraints.hasBoundedHeight && constraints.maxHeight < 520;

        return Container(
          margin: EdgeInsets.symmetric(
            vertical: tight ? 0 : 8,
            horizontal: tight ? 0 : 16,
          ),
          decoration: AppTheme.getNeumorphicDecoration(
            borderRadius: 16,
          ).copyWith(
            border: Border.all(color: const Color(0xFFFFD54F), width: 1.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: tight ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (tight)
                  Expanded(child: SingleChildScrollView(child: _buildBody(tight: true)))
                else
                  _buildBody(tight: false),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            challenge.organizationLogo,
            height: 36,
            width: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              challenge.organizationName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (challenge.isTeamChallenge)
            Chip(
              label: const Text('Team', style: TextStyle(fontSize: 11)),
              backgroundColor: Colors.blue[100],
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }

  Widget _buildBody({required bool tight}) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            challenge.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            challenge.description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            maxLines: tight ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.timer, color: Colors.blue[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    challenge.timeline,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[800],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.green[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getPrizeOrRewardText(),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.green[800],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUnlocked ? Colors.green[100] : Colors.amber[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    isUnlocked ? 'Joined' : 'Cost: ${challenge.coinsCost}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!tight) ...[
            const SizedBox(height: 10),
            Text(
              'Evaluation Criteria:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: challenge.criteria.map((criterion) {
                return Chip(
                  label: Text(criterion, style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.grey[200],
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
          if (showSponsorRegistration &&
              challenge.externalJoinUrl != null &&
              challenge.externalJoinUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchURL(challenge.externalJoinUrl!),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Open Sponsor Portal'),
              ),
            ),
          ],
          if (!isUnlocked) ...[
            const SizedBox(height: 10),
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
                ),
                icon: const Icon(Icons.emoji_events_rounded),
                label: const Text(
                  'Join Challenge',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

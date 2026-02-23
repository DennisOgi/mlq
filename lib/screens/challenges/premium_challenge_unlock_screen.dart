import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_leadership_quest/providers/providers.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/widgets/quest_button.dart';

class PremiumChallengeUnlockScreen extends StatefulWidget {
  final String challengeId;
  const PremiumChallengeUnlockScreen({super.key, required this.challengeId});

  @override
  State<PremiumChallengeUnlockScreen> createState() => _PremiumChallengeUnlockScreenState();
}

class _PremiumChallengeUnlockScreenState extends State<PremiumChallengeUnlockScreen>
    with SingleTickerProviderStateMixin {
  bool _isUnlocking = false;
  bool _isSuccess = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final challengeProvider = Provider.of<ChallengeProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final challenge = challengeProvider.getChallengeById(widget.challengeId);
    if (challenge == null) {
      _showSnack('Challenge not found');
      return;
    }

    final cost = challenge.coinsCost.toDouble();
    final balance = userProvider.user?.coins ?? 0.0;
    if (balance < cost) {
      _showSnack('Not enough coins. You need ${(cost - balance).toStringAsFixed(0)} more.');
      return;
    }

    setState(() => _isUnlocking = true);
    final result = await challengeProvider.unlockPremium(
      widget.challengeId,
      coinCost: cost,
      userProvider: userProvider,
    );

    if (!mounted) return;

    if (result.success) {
      if (result.redirectUrl != null) {
        // Handle redirect if needed (though usually we just unlock)
        // For now, treat as success and let detail screen handle access link
      }
      
      setState(() => _isSuccess = true);
      _controller.forward();
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/challenge-detail',
        arguments: widget.challengeId,
      );
    } else {
      _showErrorDialog(result.errorMessage ?? 'Failed to unlock challenge');
    }

    if (mounted) setState(() => _isUnlocking = false);
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock Failed'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChallengeProvider, UserProvider>(
      builder: (context, challengeProvider, userProvider, _) {
        final challenge = challengeProvider.getChallengeById(widget.challengeId);
        if (challenge == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Unlock')),
            body: const Center(child: Text('Challenge not found')),
          );
        }
        final cost = challenge.coinsCost.toDouble();
        final balance = userProvider.user?.coins ?? 0.0;
        final hasEnough = balance >= cost;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Unlock Premium Challenge'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  challenge.title,
                  style: AppTextStyles.heading2.copyWith(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  challenge.description,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Coin card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: const Icon(Icons.stars_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unlock cost', style: AppTextStyles.bodyBold),
                            Text('$cost coins', style: AppTextStyles.body.copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Your balance', style: AppTextStyles.caption),
                          Text(balance.toStringAsFixed(0), style: AppTextStyles.bodyBold),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Unlock animation / feedback
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isSuccess
                          ? ScaleTransition(
                              scale: _scaleAnim,
                              child: const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 96),
                            )
                          : _isUnlocking
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: AppColors.primary),
                                    SizedBox(height: 12),
                                    Text('Unlocking...'),
                                  ],
                                )
                              : const Icon(Icons.lock_rounded, color: AppColors.primary, size: 96),
                    ),
                  ),
                ),

                // Buttons
                if (!hasEnough)
                  QuestButton(
                    text: 'Earn More Coins',
                    type: QuestButtonType.secondary,
                    isFullWidth: true,
                    onPressed: () {
                      _showSnack('Complete goals to earn more coins!');
                      Navigator.pop(context);
                    },
                  )
                else
                  QuestButton(
                    text: _isUnlocking ? 'Unlocking...' : 'Unlock for $cost coins',
                    type: QuestButtonType.primary,
                    isFullWidth: true,
                    isLoading: _isUnlocking,
                    onPressed: _isUnlocking ? null : _unlock,
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isUnlocking ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

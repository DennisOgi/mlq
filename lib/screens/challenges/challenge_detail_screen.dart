import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailScreen({
    super.key,
    required this.challengeId,
  });

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

// Renders progress for structured basic challenge rules
class _RulesProgress extends StatelessWidget {
  final ChallengeModel challenge;
  const _RulesProgress({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final gratitudeProvider =
        Provider.of<GratitudeProvider>(context, listen: false);
    final miniCourseProvider =
        Provider.of<MiniCourseProvider>(context, listen: false);

    return FutureBuilder<Map<String, dynamic>>(
      future: (() async {
        final userId = client.auth.currentUser?.id;
        // Fetch rules from database
        final rulesResponse = await client
            .from('challenge_rules')
            .select('*')
            .eq('challenge_id', challenge.id)
            .order('created_at');
        final rules = List<Map<String, dynamic>>.from(rulesResponse as List);
        
        // Fetch server-side progress if user is logged in
        int? serverProgress;
        DateTime? joinedAt;
        if (userId != null) {
          final progressResponse = await client
              .from('user_challenges')
              .select('progress, start_date')
              .eq('challenge_id', challenge.id)
              .eq('user_id', userId)
              .maybeSingle();
          serverProgress = progressResponse?['progress'] as int?;
          if (progressResponse?['start_date'] != null) {
            joinedAt = DateTime.tryParse(progressResponse!['start_date']);
          }
        }
        
        return {
          'rules': rules,
          'serverProgress': serverProgress,
          'joinedAt': joinedAt,
        };
      })(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: SizedBox(
                  height: 32, width: 32, child: CircularProgressIndicator()));
        }
        final data = snapshot.data;
        final rules = (data?['rules'] as List<Map<String, dynamic>>?) ?? const [];
        final serverProgress = data?['serverProgress'] as int?;
        final joinedAt = data?['joinedAt'] as DateTime?;
        
        if (rules.isEmpty) {
          return Text(
            'No structured rules defined for this challenge.',
            style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          );
        }

        final now = DateTime.now();
        final windowStartFixed = challenge.startDate;
        final windowEndFixed = challenge.endDate;
        
        // For single-rule challenges, use server progress if available
        final useSingleRuleServerProgress = rules.length == 1 && serverProgress != null;

        List<Widget> rows = [];
        for (final r in rules) {
          final ruleType = (r['rule_type'] as String?) ?? '';
          final target = (r['target_value'] as int?) ?? 1;
          final consecutive = (r['consecutive_required'] as bool?) ?? false;
          final windowType = (r['window_type'] as String?) ?? 'fixed_window';
          final windowDays = (r['window_value_days'] as int?) ?? 7;
          DateTime start;
          DateTime end;

          switch (windowType) {
            case 'rolling_days':
              start = DateTime(now.year, now.month, now.day)
                  .subtract(Duration(days: windowDays - 1));
              end = DateTime(now.year, now.month, now.day, 23, 59, 59);
              break;
            case 'per_user_enrollment':
              // Use actual join date if available, otherwise fallback to challenge start
              start = joinedAt ?? windowStartFixed;
              
              // Extend window to NOW if challenge end date has passed (matching server logic)
              final nowDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
              end = windowEndFixed.isAfter(nowDate) ? windowEndFixed : nowDate;
              break;
            case 'fixed_window':
            default:
              start = windowStartFixed;
              end = windowEndFixed;
          }

          // For single-rule challenges, prefer server progress for consistency
          int current;
          if (useSingleRuleServerProgress) {
            current = serverProgress!;
          } else if (ruleType == 'gratitude_count_in_window') {
            // For gratitude count, fetch from server (handled via nested FutureBuilder)
            rows.add(FutureBuilder<int>(
              future: _fetchGratitudeCountFromServer(context, start, end),
              builder: (context, snap) {
                int countCurrent;
                if (snap.connectionState == ConnectionState.waiting) {
                  countCurrent = _gratitudeCount(gratitudeProvider, start, end);
                } else if (snap.hasError) {
                  countCurrent = _gratitudeCount(gratitudeProvider, start, end);
                } else {
                  countCurrent = snap.data ?? _gratitudeCount(gratitudeProvider, start, end);
                }
                final capped = countCurrent.clamp(0, target);
                return _RuleProgressRow(
                  label: _formatRuleLabel(ruleType),
                  current: capped,
                  target: target,
                );
              },
            ));
            continue; // Skip the rest of the loop for this rule
          } else if (ruleType == 'gratitude_streak_days') {
            current = _gratitudeStreak(gratitudeProvider, start, end);
          } else if (ruleType == 'daily_goal_streak_days') {
            current = _dailyGoalStreak(goalProvider, start, end,
                consecutive: consecutive);
          } else if (ruleType == 'main_goals_completed') {
            current = _goalsCompleted(goalProvider, start, end, scope: 'main');
          } else if (ruleType == 'any_goals_completed') {
            current = _goalsCompleted(goalProvider, start, end, scope: 'any');
          } else if (ruleType == 'mini_courses_completed') {
            current = _miniCoursesCompleted(miniCourseProvider, start, end);
          } else if (ruleType == 'daily_goal_count_in_window') {
            current = _goalsCompleted(goalProvider, start, end, scope: 'daily');
          } else if (ruleType == 'main_goal_count_in_window') {
            current = _goalsCompleted(goalProvider, start, end, scope: 'main');
          } else {
            current = 0;
          }

          final capped = current.clamp(0, target);
          rows.add(_RuleProgressRow(
            label: _formatRuleLabel(ruleType),
            current: capped,
            target: target,
          ));
        }

        return Column(children: rows);
      },
    );
  }

  Future<int> _fetchGratitudeCountFromServer(
      BuildContext context, DateTime start, DateTime end) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return 0;
      final startIso =
          DateTime.utc(start.year, start.month, start.day).toIso8601String();
      final endIso = DateTime.utc(end.year, end.month, end.day, 23, 59, 59)
          .toIso8601String();
      final rows = await client
          .from('gratitude_entries')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', startIso)
          .lte('created_at', endIso);
      return (rows as List).length;
    } catch (_) {
      return _gratitudeCount(
          Provider.of<GratitudeProvider>(context, listen: false), start, end);
    }
  }

  int _gratitudeStreak(
      GratitudeProvider provider, DateTime start, DateTime end) {
    final entries = provider.entries;
    if (entries.isEmpty) return 0;
    final dates = <DateTime>{};
    for (final e in entries) {
      final dt = e.date;
      if (dt.isBefore(start) || dt.isAfter(end)) continue;
      dates.add(DateTime(dt.year, dt.month, dt.day));
    }
    int streak = 0;
    DateTime cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    if (cursor.isAfter(end)) cursor = DateTime(end.year, end.month, end.day);
    while (!cursor.isBefore(start)) {
      if (dates.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int _gratitudeCount(
      GratitudeProvider provider, DateTime start, DateTime end) {
    int count = 0;
    for (final e in provider.entries) {
      final dt = e.date;
      if (!dt.isBefore(start) && !dt.isAfter(end)) count++;
    }
    return count;
  }

  int _dailyGoalStreak(GoalProvider provider, DateTime start, DateTime end,
      {required bool consecutive}) {
    final dailyGoals = provider.dailyGoals;
    final completedDates = <DateTime>{};
    for (final g in dailyGoals) {
      if (g.isCompleted == true) {
        final dt = g.date; // Use daily goal date as completion proxy
        if (!dt.isBefore(start) && !dt.isAfter(end)) {
          completedDates.add(DateTime(dt.year, dt.month, dt.day));
        }
      }
    }
    int streak = 0;
    DateTime cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    if (cursor.isAfter(end)) cursor = DateTime(end.year, end.month, end.day);
    while (!cursor.isBefore(start)) {
      if (completedDates.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int _goalsCompleted(GoalProvider provider, DateTime start, DateTime end,
      {required String scope}) {
    int count = 0;
    if (scope == 'daily' || scope == 'any') {
      for (final g in provider.dailyGoals) {
        if (g.isCompleted == true) {
          final dt = g.date; // Use daily goal date as completion proxy
          if (!dt.isBefore(start) && !dt.isAfter(end)) count++;
        }
      }
    }
    if (scope == 'main' || scope == 'any') {
      for (final g in provider.mainGoals) {
        if (g.isCompleted == true) {
          // MainGoalModel may not expose a completion date; fall back to now for UI-only progress
          final dt = DateTime.now();
          if (!dt.isBefore(start) && !dt.isAfter(end)) count++;
        }
      }
    }
    return count;
  }

  int _miniCoursesCompleted(
      MiniCourseProvider provider, DateTime start, DateTime end) {
    int count = 0;

    // Check today's courses first (most recent completions)
    for (final c in provider.todayCourses) {
      if (c.quiz.isCompleted && c.quiz.score != null && c.quiz.score! >= 70) {
        final dt = c.completedAt ?? DateTime.now();
        if (!dt.isBefore(start) && !dt.isAfter(end)) count++;
      }
    }

    // Also check regular courses list
    for (final c in provider.courses) {
      if (c.status.toString().toLowerCase().contains('completed')) {
        final dt = c.completedAt ?? DateTime.now();
        if (!dt.isBefore(start) && !dt.isAfter(end)) count++;
      }
    }

    return count;
  }
  
  // Format rule type into human-readable label
  String _formatRuleLabel(String ruleType) {
    const labelMap = {
      'daily_goal_streak_days': 'Daily Goal Streak',
      'gratitude_streak_days': 'Gratitude Streak',
      'gratitude_count_in_window': 'Gratitude Entries',
      'main_goals_completed': 'Main Goals Completed',
      'any_goals_completed': 'Goals Completed',
      'mini_courses_completed': 'Mini-Courses Completed',
      'daily_goal_count_in_window': 'Daily Goals Completed',
      'main_goal_count_in_window': 'Main Goals Completed',
    };
    return labelMap[ruleType] ?? ruleType.replaceAll('_', ' ');
  }
}

class _RuleProgressRow extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  const _RuleProgressRow(
      {required this.label, required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? current / target : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${label[0].toUpperCase()}${label.substring(1)}',
                  style: AppTextStyles.bodyBold,
                ),
              ),
              Text('$current / $target', style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.black12,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  bool _isUnlocking = false;
  bool _isOpeningLink = false;

  Future<void> _openPremiumAccessLink(
      ChallengeProvider challengeProvider) async {
    setState(() => _isOpeningLink = true);
    try {
      final redirectUrl =
          await challengeProvider.getPremiumAccessLink(widget.challengeId);
      if (redirectUrl != null) {
        final trimmed = redirectUrl.trim();
        if (trimmed.isEmpty) {
          _showErrorSnackBar('Could not open link');
          return;
        }

        final uri = Uri.tryParse(trimmed);
        if (uri == null || !uri.hasScheme) {
          _showErrorSnackBar('Invalid link');
          return;
        }

        // Some Android versions (11+) can return false here unless manifest <queries> includes VIEW intents.
        // We'll still try launchUrl even when canLaunchUrl returns false.
        final canLaunch = await canLaunchUrl(uri);
        if (!canLaunch) {
          debugPrint('[ChallengeDetail] canLaunchUrl returned false for: $uri');
        }

        final launchedInApp = await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );

        if (launchedInApp) {
          return;
        }

        debugPrint(
            '[ChallengeDetail] In-app webview launch failed, retrying external: $uri');

        final launchedExternal = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launchedExternal) {
          _showErrorSnackBar('Could not open link');
        }
      } else if (challengeProvider.hasError) {
        _showErrorSnackBar(challengeProvider.errorMessage);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open challenge: $e');
    } finally {
      setState(() => _isOpeningLink = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChallengeProvider, UserProvider>(
      builder: (context, challengeProvider, userProvider, child) {
        final challenge =
            challengeProvider.getChallengeById(widget.challengeId);

        if (challenge == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Challenge Not Found')),
            body: const Center(
              child: Text('Challenge not found'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(challenge.title),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium hero banner
                if (challenge.type == ChallengeType.premium)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7D774), Color(0xFFE8C547)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x33A68A00),
                            blurRadius: 12,
                            offset: Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.workspace_premium_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text('Premium Challenge',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _SponsorLogo(logoPath: challenge.organizationLogo),
                      ],
                    ),
                  ),
                if (challenge.type == ChallengeType.premium)
                  const SizedBox(height: 16),
                // Challenge Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.getNeumorphicDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: challenge.type == ChallengeType.premium
                                  ? AppColors.warning
                                  : AppColors.secondary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              challenge.type == ChallengeType.premium
                                  ? 'PREMIUM'
                                  : 'BASIC',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (challenge.type == ChallengeType.premium)
                            Row(
                              children: [
                                Icon(Icons.monetization_on,
                                    color: AppColors.warning, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'Cost: ${challenge.coinsCost} coins',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        challenge.title,
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        challenge.description,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Organization Info (for premium)
                if (challenge.type == ChallengeType.premium) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.getNeumorphicDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sponsored by',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _SponsorLogo(
                                logoPath: challenge.organizationLogo, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                challenge.organizationName,
                                style: AppTextStyles.heading3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Challenge Details
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.getNeumorphicDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Challenge Details',
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Duration', challenge.timeline),
                      _buildDetailRow('Participants',
                          '${challenge.participantsCount} ${challenge.participantsCount == 1 ? "participant" : "participants"}'),
                      if (challenge.realWorldPrize != null)
                        _buildDetailRow('Prize', challenge.realWorldPrize!),
                      if (challenge.type == ChallengeType.basic)
                        _buildDetailRow(
                            'Reward', '${challenge.coinReward} coins'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Progress (for basic challenges if participating)
                if (challenge.type == ChallengeType.basic &&
                    challengeProvider
                        .isParticipatingIn(widget.challengeId)) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.getNeumorphicDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Progress',
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: 12),
                        _RulesProgress(challenge: challenge),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                      challenge, challengeProvider, userProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    ChallengeModel challenge,
    ChallengeProvider challengeProvider,
    UserProvider userProvider,
  ) {
    final isParticipating =
        challengeProvider.isParticipatingIn(widget.challengeId);
    final isLoading =
        challengeProvider.isLoading || _isUnlocking || _isOpeningLink;

    if (challenge.type == ChallengeType.premium) {
      if (isParticipating) {
        return QuestButton(
          text: _isOpeningLink ? 'Opening…' : 'Go to Challenge',
          onPressed: isLoading
              ? null
              : () => _openPremiumAccessLink(challengeProvider),
          type: QuestButtonType.success,
          isLoading: _isOpeningLink,
        );
      }

      return QuestButton(
        text: 'Unlock & Join (${challenge.coinsCost} coins)',
        onPressed: isLoading
            ? null
            : () => Navigator.pushNamed(
                  context,
                  '/premium-unlock',
                  arguments: widget.challengeId,
                ),
        type: QuestButtonType.secondary,
        isLoading: false,
      );
    } else {
      // Basic challenge
      final isCompleted =
          challengeProvider.isCompleted(widget.challengeId);

      if (isCompleted) {
        return QuestButton(
          text: 'Completed',
          onPressed: null,
          type: QuestButtonType.success,
          isLoading: false,
        );
      } else if (isParticipating) {
        return QuestButton(
          text: 'Leave Challenge',
          onPressed:
              isLoading ? null : () => _leaveChallenge(challengeProvider),
          type: QuestButtonType.outline,
        );
      } else {
        return QuestButton(
          text: isLoading ? 'Joining...' : 'Join Challenge',
          onPressed: isLoading
              ? null
              : () => _joinBasicChallenge(challengeProvider, userProvider),
          type: QuestButtonType.primary,
          isLoading: isLoading,
        );
      }
    }
  }

  Future<void> _unlockPremiumChallenge(
    ChallengeModel challenge,
    ChallengeProvider challengeProvider,
    UserProvider userProvider,
  ) async {
    setState(() => _isUnlocking = true);

    try {
      final result = await challengeProvider.unlockPremium(
        widget.challengeId,
        coinCost: challenge.coinsCost.toDouble(),
        userProvider: userProvider,
      );

      if (result.success) {
        if (result.redirectUrl != null) {
          // Open in in-app browser
          final uri = Uri.parse(result.redirectUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.inAppWebView,
              webViewConfiguration: const WebViewConfiguration(
                enableJavaScript: true,
                enableDomStorage: true,
              ),
            );
          }
        } else {
          _showSuccessSnackBar('Challenge unlocked successfully!');
          // Force UI refresh if needed, though provider should handle it
        }
      } else {
        // Show error from result
        _showErrorSnackBar(result.errorMessage ?? 'Failed to unlock challenge');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to unlock challenge: $e');
    } finally {
      setState(() => _isUnlocking = false);
    }
  }

  Future<void> _joinBasicChallenge(
    ChallengeProvider challengeProvider,
    UserProvider userProvider,
  ) async {
    // Guard: require at least one main goal to participate in basic challenges
    try {
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      if ((goalProvider.mainGoals).isEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Create a Main Goal'),
            content: const Text(
                'To join this challenge, please create your first Main Goal.\n\n'
                'Main Goals help us track your progress accurately.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create Now'),
              ),
            ],
          ),
        );
        if (proceed == true) {
          if (!mounted) return;
          Navigator.pushNamed(context, '/goals');
        }
        return;
      }
    } catch (_) {}

    final success = await challengeProvider.joinBasic(
      widget.challengeId,
      userProvider: userProvider,
    );

    if (success) {
      _showSuccessSnackBar('Successfully joined challenge!');
    } else if (challengeProvider.hasError) {
      _showErrorSnackBar(challengeProvider.errorMessage);
    }
  }

  Future<void> _leaveChallenge(ChallengeProvider challengeProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Challenge'),
        content: const Text('Are you sure you want to leave this challenge?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await challengeProvider.leaveChallenge(widget.challengeId);
      _showSuccessSnackBar('Left challenge successfully');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Premium sponsor logo chip used in the banner and sponsor section
class _SponsorLogo extends StatelessWidget {
  final String logoPath;
  final double size;
  const _SponsorLogo({required this.logoPath, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 12,
      height: size + 12,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          logoPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, _, __) => Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.primary,
              size: size),
        ),
      ),
    );
  }
}

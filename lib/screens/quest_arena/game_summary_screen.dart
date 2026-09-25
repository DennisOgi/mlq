import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:my_leadership_quest/theme/app_theme.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/quest_arena_service.dart';
import 'package:my_leadership_quest/providers/providers.dart';
import 'package:my_leadership_quest/models/models.dart';

class GameSummaryScreen extends StatefulWidget {
  final String roomId;
  final bool isBotGame;
  final Map<String, dynamic> rewards;

  const GameSummaryScreen({
    super.key,
    required this.roomId,
    required this.isBotGame,
    required this.rewards,
  });

  @override
  State<GameSummaryScreen> createState() => _GameSummaryScreenState();
}

class _GameSummaryScreenState extends State<GameSummaryScreen> {
  late ConfettiController _confettiController;
  bool _isLoadingSummary = true;
  Map<String, dynamic>? _summaryData;
  bool _isShared = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _loadSummary();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    // Safely disconnect the realtime channel now that the game is fully done and summarized
    QuestArenaService().disconnect();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await QuestArenaService().getGameSummary(widget.roomId, widget.isBotGame);
      if (!mounted) return;
      setState(() {
        _summaryData = summary;
        _isLoadingSummary = false;
      });

      // Play confetti if it's a victory!
      if (summary['result_text'] == 'Victory!') {
        _confettiController.play();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSummary = false;
      });
    }
  }

  void _shareOnVictoryWall(BuildContext context) async {
    if (_isShared || _summaryData == null) return;
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user == null) return;

    setState(() => _isLoadingSummary = true);

    final score = _summaryData!['my_score'];
    final resultText = _summaryData!['result_text'];
    final opponentName = _summaryData!['opponent_name'];

    String postContent;
    if (resultText == 'Victory!') {
      postContent = "🎯 Quest Arena Victory! I just won a Leadership Duel against $opponentName! 🏆 Score: $score pts. Feeling like a true leader! 💪🚀";
    } else if (resultText == 'It\'s a Tie!') {
      postContent = "🤝 Played an intense Quest Arena Duel with $opponentName and ended in a tie! Score: $score pts. Great practice! 🌟";
    } else {
      postContent = "📚 Just finished a Quest Arena Duel with $opponentName! Score: $score pts. Always learning and improving! 🌱✨";
    }

    final post = PostModel(
      id: const Uuid().v4(),
      userId: user.id,
      userName: user.name,
      content: postContent,
      createdAt: DateTime.now(),
    );

    try {
      final result = await postProvider.addPost(post);
      if (!mounted) return;
      setState(() {
        _isLoadingSummary = false;
        _isShared = true;
      });

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Victory shared on the Victory Wall! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSummary = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share victory: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final correctCount = widget.rewards['correct_count'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: _isLoadingSummary
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Outcome Banner
                        Column(
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              _summaryData?['result_icon'] ?? '🎉',
                              style: const TextStyle(fontSize: 64),
                            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                            const SizedBox(height: 12),
                            Text(
                              _summaryData?['result_text'] ?? 'Match Over!',
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: _summaryData?['result_text'] == 'Victory!'
                                    ? Colors.green[700]
                                    : _summaryData?['result_text'] == 'Defeat'
                                        ? Colors.red[700]
                                        : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),

                        // Score Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AppTheme.getNeumorphicDecoration(borderRadius: 24),
                          child: Column(
                            children: [
                              // Versus Breakdown
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildPlayerScore(
                                    name: 'You',
                                    score: _summaryData?['my_score'] ?? 0,
                                    color: AppColors.primary,
                                    isMe: true,
                                  ),
                                  Text(
                                    'VS',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textHint,
                                      fontSize: 18,
                                    ),
                                  ),
                                  _buildPlayerScore(
                                    name: _summaryData?['opponent_name'] ?? 'Opponent',
                                    score: _summaryData?['opponent_score'] ?? 0,
                                    color: widget.isBotGame ? Colors.orange : Colors.blue,
                                    isMe: false,
                                  ),
                                ],
                              ),
                              
                              const Divider(height: 32, thickness: 1),

                              // Match stats (no economy rewards)
                              Text(
                                'Match Stats',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Correct Answers: $correctCount / 5',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05),

                        // Action Buttons
                        Column(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isShared ? Colors.grey : const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 52),
                              ),
                              icon: const Icon(Icons.share),
                              label: Text(_isShared ? 'Shared on Victory Wall' : 'Share on Victory Wall'),
                              onPressed: _isShared ? null : () => _shareOnVictoryWall(context),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 52),
                              ),
                              onPressed: () {
                                // Pop back to Arena Lobby
                                Navigator.of(context).pop();
                              },
                              child: const Text('Back to Arena Lobby'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          // Confetti overlay on victory
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerScore({
    required String name,
    required int score,
    required Color color,
    required bool isMe,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            isMe
                ? Icons.person
                : widget.isBotGame
                    ? Icons.smart_toy
                    : Icons.person_outline,
            color: color,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Text(
            name,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score pts',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardItem({
    required IconData icon,
    required Color color,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:my_leadership_quest/providers/providers.dart';
import 'package:my_leadership_quest/theme/app_theme.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/quest_arena_service.dart';
import 'package:my_leadership_quest/screens/quest_arena/matchmaker_screen.dart';

class QuestArenaHomeScreen extends StatefulWidget {
  const QuestArenaHomeScreen({super.key});

  @override
  State<QuestArenaHomeScreen> createState() => _QuestArenaHomeScreenState();
}

class _QuestArenaHomeScreenState extends State<QuestArenaHomeScreen> {
  bool _isLoading = false;
  String _subject = 'mixed';

  static const List<String> _subjects = [
    'mixed',
    'math',
    'english',
    'science',
    'history',
    'geography',
  ];

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    
    // Compute mockup/realistic statistics based on user data
    final coins = user?.coins ?? 0.0;
    final xp = user?.monthlyXp ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quest Arena'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AppTheme.getNeumorphicDecoration(borderRadius: 20),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.orange, size: 20),
                const SizedBox(width: 4),
                Text(
                  coins.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.getGradientDecoration(
                  colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                  borderRadius: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leadership Duel',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Compete in real-time, solve scenarios, climb your rating, and earn seasonal trophies.',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Player Stats Header
              Text(
                'Your Arena Stats',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Grid of Stats
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard('Total Wins', '14', Icons.emoji_events, Colors.orange),
                  _buildStatCard('Matches Played', '22', Icons.sports_esports, Colors.blue),
                  _buildStatCard('Win Rate', '63.6%', Icons.percent, Colors.green),
                  _buildStatCard('XP Score', '$xp', Icons.star, Colors.purple),
                ],
              ),

              const SizedBox(height: 32),

              Text(
                'Pick a subject',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _subjects.map((s) {
                  final selected = _subject == s;
                  return ChoiceChip(
                    label: Text(s == 'mixed' ? 'Mixed' : s[0].toUpperCase() + s.substring(1)),
                    selected: selected,
                    onSelected: (_) => setState(() => _subject = s),
                    selectedColor: const Color(0xFF6366F1).withOpacity(0.18),
                    labelStyle: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      color: selected ? const Color(0xFF3730A3) : AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF6366F1).withOpacity(0.4)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    backgroundColor: Colors.white,
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Game Selection Actions
              Text(
                'Choose Game Mode',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Multiplayer Quick Match Button
              _buildGameModeCard(
                title: 'Quick Play Duel',
                subtitle: 'Match with an online player or classmate',
                icon: Icons.people_alt,
                gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
                onTap: () => _startMatchmaking(context, isBot: false),
              ),

              const SizedBox(height: 16),

              // Solo vs Bot Button
              _buildGameModeCard(
                title: 'Practice vs AI Coach',
                subtitle: 'Improve your skills against a computer coach',
                icon: Icons.smart_toy,
                gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                onTap: () => _startMatchmaking(context, isBot: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildGameModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.getNeumorphicDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }

  void _startMatchmaking(BuildContext context, {required bool isBot}) async {
    setState(() => _isLoading = true);
    
    try {
      QuestArenaRoom room;
      if (isBot) {
        room = await QuestArenaService().startBotGame(subject: _subject);
      } else {
        room = await QuestArenaService().findOrCreateRoom(subject: _subject);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Navigate to Matchmaker/Loading Screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MatchmakerScreen(room: room),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to enter Arena: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

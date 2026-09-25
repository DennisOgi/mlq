import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:my_leadership_quest/theme/app_theme.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/quest_arena_service.dart';
import 'package:my_leadership_quest/screens/quest_arena/game_play_screen.dart';

class MatchmakerScreen extends StatefulWidget {
  final QuestArenaRoom room;
  const MatchmakerScreen({super.key, required this.room});

  @override
  State<MatchmakerScreen> createState() => _MatchmakerScreenState();
}

class _MatchmakerScreenState extends State<MatchmakerScreen> {
  late QuestArenaRoom _currentRoom;
  int _searchTimerSeconds = 0;
  Timer? _searchTimer;
  Timer? _countdownTimer;
  int _startCountdown = 3;
  bool _isTransitioning = false;
  bool _showBotPrompt = false;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;

    if (_currentRoom.status == 'active') {
      // Room is already active (e.g. joined existing or bot game), start countdown immediately
      _startCountdownFlow();
    } else {
      // Waiting for player, start search timer and subscribe
      _startSearchTimer();
      _subscribeToRoomChanges();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _countdownTimer?.cancel();
    QuestArenaService().disconnect();
    super.dispose();
  }

  void _startSearchTimer() {
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _searchTimerSeconds++;
        if (_searchTimerSeconds >= 15 && !_showBotPrompt) {
          _showBotPrompt = true;
          _searchTimer?.cancel();
        }
      });
    });
  }

  void _subscribeToRoomChanges() {
    QuestArenaService().connectToRoom(_currentRoom, (updatedRoom) {
      if (!mounted) return;
      
      setState(() {
        _currentRoom = updatedRoom;
      });

      if (_currentRoom.status == 'active' && !_isTransitioning) {
        _searchTimer?.cancel();
        _startCountdownFlow();
      }
    });
  }

  void _startCountdownFlow() {
    if (!mounted) return;
    setState(() {
      _isTransitioning = true;
      _showBotPrompt = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_startCountdown > 1) {
          _startCountdown--;
        } else {
          _countdownTimer?.cancel();
          _navigateToGame();
        }
      });
    });
  }

  void _navigateToGame() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GamePlayScreen(room: _currentRoom),
      ),
    );
  }

  void _playAgainstBot() async {
    _searchTimer?.cancel();
    QuestArenaService().disconnect();

    // Cancel waiting room
    await QuestArenaService().cancelMatchmaking(_currentRoom.id);

    // Create a bot game
    try {
      final botRoom = await QuestArenaService().startBotGame();
      if (!mounted) return;
      setState(() {
        _currentRoom = botRoom;
        _showBotPrompt = false;
      });
      _startCountdownFlow();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch AI game: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Quest Arena',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isTransitioning ? 'Opponent Found!' : 'Matchmaking Queue',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Animated Center Section
              Expanded(
                child: Center(
                  child: _isTransitioning
                      ? _buildCountdownUI()
                      : _buildRadarUI(),
                ),
              ),

              // Bottom Actions
              Column(
                children: [
                  if (_showBotPrompt) ...[
                    Text(
                      'Taking longer than usual...',
                      style: GoogleFonts.nunito(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      icon: const Icon(Icons.smart_toy),
                      label: const Text('Play with AI Coach instead'),
                      onPressed: _playAgainstBot,
                    ).animate().fade(duration: 300.ms).scaleY(),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: AppColors.error, width: 2),
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: () async {
                      if (!_isTransitioning) {
                        await QuestArenaService().cancelMatchmaking(_currentRoom.id);
                      }
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Cancel Match'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'GET READY',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF8B5CF6),
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 140,
          height: 140,
          alignment: Alignment.center,
          decoration: AppTheme.getNeumorphicDecoration(borderRadius: 70),
          child: Text(
            '$_startCountdown',
            style: GoogleFonts.poppins(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ).animate(key: ValueKey(_startCountdown)).scale(duration: 400.ms, curve: Curves.elasticOut),
        ),
        const SizedBox(height: 24),
        Text(
          'Game starts in a few seconds',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRadarUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Radar circle pulse
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .scale(duration: 2.seconds, begin: const Offset(1.0, 1.0), end: const Offset(2.0, 2.0))
                .fade(begin: 1.0, end: 0.0),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .scale(duration: 2.seconds, delay: 1.seconds, begin: const Offset(1.0, 1.0), end: const Offset(2.0, 2.0))
                .fade(begin: 1.0, end: 0.0),
            // Center Neumorphic Ring
            Container(
              width: 120,
              height: 120,
              decoration: AppTheme.getNeumorphicDecoration(borderRadius: 60),
              child: const Icon(
                Icons.radar,
                size: 48,
                color: AppColors.primary,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shake(duration: 1.5.seconds, hz: 4),
          ],
        ),
        const SizedBox(height: 36),
        Text(
          'Finding peer...',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Queue time: $_searchTimerSeconds seconds',
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:my_leadership_quest/theme/app_theme.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/quest_arena_service.dart';
import 'package:my_leadership_quest/screens/quest_arena/game_summary_screen.dart';

class GamePlayScreen extends StatefulWidget {
  final QuestArenaRoom room;
  const GamePlayScreen({super.key, required this.room});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  List<bool> _answerHistory = []; // true = correct, false = incorrect
  List<Map<String, dynamic>> _userAnswersList = [];
  
  // Timer settings
  static const int _questionTimeLimit = 15;
  int _secondsLeft = _questionTimeLimit;
  Timer? _questionTimer;

  // Selected state
  String? _selectedOption; // 'A', 'B', 'C', 'D'
  bool _isAnswered = false;

  // Opponent Live Progress
  PlayerGameProgress? _opponentProgress;
  StreamSubscription<PlayerGameProgress>? _opponentProgressSubscription;

  @override
  void initState() {
    super.initState();
    _startTimer();
    
    // Connect to room & listen to live progress broadcasts
    QuestArenaService().connectToRoom(widget.room, (_) {});
    _opponentProgressSubscription = QuestArenaService().opponentProgressStream?.listen((progress) {
      if (mounted) {
        setState(() {
          _opponentProgress = progress;
        });
      }
    });

    // Broadcast initial state
    _broadcastMyProgress();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _opponentProgressSubscription?.cancel();
    // Note: service disconnect will be called on the summary screen to keep broadcast channels alive until matching is done.
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = _questionTimeLimit;
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _secondsLeft = 0;
          _questionTimer?.cancel();
          _handleTimeOut();
        }
      });
    });
  }

  void _broadcastMyProgress() {
    final progress = PlayerGameProgress(
      currentQuestionIndex: _currentQuestionIndex,
      score: _score,
      answerHistory: List.from(_answerHistory),
    );
    QuestArenaService().broadcastProgress(widget.room.id, progress);
  }

  void _handleOptionTap(String optionCode) {
    if (_isAnswered) return;
    _questionTimer?.cancel();

    final currentQuestion = widget.room.questions[_currentQuestionIndex];
    final isCorrect = optionCode == currentQuestion.correctOption;

    setState(() {
      _selectedOption = optionCode;
      _isAnswered = true;
      if (isCorrect) {
        _score += 10;
        _answerHistory.add(true);
      } else {
        _answerHistory.add(false);
      }

      _userAnswersList.add({
        'question_id': currentQuestion.id,
        'selected_option': optionCode,
        'correct_option': currentQuestion.correctOption,
        'is_correct': isCorrect,
        'time_taken_seconds': _questionTimeLimit - _secondsLeft,
      });
    });

    _broadcastMyProgress();
  }

  void _handleTimeOut() {
    final currentQuestion = widget.room.questions[_currentQuestionIndex];
    setState(() {
      _selectedOption = null;
      _isAnswered = true;
      _answerHistory.add(false);

      _userAnswersList.add({
        'question_id': currentQuestion.id,
        'selected_option': 'NONE',
        'correct_option': currentQuestion.correctOption,
        'is_correct': false,
        'time_taken_seconds': _questionTimeLimit,
      });
    });

    _broadcastMyProgress();
  }

  void _goToNextQuestion() async {
    if (_currentQuestionIndex < widget.room.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _isAnswered = false;
        _selectedOption = null;
      });
      _broadcastMyProgress();
      _startTimer();
    } else {
      // Completed the quiz! Submit score and go to summary
      _questionTimer?.cancel();
      _showSubmittingDialog();

      try {
        final rewards = await QuestArenaService().submitFinalScore(
          roomId: widget.room.id,
          score: _score,
          answers: _userAnswersList,
          isBotGame: widget.room.isBotGame,
        );

        if (!mounted) return;
        Navigator.of(context).pop(); // dismiss loading dialog

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GameSummaryScreen(
              roomId: widget.room.id,
              isBotGame: widget.room.isBotGame,
              rewards: rewards,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving game results: $e')),
        );
        Navigator.of(context).pop(); // go back to main menu
      }
    }
  }

  void _showSubmittingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Submitting Duel Score...',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Finalizing your match results...',
                style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.room.questions[_currentQuestionIndex];
    final totalQuestions = widget.room.questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with live status of both players
              _buildLiveOpponentTracker(totalQuestions),
              
              const SizedBox(height: 16),

              // 2. Question number, timer and category banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currentQuestion.category.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '$_secondsLeft s',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          color: _secondsLeft <= 5 ? AppColors.error : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Question scenario card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.getNeumorphicDecoration(borderRadius: 20),
                child: Text(
                  currentQuestion.scenario,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Options
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildOptionTile('A', currentQuestion.optionA, currentQuestion.correctOption),
                      const SizedBox(height: 12),
                      _buildOptionTile('B', currentQuestion.optionB, currentQuestion.correctOption),
                      const SizedBox(height: 12),
                      _buildOptionTile('C', currentQuestion.optionC, currentQuestion.correctOption),
                      const SizedBox(height: 12),
                      _buildOptionTile('D', currentQuestion.optionD, currentQuestion.correctOption),
                    ],
                  ),
                ),
              ),

              // 3. Explanation and Next button
              if (_isAnswered) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Leadership Lesson',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentQuestion.explanation,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 300.ms).slideY(begin: 0.1),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: _goToNextQuestion,
                  child: Text(
                    _currentQuestionIndex < totalQuestions - 1 ? 'Next Scenario' : 'View Results',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveOpponentTracker(int totalQuestions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        children: [
          // Player rows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current User
              Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'You',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              // User Progress dots
              _buildProgressDots(_currentQuestionIndex, _answerHistory, totalQuestions),
              Text(
                '$_score pts',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
            ],
          ),
          const Divider(height: 16, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Opponent
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: widget.room.isBotGame ? Colors.orange : Colors.blue,
                    child: Icon(
                      widget.room.isBotGame ? Icons.smart_toy : Icons.person_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.room.isBotGame ? 'AI Bot' : 'Opponent',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              // Opponent Progress dots
              _buildProgressDots(
                _opponentProgress?.currentQuestionIndex ?? 0,
                _opponentProgress?.answerHistory ?? [],
                totalQuestions,
              ),
              Text(
                '${_opponentProgress?.score ?? 0} pts',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: widget.room.isBotGame ? Colors.orange : Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots(int activeIndex, List<bool> history, int total) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        Color dotColor = Colors.grey[300]!;
        IconData? icon;

        if (index < history.length) {
          final isCorrect = history[index];
          dotColor = isCorrect ? Colors.green : Colors.red;
          icon = isCorrect ? Icons.check : Icons.close;
        } else if (index == activeIndex) {
          dotColor = AppColors.primary;
        }

        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 12)
              : null,
        );
      }),
    );
  }

  Widget _buildOptionTile(String optionCode, String optionText, String correctOption) {
    final bool isSelected = _selectedOption == optionCode;
    final bool isCorrectAnswer = optionCode == correctOption;

    Color tileColor = AppColors.surface;
    Color textColor = AppColors.textPrimary;
    BorderSide border = BorderSide.none;

    if (_isAnswered) {
      if (isCorrectAnswer) {
        // Always show the correct option as green
        tileColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green[800]!;
        border = BorderSide(color: Colors.green.withOpacity(0.5), width: 2);
      } else if (isSelected) {
        // If selected incorrect, show red
        tileColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red[800]!;
        border = BorderSide(color: Colors.red.withOpacity(0.5), width: 2);
      }
    } else if (isSelected) {
      tileColor = AppColors.primary.withOpacity(0.1);
      border = const BorderSide(color: AppColors.primary, width: 2);
    }

    return GestureDetector(
      onTap: () => _handleOptionTap(optionCode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.getNeumorphicDecoration().copyWith(
          color: tileColor,
          border: border == BorderSide.none ? null : Border(
            top: border, left: border, right: border, bottom: border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Text(
                optionCode,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                optionText,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

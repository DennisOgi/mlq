import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';

class QuestArenaQuestion {
  final String id;
  final String scenario;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final String explanation;
  final String category;

  QuestArenaQuestion({
    required this.id,
    required this.scenario,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.explanation,
    required this.category,
  });

  factory QuestArenaQuestion.fromJson(Map<String, dynamic> json) {
    return QuestArenaQuestion(
      id: json['id'] ?? '',
      scenario: json['scenario'] ?? '',
      optionA: json['option_a'] ?? '',
      optionB: json['option_b'] ?? '',
      optionC: json['option_c'] ?? '',
      optionD: json['option_d'] ?? '',
      correctOption: json['correct_option'] ?? 'A',
      explanation: json['explanation'] ?? '',
      category: json['category'] ?? 'Leadership',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scenario': scenario,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_option': correctOption,
      'explanation': explanation,
      'category': category,
    };
  }
}

class QuestArenaRoom {
  final String id;
  final String player1Id;
  final String? player2Id;
  final String status;
  final List<QuestArenaQuestion> questions;
  final bool isBotGame;
  final DateTime createdAt;

  QuestArenaRoom({
    required this.id,
    required this.player1Id,
    this.player2Id,
    required this.status,
    required this.questions,
    required this.isBotGame,
    required this.createdAt,
  });

  factory QuestArenaRoom.fromJson(Map<String, dynamic> json) {
    var questionsJson = json['questions'] as List? ?? [];
    List<QuestArenaQuestion> loadedQuestions = questionsJson
        .map((q) => QuestArenaQuestion.fromJson(q as Map<String, dynamic>))
        .toList();

    return QuestArenaRoom(
      id: json['id'] ?? '',
      player1Id: json['player_1_id'] ?? '',
      player2Id: json['player_2_id'],
      status: json['status'] ?? 'waiting',
      questions: loadedQuestions,
      isBotGame: json['is_bot_game'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class PlayerGameProgress {
  final int currentQuestionIndex;
  final int score;
  final List<bool> answerHistory; // true = correct, false = incorrect

  PlayerGameProgress({
    required this.currentQuestionIndex,
    required this.score,
    required this.answerHistory,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentQuestionIndex': currentQuestionIndex,
      'score': score,
      'answerHistory': answerHistory,
    };
  }

  factory PlayerGameProgress.fromJson(Map<String, dynamic> json) {
    return PlayerGameProgress(
      currentQuestionIndex: json['currentQuestionIndex'] ?? 0,
      score: json['score'] ?? 0,
      answerHistory: List<bool>.from(json['answerHistory'] ?? []),
    );
  }
}

class QuestArenaService {
  static final QuestArenaService _instance = QuestArenaService._internal();
  factory QuestArenaService() => _instance;
  QuestArenaService._internal();

  final SupabaseClient _client = SupabaseService.instance.client;
  RealtimeChannel? _gameChannel;
  StreamController<PlayerGameProgress>? _opponentProgressController;
  Timer? _botSimulationTimer;

  // Stream of the opponent's live progress
  Stream<PlayerGameProgress>? get opponentProgressStream =>
      _opponentProgressController?.stream;

  /// Fetches a list of random questions from Supabase to bundle in a room
  Future<List<QuestArenaQuestion>> _fetchRandomQuestions({
    int count = 5,
    String? subject,
  }) async {
    try {
      var q = _client.from('game_questions').select();
      final s = (subject ?? '').trim().toLowerCase();
      if (s.isNotEmpty && s != 'mixed') {
        q = q.eq('subject', s);
      }
      final response = await q;

      final list = (response as List)
          .map((item) => QuestArenaQuestion.fromJson(item))
          .toList();

      if (list.isEmpty) {
        throw Exception('No questions found in database.');
      }

      list.shuffle(Random());
      return list.take(count).toList();
    } catch (e) {
      debugPrint('Error fetching questions: $e');
      // Fallback in case table is empty or offline
      return _getFallbackQuestions();
    }
  }

  /// Matchmakes the current user. Searches for an open room. If none is found, creates one.
  Future<QuestArenaRoom> findOrCreateRoom({String subject = 'mixed'}) async {
    try {
      // Use an atomic DB-side matchmaking function to avoid client-side races.
      final room = await _client.rpc(
        'arena_find_or_create_room',
        params: {'p_question_count': 5, 'p_subject': subject},
      );

      debugPrint('Arena matchmaking resolved room: ${room['id']}');
      return QuestArenaRoom.fromJson(room);
    } on PostgrestException catch (e) {
      debugPrint(
          'Error in findOrCreateRoom (Postgrest): code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
      if (e.code == 'PGRST202') {
        throw Exception(
          'Quest Arena backend is not deployed yet (missing RPC arena_find_or_create_room). '
          'Apply Supabase migrations and reload schema cache.',
        );
      }
      rethrow;
    } catch (e, st) {
      debugPrint('Error in findOrCreateRoom: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Immediately launches a game against an AI bot
  Future<QuestArenaRoom> startBotGame({String subject = 'mixed'}) async {
    final currentUserId = SupabaseService.instance.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('User must be authenticated to play.');
    }

    try {
      final questions = await _fetchRandomQuestions(subject: subject);
      final newRoomData = await _client
          .from('game_rooms')
          .insert({
            'player_1_id': currentUserId,
            'status': 'active',
            'is_bot_game': true,
            'questions': questions.map((q) => q.toJson()).toList(),
          })
          .select()
          .single();

      debugPrint('Started bot game: ${newRoomData['id']}');
      return QuestArenaRoom.fromJson(newRoomData);
    } on PostgrestException catch (e) {
      debugPrint(
          'Error in startBotGame (Postgrest): code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
      if (e.code == '42P01') {
        throw Exception(
          'Quest Arena backend tables are missing (game_rooms / game_questions). '
          'Apply Supabase migrations to create the multiplayer schema.',
        );
      }
      rethrow;
    } catch (e, st) {
      debugPrint('Error in startBotGame: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Cancels matchmaking (deletes or cancels a waiting room)
  Future<void> cancelMatchmaking(String roomId) async {
    try {
      await _client
          .from('game_rooms')
          .update({'status': 'cancelled'})
          .eq('id', roomId);
      debugPrint('Cancelled matchmaking for room: $roomId');
    } catch (e) {
      debugPrint('Error cancelling matchmaking: $e');
    }
  }

  /// Connects to a game room and starts listening to opponent updates
  void connectToRoom(QuestArenaRoom room, Function(QuestArenaRoom) onRoomUpdated) {
    _opponentProgressController = StreamController<PlayerGameProgress>.broadcast();

    // 1. Listen for changes in the database room state (e.g. when Player 2 joins)
    if (room.status == 'waiting') {
      _client
          .from('game_rooms')
          .stream(primaryKey: ['id'])
          .eq('id', room.id)
          .listen((List<Map<String, dynamic>> rooms) {
            if (rooms.isNotEmpty) {
              final updatedRoom = QuestArenaRoom.fromJson(rooms.first);
              onRoomUpdated(updatedRoom);
            }
          });
    }

    // 2. Set up Realtime Broadcast for live progress sharing
    _gameChannel = _client.channel('arena_${room.id}');
    
    _gameChannel!.onBroadcast(
      event: 'progress',
      callback: (payload) {
        final senderId = payload['user_id'];
        final currentUserId = SupabaseService.instance.currentUser?.id;
        
        // Only listen to the other player's progress
        if (senderId != currentUserId) {
          final progress = PlayerGameProgress.fromJson(payload['progress']);
          _opponentProgressController?.add(progress);
        }
      },
    );

    _gameChannel!.subscribe();

    // 3. If this is a bot game, simulate the bot
    if (room.isBotGame) {
      _startBotSimulation(room.questions.length);
    }
  }

  /// Broadcasts your current progress to the opponent
  void broadcastProgress(String roomId, PlayerGameProgress progress) {
    final currentUserId = SupabaseService.instance.currentUser?.id;
    if (currentUserId == null || _gameChannel == null) return;

    // NOTE: `send` is internal in realtime_client; use the public helper instead.
    _gameChannel!.sendBroadcastMessage(
      event: 'progress',
      payload: {
        'user_id': currentUserId,
        'progress': progress.toJson(),
      },
    );
  }

  /// Simulates an AI opponent's progress in real-time
  void _startBotSimulation(int totalQuestions) {
    int currentQuestion = 0;
    int botScore = 0;
    List<bool> history = [];
    final random = Random();

    _botSimulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulate answer every 4-8 seconds
      final secondsNeeded = random.nextInt(4) + 4;
      if (timer.tick % secondsNeeded == 0) {
        final isCorrect = random.nextDouble() < 0.75; // 75% accuracy
        if (isCorrect) botScore += 10;
        history.add(isCorrect);
        
        final progress = PlayerGameProgress(
          currentQuestionIndex: currentQuestion,
          score: botScore,
          answerHistory: List.from(history),
        );

        _opponentProgressController?.add(progress);
        currentQuestion++;

        if (currentQuestion >= totalQuestions) {
          _botSimulationTimer?.cancel();
        }
      }
    });
  }

  /// Saves the final game score.
  ///
  /// NOTE: Quest Arena does not award coins or XP. Rewards are handled via
  /// MMR + seasonal trophies + cosmetics (separate systems).
  Future<Map<String, dynamic>> submitFinalScore({
    required String roomId,
    required int score,
    required List<Map<String, dynamic>> answers,
    required bool isBotGame,
  }) async {
    final currentUserId = SupabaseService.instance.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated.');

    try {
      // 1. Compute summary stats (no economy rewards)
      final correctCount = answers.where((a) => a['is_correct'] == true).length;

      // 2. Save score to Supabase
      await _client.from('game_scores').upsert({
        'room_id': roomId,
        'user_id': currentUserId,
        'score': score,
        'answers': answers,
        'coins_earned': 0,
        'xp_earned': 0,
      });

      // 3. Update room status to completed if appropriate
      if (isBotGame) {
        await _client
            .from('game_rooms')
            .update({'status': 'completed'})
            .eq('id', roomId);
      } else {
        // For human multiplayer, check if the opponent has also submitted score
        final scoresResponse = await _client
            .from('game_scores')
            .select('user_id')
            .eq('room_id', roomId);

        if (scoresResponse.length >= 2) {
          await _client
              .from('game_rooms')
              .update({'status': 'completed'})
              .eq('id', roomId);
        }
      }

      return {
        'correct_count': correctCount,
      };
    } catch (e) {
      debugPrint('Error submitting score and awarding prizes: $e');
      rethrow;
    }
  }

  /// Retrieves final score details for both players to show the summary
  Future<Map<String, dynamic>> getGameSummary(String roomId, bool isBotGame) async {
    final currentUserId = SupabaseService.instance.currentUser?.id;
    if (currentUserId == null) throw Exception('User not authenticated.');

    try {
      final response = await _client
          .from('game_scores')
          .select('score, user_id, coins_earned, xp_earned, profiles(name, avatar_url)')
          .eq('room_id', roomId);

      Map<String, dynamic>? myResult;
      Map<String, dynamic>? opponentResult;

      for (var r in response) {
        final profile = r['profiles'] as Map<String, dynamic>? ?? {};
        final result = {
          'score': r['score'] ?? 0,
          'name': profile['name'] ?? 'Player',
          'avatar_url': profile['avatar_url'],
          'coins_earned': r['coins_earned'] ?? 0,
          'xp_earned': r['xp_earned'] ?? 0,
        };

        if (r['user_id'] == currentUserId) {
          myResult = result;
        } else {
          opponentResult = result;
        }
      }

      // If playing with a bot and opponent hasn't completed, or opponent was a bot
      if (isBotGame && opponentResult == null) {
        // Fetch bot's simulated final score from the DB or generate a realistic one
        opponentResult = {
          'score': 30, // 3/5 correct
          'name': 'AI Coach Bot',
          'avatar_url': null,
          'coins_earned': 0,
          'xp_earned': 0,
        };
      }

      // Determine match result text
      String resultText = 'It\'s a Tie!';
      String icon = '🤝';
      if (myResult != null && opponentResult != null) {
        final myScore = myResult['score'] as int;
        final opScore = opponentResult['score'] as int;
        if (myScore > opScore) {
          resultText = 'Victory!';
          icon = '🏆';
        } else if (myScore < opScore) {
          resultText = 'Defeat';
          icon = '💔';
        }
      }

      return {
        'my_score': myResult?['score'] ?? 0,
        'my_coins': myResult?['coins_earned'] ?? 0,
        'my_xp': myResult?['xp_earned'] ?? 0,
        'opponent_name': opponentResult?['name'] ?? 'Waiting...',
        'opponent_score': opponentResult?['score'] ?? 0,
        'opponent_avatar': opponentResult?['avatar_url'],
        'result_text': resultText,
        'result_icon': icon,
      };
    } catch (e) {
      debugPrint('Error getting game summary: $e');
      return {
        'my_score': 0,
        'my_coins': 0,
        'my_xp': 0,
        'opponent_name': isBotGame ? 'AI Coach Bot' : 'Opponent',
        'opponent_score': 30,
        'opponent_avatar': null,
        'result_text': 'Completed!',
        'result_icon': '🎉',
      };
    }
  }

  /// Disconnects and cleans up resources
  void disconnect() {
    _botSimulationTimer?.cancel();
    _botSimulationTimer = null;
    
    if (_gameChannel != null) {
      _client.removeChannel(_gameChannel!);
      _gameChannel = null;
    }

    _opponentProgressController?.close();
    _opponentProgressController = null;
  }

  List<QuestArenaQuestion> _getFallbackQuestions() {
    return [
      QuestArenaQuestion(
        id: 'fallback-1',
        scenario: 'Your team is working on a school project, but one team member is not doing their part. What is the best leadership approach?',
        optionA: 'Complain to the teacher immediately without talking to them first.',
        optionB: 'Talk to them privately, check if they need help, and encourage them to contribute.',
        optionC: 'Do their work for them and leave their name off the project submission.',
        optionD: 'Ignore them and complete the project only with the other cooperative members.',
        correctOption: 'B',
        explanation: 'A good leader tries to understand the team members first, communicates privately, and offers support before escalating issues.',
        category: 'Teamwork',
      ),
      QuestArenaQuestion(
        id: 'fallback-2',
        scenario: 'You notice a classmate sitting alone at lunch looking sad and left out. What is the most empathetic action?',
        optionA: 'Ignore them; they probably want some quiet time.',
        optionB: 'Go over, sit with them, and invite them to eat with you and your friends.',
        optionC: 'Go tell a teacher that someone is sitting alone.',
        optionD: 'Point them out to your friends and talk about why they might be sad.',
        correctOption: 'B',
        explanation: 'Empathy means taking action to help others feel valued. Inviting someone who is alone to join you makes a big difference.',
        category: 'Empathy',
      ),
    ];
  }
}

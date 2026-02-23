import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/challenge_evaluator.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/challenge_service.dart';
import '../providers/user_provider.dart';

class UnlockResult {
  final bool success;
  final String? redirectUrl;
  final String? errorMessage;
  
  UnlockResult({
    required this.success,
    this.redirectUrl,
    this.errorMessage,
  });
}

class ChallengeProvider extends ChangeNotifier {
  List<ChallengeModel> _challenges = [];
  List<String> _participatingChallengeIds = [];
  final Set<String> _completedChallengeIds = {};
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _initInProgress = false;
  
  // Subscription to evaluator events
  StreamSubscription? _completionSubscription;
  
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  List<ChallengeModel> get challenges => _challenges;
  List<String> get participatingChallengeIds => _participatingChallengeIds;

  List<ChallengeModel> get basicChallenges => 
      _challenges.where((challenge) => challenge.type == ChallengeType.basic).toList();

  List<ChallengeModel> get premiumChallenges => 
      _challenges.where((challenge) => challenge.type == ChallengeType.premium).toList();

  List<ChallengeModel> get participatingChallenges => 
      _challenges.where((challenge) => _participatingChallengeIds.contains(challenge.id)).toList();
  
  /// Get only active (non-expired) challenges
  List<ChallengeModel> get activeChallenges =>
      _challenges.where((challenge) => challenge.isActive).toList();
  
  /// Get only active basic challenges
  List<ChallengeModel> get activeBasicChallenges =>
      _challenges.where((challenge) => challenge.type == ChallengeType.basic && challenge.isActive).toList();
  
  /// Get only active premium challenges
  List<ChallengeModel> get activePremiumChallenges =>
      _challenges.where((challenge) => challenge.type == ChallengeType.premium && challenge.isActive).toList();
  
  /// Get expired challenges (for history/archive view)
  List<ChallengeModel> get expiredChallenges =>
      _challenges.where((challenge) => challenge.isExpired).toList();
  
  /// Get challenges the user is participating in that are still active
  List<ChallengeModel> get activeParticipatingChallenges =>
      _challenges.where((challenge) => 
          _participatingChallengeIds.contains(challenge.id) && challenge.isActive).toList();
  
  /// Get challenges the user participated in that have expired
  List<ChallengeModel> get expiredParticipatingChallenges =>
      _challenges.where((challenge) => 
          _participatingChallengeIds.contains(challenge.id) && challenge.isExpired).toList();

  // Check if a joined challenge is completed
  bool isCompleted(String challengeId) => _completedChallengeIds.contains(challengeId);

  // Initialize with data from Supabase
  ChallengeProvider() {
    // Listen for challenge completion events to keep UI in sync
    try {
      _completionSubscription = ChallengeEvaluator.instance.completionStream.listen(_onChallengeCompleted);
    } catch (e) {
      debugPrint('Error subscribing to challenge completion stream: $e');
    }
  }

  @override
  void dispose() {
    _completionSubscription?.cancel();
    super.dispose();
  }

  void _onChallengeCompleted(ChallengeCompletionEvent event) {
    if (!_completedChallengeIds.contains(event.challengeId)) {
      debugPrint('ChallengeProvider: Received completion event for ${event.challengeId}');
      _completedChallengeIds.add(event.challengeId);
      
      // Also update the challenges list if we have the data loaded
      final idx = _challenges.indexWhere((c) => c.id == event.challengeId);
      // Note: ChallengeModel doesn't have an isCompleted field (it's in user_challenges),
      // but we track it via _completedChallengeIds set.
      
      notifyListeners();
    }
  }
  
  // Premium flow: use server-side transaction for atomic unlock
  // Returns UnlockResult with status and optional redirect URL
  Future<UnlockResult> unlockPremium(
    String challengeId, {
    required double coinCost,
    required UserProvider userProvider,
  }) async {
    // Prevent duplicate unlocks
    // Prevent duplicate unlocks
    if (_participatingChallengeIds.contains(challengeId)) {
      return UnlockResult(success: true);
    }

    _setLoading(true);
    try {
      // Validate balance locally first for better UX
      final user = userProvider.user;
      if (user == null || user.coins < coinCost) {
        _hasError = true;
        _errorMessage = 'Not enough coins to unlock this premium challenge';
        return UnlockResult(success: false, errorMessage: _errorMessage);
      }

      // Call server-side transaction
      if (_supabaseService.isAuthenticated && _isUuid(challengeId)) {
        final uid = _supabaseService.currentUser?.id;
        if (uid == null) throw Exception('User not authenticated');

        final response = await _supabaseService.client.rpc(
          'unlock_premium_challenge_transaction',
          params: {
            'p_user_id': uid,
            'p_challenge_id': challengeId,
            'p_cost': coinCost,
          },
        );

        if (response is Map && response['success'] == true) {
          // Success!
          debugPrint('Premium challenge unlocked successfully via transaction');
          
          // Refresh user coins locally
          await userProvider.refreshUser();
          
          // Add participation locally
          if (!_participatingChallengeIds.contains(challengeId)) {
            _participatingChallengeIds.add(challengeId);
          }
          
          // Update participants count
          final index = _challenges.indexWhere((challenge) => challenge.id == challengeId);
          if (index != -1) {
            final challenge = _challenges[index];
            _challenges[index] = challenge.copyWith(
              participantsCount: challenge.participantsCount + 1,
            );
          }

          // Check for external URL if applicable
          final ch = getChallengeById(challengeId);
          if (ch != null &&
              ch.validationMode == 'external' &&
              (ch.externalJoinUrl?.isNotEmpty ?? false)) {
            return UnlockResult(success: true, redirectUrl: ch.externalJoinUrl);
          }
          
          // For in-app challenges, we might return a deep link or null
          // If there's a specific "redirectUrl" logic needed, it can be added here
          // For now, returning null implies "stay in app, unlock successful"
          return UnlockResult(success: true); 
        } else {
          throw Exception(response['message'] ?? 'Failed to unlock challenge');
        }
      }

      // Mock/unauthed path: if non-UUID, simulate only in debug builds
      if (kDebugMode && !_isUuid(challengeId)) {
        // Deduct coins locally for mock
        await userProvider.addCoins(-coinCost);
        
        // Mark participation locally
        if (!_participatingChallengeIds.contains(challengeId)) {
          _participatingChallengeIds.add(challengeId);
        }
        // Ensure the mock challenge exists in list and bump participants
        final idx = _challenges.indexWhere((c) => c.id == challengeId);
        if (idx == -1) {
          final mock = ChallengeService.getChallengeById(challengeId);
          if (mock != null) {
            _challenges.add(mock.copyWith(participantsCount: mock.participantsCount + 1));
          }
        } else {
          final c = _challenges[idx];
          _challenges[idx] = c.copyWith(participantsCount: c.participantsCount + 1);
        }
        notifyListeners();
        // Return mock secret URL
        return UnlockResult(success: true, redirectUrl: ChallengeService.getMockAccessUrl(challengeId));
      }
      
      return UnlockResult(success: false, errorMessage: 'Unknown error');
    } catch (e) {
      debugPrint('Error unlocking premium challenge: $e');
      _hasError = true;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return UnlockResult(success: false, errorMessage: _errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch a signed access link for an already-unlocked premium challenge.
  // Does NOT deduct coins. Returns null on failure.
  Future<String?> getPremiumAccessLink(String challengeId) async {
    try {
      final ch = getChallengeById(challengeId);
      if (ch != null &&
          ch.validationMode == 'external' &&
          (ch.externalJoinUrl?.isNotEmpty ?? false)) {
        return ch.externalJoinUrl;
      }

      // For mock (non-UUID) challenges, return the mock URL immediately
      if (!_isUuid(challengeId)) {
        return ChallengeService.getMockAccessUrl(challengeId);
      }
      // Ensure authenticated and a realistic id before calling backend
      if (!_supabaseService.isAuthenticated) {
        return null;
      }

      final response = await _supabaseService.client.functions.invoke(
        'unlock-premium-challenge',
        body: {
          'challengeId': challengeId,
          'linkOnly': true, // hints backend to only generate access link
        },
      );

      if (response.data != null && response.data['success'] == true) {
        return response.data['redirectUrl'] as String?;
      }

      _hasError = true;
      _errorMessage = response.data?['error'] ?? 'Failed to get access link';
      return null;
    } catch (e) {
      debugPrint('Error fetching premium access link: $e');
      _hasError = true;
      _errorMessage = 'Failed to get access link';
      return null;
    } finally {
      notifyListeners();
    }
  }

  // Utility: detect UUID v4-ish (hyphenated 36 chars)
  bool _isUuid(String value) {
    final regex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return regex.hasMatch(value);
  }

  // Basic flow: fully in-app join using existing joinChallenge semantics
  Future<bool> joinBasic(String challengeId, {UserProvider? userProvider}) async {
    return joinChallenge(challengeId, isPremium: false, userProvider: userProvider);
  }

  // Initialize challenges from Supabase
  Future<void> initChallenges() async {
    if (_initInProgress) return;

    _initInProgress = true;
    _setLoading(true);
    try {
      // Always try to fetch from database first
      try {
        final challenges = await _supabaseService.fetchChallenges();
        _challenges = challenges;
        
        // Fetch user challenges if authenticated
        if (_supabaseService.isAuthenticated) {
          final userChallenges = await _supabaseService.fetchUserChallenges();
          _participatingChallengeIds = [];
          _completedChallengeIds.clear();
          for (var userChallenge in userChallenges) {
            _participatingChallengeIds.add(userChallenge.challengeId);
            if (userChallenge.isCompleted) {
              _completedChallengeIds.add(userChallenge.challengeId);
            }
          }
        }
        
        debugPrint('Loaded ${_challenges.length} challenges from database');
      } catch (dbError) {
        debugPrint('Database fetch failed: $dbError, using mock data');
        // Only use mock data in debug builds; in release, show empty state
        if (kDebugMode) {
          _challenges = ChallengeModel.mockChallenges();
          if (_challenges.isNotEmpty) {
            _participatingChallengeIds.add(_challenges.first.id);
          }
        } else {
          _challenges = [];
        }
      }
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing challenges: $e');
      _setError('Failed to load challenges');
    } finally {
      _initInProgress = false;
    }
  }
  
  // Helper methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _hasError = false;
      _errorMessage = '';
    }
    notifyListeners();
  }
  
  void _setError(String message) {
    _hasError = true;
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  // Join a challenge
  Future<bool> joinChallenge(String challengeId, {bool isPremium = false, double coinCost = 0.0, UserProvider? userProvider}) async {
    if (_participatingChallengeIds.contains(challengeId)) {
      return false; // Already participating
    }
    
    // Check if challenge is expired before allowing join
    final challenge = getChallengeById(challengeId);
    if (challenge != null && challenge.isExpired) {
      _hasError = true;
      _errorMessage = 'This challenge has expired and can no longer be joined';
      notifyListeners();
      return false;
    }
    
    _setLoading(true);
    bool deducted = false;
    try {
      // For premium challenges, check if user has enough coins
      if (isPremium && userProvider != null) {
        final user = userProvider.user;
        if (user == null || user.coins < coinCost) {
          _hasError = true;
          _errorMessage = 'Not enough coins to join this challenge';
          return false;
        }
        // Deduct coins for premium challenge
        await userProvider.addCoins(-coinCost);
        deducted = true;
      }

      // Avoid calling backend with mock (non-UUID) IDs
      if (_supabaseService.isAuthenticated && _isUuid(challengeId)) {
        // Start the challenge in Supabase
        await _supabaseService.startChallenge(challengeId);
      }

      // Add participation locally (for both online and offline)
      _participatingChallengeIds.add(challengeId);

      // Update participants count
      final index = _challenges.indexWhere((challenge) => challenge.id == challengeId);
      if (index != -1) {
        final challenge = _challenges[index];
        _challenges[index] = challenge.copyWith(
          participantsCount: challenge.participantsCount + 1,
        );
      } else {
        // If this is a mock premium challenge not present in provider list, add it so it shows in "My Challenges"
        final mock = ChallengeService.getChallengeById(challengeId);
        if (mock != null) {
          _challenges.add(mock.copyWith(
            participantsCount: mock.participantsCount + 1,
          ));
        }
      }

      // Trigger evaluator for immediate check (best effort)
      try {
        await ChallengeEvaluator.instance.onJoinedChallenge(challengeId);
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('Error joining challenge: $e');
      // Roll back coin deduction if we deducted before failing
      if (deducted && userProvider != null) {
        try {
          await userProvider.addCoins(coinCost);
        } catch (_) {
          // swallow rollback exception but log
          debugPrint('Failed to rollback coins after join failure');
        }
      }
      // Ensure local participation isn't added on failure
      _participatingChallengeIds.remove(challengeId);
      _hasError = true;
      _errorMessage = 'Failed to join challenge';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Leave a challenge
  Future<void> leaveChallenge(String challengeId) async {
    try {
      _setLoading(true);
      
      if (_supabaseService.isAuthenticated) {
        // Update challenge status in Supabase
        await _supabaseService.updateChallengeProgress(challengeId, 0);
      }
      
      _participatingChallengeIds.remove(challengeId);
      _completedChallengeIds.remove(challengeId);
      
      // Update participants count
      final index = _challenges.indexWhere((challenge) => challenge.id == challengeId);
      if (index != -1) {
        final challenge = _challenges[index];
        _challenges[index] = challenge.copyWith(
          // Keep lifetime participant count aligned with server (number of users who have ever joined).
          participantsCount: challenge.participantsCount,
        );
      }
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving challenge: $e');
      _setError('Failed to leave challenge');
    }
  }

  // Check if user is participating in a challenge
  bool isParticipatingIn(String challengeId) {
    return _participatingChallengeIds.contains(challengeId);
  }

  // Add a new challenge - admin function
  Future<void> addChallenge(ChallengeModel challenge) async {
    try {
      _setLoading(true);
      
      if (_supabaseService.isAuthenticated) {
        // This would typically be an admin function
        // For now, we're just updating the local state
      }
      
      _challenges.add(challenge);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding challenge: $e');
      _setError('Failed to add challenge');
    }
  }

  // Update a challenge
  Future<void> updateChallenge(ChallengeModel updatedChallenge) async {
    final index = _challenges.indexWhere((challenge) => challenge.id == updatedChallenge.id);
    if (index != -1) {
      try {
        if (_supabaseService.isAuthenticated) {
          // This would typically be an admin function
          // For now, we're just updating the local state
        }
        
        _challenges[index] = updatedChallenge;
        notifyListeners();
      } catch (e) {
        debugPrint('Error updating challenge: $e');
        _setError('Failed to update challenge');
      }
    }
  }

  // Delete a challenge - admin function
  Future<void> deleteChallenge(String challengeId) async {
    try {
      _setLoading(true);
      
      if (_supabaseService.isAuthenticated) {
        // This would typically be an admin function
        // For now, we're just updating the local state
      }
      
      _challenges.removeWhere((challenge) => challenge.id == challengeId);
      _participatingChallengeIds.remove(challengeId);
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting challenge: $e');
      _setError('Failed to delete challenge');
    }
  }

  // Get challenge by ID
  ChallengeModel? getChallengeById(String challengeId) {
    try {
      return _challenges.firstWhere((challenge) => challenge.id == challengeId);
    } catch (e) {
      // Fallback: in debug builds, also check static/mock premium challenges
      if (kDebugMode) {
        try {
          final mock = ChallengeService.getChallengeById(challengeId);
          return mock;
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }
  
  // Update challenge progress
  Future<void> updateChallengeProgress(String challengeId, int progress, {bool completed = false}) async {
    try {
      if (_supabaseService.isAuthenticated) {
        await _supabaseService.updateChallengeProgress(challengeId, progress);
        
        // If completed, update user points and badges - this would be handled elsewhere
        // For now, we're just updating the progress
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating challenge progress: $e');
      _setError('Failed to update challenge progress');
    }
  }
  
  // Fetch user's progress for a specific challenge
  Future<Map<String, dynamic>?> getChallengeProgress(String challengeId) async {
    try {
      if (_supabaseService.isAuthenticated) {
        // Get user challenge directly from Supabase
        final userChallenges = await _supabaseService.fetchUserChallenges();
        for (var userChallenge in userChallenges) {
          if (userChallenge.challengeId == challengeId) {
            // Convert UserChallengeModel to Map for compatibility
            return {
              'id': userChallenge.id,
              'user_id': userChallenge.userId,
              'challenge_id': userChallenge.challengeId,
              'start_date': userChallenge.startDate.toIso8601String(),
              'end_date': userChallenge.endDate?.toIso8601String(),
              'is_completed': userChallenge.isCompleted,
              'completion_date': userChallenge.completionDate?.toIso8601String(),
              'progress': userChallenge.progress,
            };
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting challenge progress: $e');
      return null;
    }
  }
  
  // Refresh challenges and user participation from Supabase
  Future<void> refreshChallenges() async {
    await initChallenges();
  }
}
import 'package:flutter/foundation.dart';

import '../models/community_model.dart';
import '../services/supabase_service.dart';

/// Provider responsible for loading and managing the user's communities
/// and lightweight community-related operations.
class CommunityProvider extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  final List<CommunityModel> _communities = [];
  bool _isLoading = false;
  String? _lastError;

  List<CommunityModel> get communities => List.unmodifiable(_communities);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  
  /// Returns communities where the user is an active member (not pending invites)
  List<CommunityModel> get activeCommunities => 
      _communities.where((c) => c.isActiveMember).toList();
  
  /// Returns communities where the user has a pending invite
  List<CommunityModel> get pendingInvites => 
      _communities.where((c) => c.hasPendingInvite).toList();

  CommunityModel? getCommunityById(String id) {
    try {
      return _communities.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadMyCommunities() async {
    if (!_supabase.isAuthenticated) return;
    _setLoading(true);
    try {
      final rows = await _supabase.fetchMyCommunities();
      _communities
        ..clear()
        ..addAll(rows.map((r) => CommunityModel.fromJoinedRow(r)));
      _lastError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading communities: $e');
      _lastError = 'Could not load communities. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> requestCommunityCreation({
    required String name,
    String? description,
    String? category,
  }) async {
    if (!_supabase.isAuthenticated) {
      _lastError = 'You must be signed in.';
      notifyListeners();
      return false;
    }

    try {
      final created = await _supabase.requestCommunityCreation(
        name: name,
        description: description,
        category: category,
      );

      // Optimistically add pending community for current user
      if (created != null) {
        final pending = CommunityModel(
          id: created['id'].toString(),
          name: created['name'] as String? ?? name,
          description: created['description'] as String? ?? description,
          category: created['category'] as String? ?? category,
          createdBy: created['created_by'].toString(),
          status: created['status'] as String? ?? 'pending',
          role: 'owner',
        );
        _communities.removeWhere((c) => c.id == pending.id);
        _communities.insert(0, pending);
        notifyListeners();
      }

      _lastError = null;
      return true;
    } catch (e) {
      debugPrint('Error requesting community creation: $e');
      _lastError = 'Could not submit community request. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCommunity(String communityId) async {
    if (!_supabase.isAuthenticated) {
      _lastError = 'You must be signed in.';
      notifyListeners();
      return false;
    }

    try {
      await _supabase.deleteCommunity(communityId);
      _communities.removeWhere((c) => c.id == communityId);
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting community: $e');
      _lastError = 'Could not delete community. Please try again.';
      notifyListeners();
      return false;
    }
  }
  
  /// Accept a pending community invite
  Future<bool> acceptInvite(String communityId) async {
    if (!_supabase.isAuthenticated) {
      _lastError = 'You must be signed in.';
      notifyListeners();
      return false;
    }

    try {
      await _supabase.acceptCommunityInvite(communityId);
      // Update local state
      final index = _communities.indexWhere((c) => c.id == communityId);
      if (index >= 0) {
        _communities[index] = _communities[index].copyWith(membershipStatus: 'active');
      }
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error accepting invite: $e');
      _lastError = 'Could not accept invite. Please try again.';
      notifyListeners();
      return false;
    }
  }
  
  /// Decline a pending community invite
  Future<bool> declineInvite(String communityId) async {
    if (!_supabase.isAuthenticated) {
      _lastError = 'You must be signed in.';
      notifyListeners();
      return false;
    }

    try {
      await _supabase.declineCommunityInvite(communityId);
      // Remove from local state
      _communities.removeWhere((c) => c.id == communityId);
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error declining invite: $e');
      _lastError = 'Could not decline invite. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}

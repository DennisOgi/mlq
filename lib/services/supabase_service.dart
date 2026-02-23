import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

// Lightweight error type for clean, user-facing messages without the 'Exception:' prefix
class UserFacingError implements Exception {
  final String message;
  const UserFacingError(this.message);
  @override
  String toString() => message;
}

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static final uuid = Uuid();

  // Expose instance as a static getter
  static SupabaseService get instance => _instance;

  // Auth state stream controller
  StreamSubscription<AuthState>? _authStateSubscription;

  factory SupabaseService() {
    return _instance;
  }

  // Admin: bulk provision student accounts (no email send). Uses Edge Function 'admin-bulk-provision'.
  // Payload supports EITHER structured students OR free-text roster CSV via rosterText.
  // Returns a list of results with status and temp_password (when created).
  Future<List<Map<String, dynamic>>> adminBulkProvisionStudents({
    String? organizationId,
    String? schoolId,
    List<Map<String, dynamic>>? students,
    String? rosterText,
    bool dryRun = false,
  }) async {
    try {
      // Must be authenticated admin; the Edge Function validates admin via JWT+admin_users
      if (!isAuthenticated) {
        throw const UserFacingError(
            'You must be signed in as an admin to provision students.');
      }

      final payload = <String, dynamic>{
        if (organizationId != null) 'organization_id': organizationId,
        if (schoolId != null) 'school_id': schoolId,
        if (students != null && students.isNotEmpty) 'students': students,
        if ((rosterText ?? '').trim().isNotEmpty) 'roster_text': rosterText,
        'dry_run': dryRun,
      };

      final resp = await client.functions.invoke(
        'admin-bulk-provision',
        body: payload,
      );

      if (resp.data is Map && resp.data['ok'] == true) {
        final results =
            (resp.data['results'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];
        return results;
      }
      final err = (resp.data is Map ? (resp.data['error'] as String?) : null) ??
          'Provisioning failed';
      throw UserFacingError(err);
    } catch (e) {
      debugPrint('Error adminBulkProvisionStudents: $e');
      rethrow;
    }
  }

  // ===== B2B SCHOOL ENTITLEMENTS & INVITATIONS =====
  // Returns { 'is_premium': bool, 'organizations': [uuid, ...] }
  Future<Map<String, dynamic>> fetchEntitlements() async {
    try {
      // Some deployments have both get_entitlements() and get_entitlements(user_uuid uuid)
      // Pass user_uuid explicitly to avoid RPC ambiguity (PGRST203)
      final params = {
        if (currentUser != null) 'user_uuid': currentUser!.id,
      };
      final res = await client.rpc('get_entitlements', params: params);
      if (res is Map<String, dynamic>) return res;
      if (res is List && res.isNotEmpty && res.first is Map<String, dynamic>) {
        return res.first as Map<String, dynamic>;
      }
      return {'is_premium': false, 'organizations': []};
    } catch (e) {
      debugPrint('Error fetching entitlements: $e');
      return {'is_premium': false, 'organizations': []};
    }
  }

  // Admin: run leaderboard notifications job (7-day cooldown)
  Future<Map<String, dynamic>?> adminRunLeaderboardNotifications() async {
    try {
      final res = await client.rpc('run_leaderboard_notifications');
      if (res is Map<String, dynamic>) return res;
      return null;
    } catch (e) {
      debugPrint('Error adminRunLeaderboardNotifications: $e');
      return null;
    }
  }

  // Accept a class code invitation and attach current user to the org
  Future<bool> acceptInvitation(String code) async {
    try {
      final res =
          await client.rpc('accept_invitation', params: {'p_code': code});
      if (res is Map && (res['ok'] == true)) return true;
      return false;
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
      return false;
    }
  }

  // Admin: create school org and active subscription
  Future<Map<String, dynamic>?> adminCreateSchoolOrg({
    required String name,
    required String contactEmail,
    required String planId,
    required int seatLimit,
    List<String>? domainAllowlist,
  }) async {
    try {
      final res = await client.rpc('admin_create_school_org', params: {
        'p_name': name,
        'p_contact_email': contactEmail,
        'p_plan_id': planId,
        'p_seat_limit': seatLimit,
        'p_domain_allowlist': domainAllowlist ?? <String>[],
      });
      if (res is Map<String, dynamic>) return res;
      return null;
    } catch (e) {
      debugPrint('Error adminCreateSchoolOrg: $e');
      return null;
    }
  }

  // Admin: bulk invite emails, returns array of {invitation_id, code}
  Future<List<Map<String, dynamic>>> adminBulkInvite({
    required String organizationId,
    required List<String> emails,
  }) async {
    try {
      final res = await client.rpc('admin_bulk_invite', params: {
        'p_organization_id': organizationId,
        'p_emails': emails,
      });
      if (res is Map && res['ok'] == true) {
        final inv =
            (res['invitations'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];
        return inv;
      }
      return const [];
    } catch (e) {
      debugPrint('Error adminBulkInvite: $e');
      return const [];
    }
  }

  SupabaseService._internal();

  // Supabase client getter
  SupabaseClient get client => Supabase.instance.client;
  static const _host = 'hcvyumbkonrisrxbjnst.supabase.co';
  static const _defaultTimeout = Duration(seconds: 12);

  // Initialize Supabase
  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: 'https://hcvyumbkonrisrxbjnst.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjdnl1bWJrb25yaXNyeGJqbnN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0NTcyOTIsImV4cCI6MjA2NzAzMzI5Mn0.6OS27VWKITYjfF5aKg7BMqxYu2wphh24O26J2-NMoew',
      );

      // Set up auth state listener
      _setupAuthStateListener();

      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }

  // Set up authentication state listener
  void _setupAuthStateListener() {
    _authStateSubscription = client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint('Auth state changed: $event');

      switch (event) {
        case AuthChangeEvent.signedIn:
          debugPrint('User signed in: ${session?.user.email}');
          break;
        case AuthChangeEvent.signedOut:
          debugPrint('User signed out');
          break;
        case AuthChangeEvent.tokenRefreshed:
          debugPrint('Token refreshed for: ${session?.user.email}');
          break;
        case AuthChangeEvent.userUpdated:
          debugPrint('User updated: ${session?.user.email}');
          break;
        case AuthChangeEvent.passwordRecovery:
          debugPrint('Password recovery initiated');
          break;
        default:
          debugPrint('Unknown auth event: $event');
      }
    });
  }

  // Dispose resources
  void dispose() {
    _authStateSubscription?.cancel();
  }

  // Input sanitization and validation
  String _sanitizeInput(String input) {
    // Remove potentially dangerous characters
    return input.replaceAll(RegExp(r'[<>"\;]'), '').trim();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    // At least 8 characters, contains letter and number
    return password.length >= 8 &&
        RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password);
  }

  bool _isValidAge(int age) {
    return age >= 7;
  }

  // Get current authenticated user
  User? get currentUser => client.auth.currentUser;

  // Fetch current user with fresh data from server
  Future<UserModel?> fetchCurrentUser() async {
    try {
      if (!isAuthenticated) return null;

      final userId = currentUser!.id;
      final response =
          await client.from('profiles').select().eq('id', userId).single();

      // Check if user is admin
      final isAdmin = await _checkIfUserIsAdmin(userId);

      return _mapToUserModel(response, isAdmin: isAdmin);
    } catch (e) {
      debugPrint('Error fetching current user: $e');
      return null;
    }
  }

  // Fetch leaderboard users from Supabase
  Future<List<UserModel>> fetchLeaderboardUsers() async {
    try {
      if (!isAuthenticated) return [];

      final response = await client
          .from('profiles')
          .select()
          .order('monthly_xp', ascending: false)
          .limit(20);

      final users = <UserModel>[];
      for (final userData in response) {
        // For performance reasons, we don't check admin status for all leaderboard users
        // Admin status is only important for the current user's profile
        users.add(_mapToUserModel(userData));
      }

      debugPrint('Fetched ${users.length} users for leaderboard');
      return users;
    } catch (e) {
      debugPrint('Error fetching leaderboard users: $e');
      return [];
    }
  }

  // Fetch active schools (for registration/profile dropdowns)
  Future<List<Map<String, dynamic>>> fetchSchools() async {
    try {
      final rows = await client
          .from('schools')
          .select('id, name, city, country')
          .eq('active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('Error fetching schools: $e');
      return [];
    }
  }

  // Update the current user's school assignment
  Future<bool> updateUserSchool({String? schoolId, String? schoolName}) async {
    try {
      if (currentUser == null) return false;
      final updates = {
        'school_id': schoolId,
        'school_name': schoolName,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client.from('profiles').update(updates).eq('id', currentUser!.id);
      return true;
    } catch (e) {
      debugPrint('Error updating user school: $e');
      return false;
    }
  }

  // Fetch school leaderboard via RPC, returns top N plus current user's exact rank
  Future<List<UserModel>> fetchSchoolLeaderboard(
      {required String schoolId, int limit = 20}) async {
    try {
      if (!isAuthenticated) return [];
      final uid = currentUser!.id;
      final rows = await client.rpc('get_school_leaderboard', params: {
        'p_school_id': schoolId,
        'p_limit': limit,
        'p_user_id': uid,
      });

      final List<UserModel> users = [];
      for (final r in rows as List) {
        // Note: RPC returns 'xp' which is actually monthly_xp (see get_school_leaderboard definition)
        final monthlyXpValue = (r['xp'] as num?)?.toInt() ?? 0;
        final u = UserModel(
          id: r['id'],
          name: r['name'],
          age: (r['age'] as num?)?.toInt() ?? 0,
          avatarUrl: r['avatar_url'],
          xp: monthlyXpValue, // For backward compatibility
          monthlyXp:
              monthlyXpValue, // This is what the leaderboard actually displays
          coins: 0,
          badges: const [],
          interests: const [],
          email: null,
          parentEmail: null,
          weeklyReportsEnabled: false,
          isPremium: r['is_premium'] as bool? ?? false,
          isAdmin: false,
          timezone: null,
          preferredSendDow: null,
          preferredSendHour: null,
          preferredSendMinute: null,
          schoolId: r['school_id'],
          schoolName: r['school_name'] as String?,
          rank: (r['rank'] as num?)?.toInt(),
        );
        // Avoid duplicates if current user appears in topN and me
        if (!users.any((e) => e.id == u.id)) users.add(u);
      }
      // Defensive client-side filter: ensure only requested school members appear
      final filtered = users.where((u) => u.schoolId == schoolId).toList();
      if (filtered.length != users.length) {
        debugPrint(
            'fetchSchoolLeaderboard: filtered out ${(users.length - filtered.length)} non-matching school users');
      }
      return filtered
        ..sort((a, b) => (a.rank ?? 1 << 30).compareTo(b.rank ?? 1 << 30));
    } catch (e) {
      debugPrint('Error fetching school leaderboard: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyCommunities() async {
    try {
      if (!isAuthenticated) return [];
      final uid = currentUser!.id;

      // Fetch communities where user is a member
      final memberResponse = await client
          .from('community_members')
          .select(
              'community_id, role, status, communities (id, name, description, category, created_by, status, created_at)')
          .eq('user_id', uid)
          .neq('status', 'removed');

      final rows = List<Map<String, dynamic>>.from(memberResponse as List);

      // Also fetch communities the user created (even if not yet a member - e.g., pending approval)
      final createdResponse = await client
          .from('communities')
          .select(
              'id, name, description, category, created_by, status, created_at')
          .eq('created_by', uid);

      // Add created communities that aren't already in the member list
      final existingIds = rows.map((r) {
        final c = r['communities'] as Map<String, dynamic>?;
        return c?['id']?.toString();
      }).toSet();

      for (final community in (createdResponse as List)) {
        final communityMap = Map<String, dynamic>.from(community);
        if (!existingIds.contains(communityMap['id']?.toString())) {
          // Format as joined row structure for consistency
          rows.add({
            'community_id': communityMap['id'],
            'role': 'owner',
            'status': 'active',
            'communities': communityMap,
          });
        }
      }

      DateTime _parseCreatedAt(Map<String, dynamic> row) {
        try {
          final communities = row['communities'] as Map<String, dynamic>?;
          final raw = communities?['created_at'];
          if (raw is String && raw.isNotEmpty) {
            return DateTime.parse(raw);
          }
        } catch (_) {}
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      rows.sort((a, b) => _parseCreatedAt(b).compareTo(_parseCreatedAt(a)));
      debugPrint('Fetched ${rows.length} communities for user');
      return rows;
    } catch (e) {
      debugPrint('Error fetching communities: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> requestCommunityCreation({
    required String name,
    String? description,
    String? category,
  }) async {
    try {
      if (!isAuthenticated) {
        throw const UserFacingError(
            'You must be signed in to create a community.');
      }

      final sanitizedName = _sanitizeInput(name);
      if (sanitizedName.isEmpty) {
        throw const UserFacingError('Please enter a community name.');
      }

      final data = <String, dynamic>{
        'name': sanitizedName,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        'created_by': currentUser!.id,
      };

      final response =
          await client.from('communities').insert(data).select().single();

      return Map<String, dynamic>.from(response as Map);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('row-level security') || msg.contains('rls')) {
        throw const UserFacingError(
            'You need a premium subscription to create a community.');
      }
      debugPrint('PostgrestException during community creation: ${e.message}');
      throw const UserFacingError(
          'Could not create community right now. Please try again.');
    } on UserFacingError {
      rethrow;
    } catch (e) {
      debugPrint('Error creating community: $e');
      throw const UserFacingError(
          'Could not create community right now. Please try again.');
    }
  }

  /// Delete a community owned by the current user
  Future<void> deleteCommunity(String communityId) async {
    try {
      if (!isAuthenticated) {
        throw const UserFacingError(
            'You must be signed in to delete a community.');
      }

      final uid = currentUser!.id;

      // Verify that the community exists and is owned by the current user
      final community = await client
          .from('communities')
          .select('id, created_by')
          .eq('id', communityId)
          .maybeSingle();

      if (community == null) {
        throw const UserFacingError('Community not found.');
      }

      if (community['created_by'] != uid) {
        throw const UserFacingError(
            'Only the community owner can delete this community.');
      }

      await client.from('communities').delete().eq('id', communityId);
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException during community deletion: ${e.message}');
      throw const UserFacingError(
          'Could not delete community right now. Please try again.');
    } on UserFacingError {
      rethrow;
    } catch (e) {
      debugPrint('Error deleting community: $e');
      throw const UserFacingError(
          'Could not delete community right now. Please try again.');
    }
  }

  /// Accept a pending community invite for the current user
  Future<void> acceptCommunityInvite(String communityId) async {
    try {
      if (!isAuthenticated) {
        throw const UserFacingError(
            'You must be signed in to accept an invite.');
      }

      final userId = currentUser!.id;

      // Update membership status from 'pending' to 'active'
      await client
          .from('community_members')
          .update({
            'status': 'active',
            'joined_at': DateTime.now().toIso8601String(),
          })
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .eq('status', 'pending');

      debugPrint('Community invite accepted for community $communityId');
    } catch (e) {
      debugPrint('Error accepting community invite: $e');
      if (e is UserFacingError) rethrow;
      throw const UserFacingError(
          'Could not accept invite right now. Please try again.');
    }
  }

  /// Decline a pending community invite for the current user
  Future<void> declineCommunityInvite(String communityId) async {
    try {
      if (!isAuthenticated) {
        throw const UserFacingError(
            'You must be signed in to decline an invite.');
      }

      final userId = currentUser!.id;

      // Delete the pending membership record
      await client
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .eq('status', 'pending');

      debugPrint('Community invite declined for community $communityId');
    } catch (e) {
      debugPrint('Error declining community invite: $e');
      if (e is UserFacingError) rethrow;
      throw const UserFacingError(
          'Could not decline invite right now. Please try again.');
    }
  }

  // This method has been replaced with _mapToUserModel for consistent user model mapping
  // See _mapToUserModel method below

  // Check if user is authenticated
  bool get isAuthenticated {
    final user = client.auth.currentUser;
    final isAuth = user != null;
    debugPrint(
        'isAuthenticated check: user ${isAuth ? "exists" : "is null"} (${user?.email ?? "no email"}) - session: ${client.auth.currentSession != null ? "exists" : "is null"}');
    return isAuth;
  }

  // Check if a user is an admin
  Future<bool> _checkIfUserIsAdmin(String userId) async {
    try {
      final adminRows = await client
          .from('admin_users')
          .select('user_id')
          .eq('user_id', userId);
      return adminRows.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required int age,
    String? parentEmail,
  }) async {
    try {
      // Quick connectivity preflight (DNS/host reachability) - with longer timeout
      try {
        final result = await InternetAddress.lookup(_host)
            .timeout(const Duration(seconds: 8));
        if (result.isEmpty) {
          throw const SocketException('DNS lookup returned no results');
        }
      } on TimeoutException catch (_) {
        debugPrint(
            'DNS lookup timeout - network may be slow but continuing with signup attempt');
        // Don't throw here, let the actual signup attempt handle network issues
      } on SocketException catch (e) {
        debugPrint(
            'DNS lookup failed: ${e.message} - continuing with signup attempt');
        // Don't throw here, let the actual signup attempt handle network issues
      }

      // Validate inputs
      if (!_isValidEmail(email)) {
        throw const UserFacingError('Please enter a valid email address.');
      }

      if (!_isValidPassword(password)) {
        throw const UserFacingError(
            'Password must be at least 8 characters and include letters and numbers.');
      }

      if (!_isValidAge(age)) {
        throw const UserFacingError('Age must be 7 years or older.');
      }

      if (parentEmail != null && !_isValidEmail(parentEmail)) {
        throw const UserFacingError(
            'Please enter a valid parent email address.');
      }

      // Sanitize inputs
      final sanitizedName = _sanitizeInput(name);
      final sanitizedEmail = email.toLowerCase().trim();
      final sanitizedParentEmail = parentEmail?.toLowerCase().trim();

      if (sanitizedName.isEmpty) {
        throw const UserFacingError('Name cannot be empty.');
      }

      Future<AuthResponse> _doSignup() => client.auth.signUp(
            email: sanitizedEmail,
            password: password,
            data: {
              'name': sanitizedName,
              'age': age,
              'parent_email': sanitizedParentEmail,
            },
          ).timeout(
              const Duration(seconds: 20)); // Increased timeout for signup

      AuthResponse response;
      try {
        debugPrint('Attempting signup for: $sanitizedEmail');
        response = await _doSignup();
        debugPrint(
            'Signup response received: ${response.user?.id != null ? "Success" : "Failed"}');
      } on TimeoutException {
        debugPrint('Signup timeout, retrying once...');
        // retry once on timeout with longer delay
        await Future.delayed(const Duration(seconds: 2));
        response = await _doSignup();
        debugPrint(
            'Retry signup response: ${response.user?.id != null ? "Success" : "Failed"}');
      }

      debugPrint('User signed up successfully: $sanitizedEmail');
      return response;
    } on AuthException catch (e) {
      final raw = e.message.trim();
      final msg = raw.isNotEmpty
          ? raw
          : 'We couldn\'t create your account. Please try again.';
      debugPrint('AuthException during sign up: $msg');
      throw UserFacingError(msg);
    } on PostgrestException catch (e) {
      final msg = e.message.isNotEmpty
          ? e.message
          : 'A server error occurred while creating your account.';
      debugPrint('PostgrestException during sign up: $msg');
      throw UserFacingError(
          'We couldn\'t create your account right now. Please try again shortly.');
    } on TimeoutException {
      debugPrint('Timeout during sign up');
      throw const UserFacingError(
          'Taking longer than usual. Please try again in a moment.');
    } on SocketException catch (e) {
      debugPrint('SocketException during sign up: ${e.message}');
      throw const UserFacingError(
          "You're offline. Please check your internet connection and try again.");
    } catch (e) {
      debugPrint('Error signing up: $e');
      throw const UserFacingError(
          'Something went wrong while creating your account. Please try again.');
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Connectivity preflight
      try {
        final result = await InternetAddress.lookup(_host)
            .timeout(const Duration(seconds: 3));
        if (result.isEmpty) {
          throw const SocketException('DNS lookup returned no results');
        }
      } on TimeoutException catch (_) {
        throw Exception(
            'Connection timed out while reaching the server. Please check your internet and try again.');
      } on SocketException catch (e) {
        throw Exception(
            'Cannot reach authentication server. Check your internet connection. Details: ${e.message}');
      }

      Future<AuthResponse> _doSignin() => client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_defaultTimeout);

      AuthResponse response;
      try {
        response = await _doSignin();
      } on TimeoutException {
        await Future.delayed(const Duration(seconds: 1));
        response = await _doSignin();
      }
      return response;
    } on AuthException catch (e) {
      // Hide raw backend phrasing; present concise message for common cases
      final raw = e.message.toLowerCase();
      String msg = 'We couldn\'t sign you in. Please try again.';
      if (raw.contains('invalid login') ||
          raw.contains('invalid') ||
          raw.contains('email') ||
          raw.contains('password')) {
        msg = 'Incorrect email or password. Please try again.';
      }
      debugPrint('AuthException during sign in: ${e.message}');
      throw UserFacingError(msg);
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException during sign in: ${e.message}');
      throw const UserFacingError(
          'We couldn\'t connect right now. Please try again shortly.');
    } on TimeoutException {
      debugPrint('Timeout during sign in');
      throw const UserFacingError(
          'Taking longer than usual. Please try again in a moment.');
    } on SocketException catch (e) {
      debugPrint('SocketException during sign in: ${e.message}');
      throw const UserFacingError(
          "You're offline. Please check your internet connection and try again.");
    } catch (e) {
      debugPrint('Error signing in: $e');
      throw const UserFacingError(
          'We couldn\'t sign you in. Please try again.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear Remember Me credentials before signing out
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remembered_email');
      await prefs.remove('remembered_password');
      await prefs.setBool('remember_me', false);
      await prefs.setBool('just_logged_out', true); // Flag to skip auto-login

      await client.auth.signOut();
      debugPrint('User signed out and Remember Me credentials cleared');
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://your-app.com/reset-password', // Configure this URL
      );
      debugPrint('Password reset email sent to: $email');
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Resend email confirmation
  Future<void> resendEmailConfirmation(String email) async {
    try {
      await client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      debugPrint('Email confirmation resent to: $email');
    } catch (e) {
      debugPrint('Error resending email confirmation: $e');
      rethrow;
    }
  }

  // Update password (for authenticated users)
  Future<void> updatePassword(String newPassword) async {
    try {
      // Ensure user is signed in
      if (currentUser == null) {
        throw const UserFacingError(
          'You need to be signed in to change your password.',
        );
      }

      // Validate password with the same rules as sign up
      if (!_isValidPassword(newPassword)) {
        throw const UserFacingError(
          'Password must be at least 8 characters and include both letters and numbers.',
        );
      }

      // Lightweight connectivity preflight (similar to signIn)
      try {
        final result = await InternetAddress.lookup(_host)
            .timeout(const Duration(seconds: 3));
        if (result.isEmpty) {
          throw const SocketException('DNS lookup returned no results');
        }
      } on TimeoutException catch (_) {
        throw const UserFacingError(
          'Connection timed out while reaching the server. Please check your internet and try again.',
        );
      } on SocketException catch (_) {
        throw const UserFacingError(
          "You're offline. Please check your internet connection and try again.",
        );
      }

      // Perform password update with timeout protection
      await client.auth
          .updateUser(UserAttributes(password: newPassword))
          .timeout(_defaultTimeout);

      debugPrint('Password updated successfully');
    } on AuthException catch (e) {
      final raw = e.message.trim();
      final lower = raw.toLowerCase();

      // Map low-level handshake / TLS errors to a friendly connectivity message
      if (lower.contains('handshake') ||
          lower.contains('retryablefetchexception')) {
        debugPrint('AuthException during password update (handshake): $raw');
        throw const UserFacingError(
          'We could not reach the server securely. Please check your internet connection and try again.',
        );
      }

      final msg = raw.isNotEmpty
          ? raw
          : 'We could not change your password. Please try again.';
      debugPrint('AuthException during password update: $raw');
      throw UserFacingError(msg);
    } on TimeoutException {
      debugPrint('Timeout during password update');
      throw const UserFacingError(
        'Taking longer than usual. Please try again in a moment.',
      );
    } on SocketException catch (e) {
      debugPrint('SocketException during password update: ${e.message}');
      throw const UserFacingError(
        "You're offline. Please check your internet connection and try again.",
      );
    } on UserFacingError {
      // Re-throw clean, user-facing errors as-is
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating password: $e');
      throw const UserFacingError(
        'Something went wrong while changing your password. Please try again.',
      );
    }
  }

  // Get user profile (with optional admin status check)
  Future<UserModel?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      final response = await client
          .from('profiles')
          .select('*')
          .eq('id', currentUser!.id)
          .single();

      // Determine if user is an admin
      final isAdmin = await _checkIfUserIsAdmin(currentUser!.id);

      return _mapToUserModel(response, isAdmin: isAdmin);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    int? age,
    String? avatarUrl,
    List<String>? interests,
    String? parentEmail,
    bool? weeklyReportsEnabled,
    String? timezone,
    int? preferredSendDow,
    int? preferredSendHour,
    int? preferredSendMinute,
  }) async {
    try {
      if (currentUser == null) return;

      final updates = {
        if (name != null) 'name': name,
        if (age != null) 'age': age,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (interests != null) 'interests': interests,
        if (parentEmail != null) 'parent_email': parentEmail,
        if (weeklyReportsEnabled != null)
          'weekly_reports_enabled': weeklyReportsEnabled,
        if (timezone != null) 'timezone': timezone,
        if (preferredSendDow != null) 'preferred_send_dow': preferredSendDow,
        if (preferredSendHour != null) 'preferred_send_hour': preferredSendHour,
        if (preferredSendMinute != null)
          'preferred_send_minute': preferredSendMinute,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client.from('profiles').update(updates).eq('id', currentUser!.id);
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  // Add coins to user with optional metadata for transaction audit
  Future<bool> addCoins(
    double amount, {
    String description = 'Coin award',
    String transactionType = 'reward',
    String referenceType = 'system',
    String? referenceId,
  }) async {
    try {
      if (currentUser == null) return false;

      // First get current coins
      final response = await client
          .from('profiles')
          .select('coins')
          .eq('id', currentUser!.id)
          .single();

      final currentCoins = (response['coins'] as num).toDouble();
      final newCoins = currentCoins + amount;

      await client
          .from('profiles')
          .update({'coins': newCoins}).eq('id', currentUser!.id);

      // Log this coin award for tracking purposes
      await client.from('coin_transactions').insert({
        'user_id': currentUser!.id,
        'amount': amount,
        'balance_after': newCoins,
        'description': description,
        'transaction_type': transactionType,
        'reference_type': referenceType,
        if (referenceId != null) 'reference_id': referenceId,
      });

      debugPrint(
          'Added $amount coins to user ${currentUser!.id}. New total: $newCoins');
      return true;
    } catch (e) {
      debugPrint('Error adding coins: $e');
      return false;
    }
  }

  // Spend coins
  Future<bool> spendCoins(double amount) async {
    try {
      if (currentUser == null) return false;

      // First get current coins
      final response = await client
          .from('profiles')
          .select('coins')
          .eq('id', currentUser!.id)
          .single();

      final currentCoins = (response['coins'] as num).toDouble();

      // Check if user has enough coins
      if (currentCoins < amount) return false;

      final newCoins = currentCoins - amount;

      await client
          .from('profiles')
          .update({'coins': newCoins}).eq('id', currentUser!.id);

      return true;
    } catch (e) {
      debugPrint('Error spending coins: $e');
      return false;
    }
  }

  // Add XP to user
  Future<void> addXp(int amount) async {
    try {
      if (currentUser == null) return;

      // Add XP to the current logged-in user
      await addXpToUser(currentUser!.id, amount);
    } catch (e) {
      debugPrint('Error adding XP: $e');
      rethrow;
    }
  }

  // Add XP to any user by ID (for admin use)
  // Updates both lifetime XP and monthly XP for leaderboard ranking
  Future<bool> addXpToUser(String userId, int amount) async {
    try {
      debugPrint('Adding $amount XP to user $userId');

      // First get current XP and monthly XP
      final response = await client
          .from('profiles')
          .select('xp, monthly_xp')
          .eq('id', userId)
          .single();

      debugPrint('Current XP response: $response');
      final currentXp = (response['xp'] as num?)?.toInt() ?? 0;
      final currentMonthlyXp = (response['monthly_xp'] as num?)?.toInt() ?? 0;
      final newXp = currentXp + amount;
      final newMonthlyXp = currentMonthlyXp + amount;
      debugPrint(
          'Current XP: $currentXp, Monthly XP: $currentMonthlyXp, Adding: $amount');

      // Update both xp (lifetime) and monthly_xp (for monthly leaderboard)
      await client.from('profiles').update({
        'xp': newXp,
        'monthly_xp': newMonthlyXp,
      }).eq('id', userId);

      debugPrint(
          '✅ XP updated successfully: xp $currentXp → $newXp, monthly_xp $currentMonthlyXp → $newMonthlyXp (+$amount)');

      return true;
    } catch (e) {
      debugPrint('Error adding XP to user $userId: $e');
      return false;
    }
  }

  // This duplicate method has been removed and merged with the original addCoins method above

  // Add a badge
  Future<void> addBadge(String badge) async {
    try {
      if (currentUser == null) return;

      // First get current badges
      final response = await client
          .from('profiles')
          .select('badges')
          .eq('id', currentUser!.id)
          .single();

      final currentBadges = List<String>.from(response['badges'] ?? []);

      // Check if badge already exists
      if (currentBadges.contains(badge)) return;

      currentBadges.add(badge);

      await client
          .from('profiles')
          .update({'badges': currentBadges}).eq('id', currentUser!.id);
    } catch (e) {
      debugPrint('Error adding badge: $e');
      rethrow;
    }
  }

  // Save a main goal to Supabase
  Future<MainGoalModel> saveMainGoal(MainGoalModel goal) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      // Convert goal to JSON
      final goalJson = goal.toJson();

      // Remove the temporary ID so Supabase can generate a UUID
      if (goal.id.startsWith('temp_')) {
        goalJson.remove('id');
      }
      // Ensure user scoping uses correct snake_case column
      goalJson['user_id'] = currentUser!.id;

      // Insert goal into main_goals table and return the inserted record
      final response =
          await client.from('main_goals').insert(goalJson).select().single();

      // Parse the response to get the updated goal with the UUID
      final updatedGoal = MainGoalModel.fromJson(response);
      debugPrint('Main goal saved successfully with ID: ${updatedGoal.id}');

      return updatedGoal;
    } catch (e) {
      debugPrint('Error saving main goal: $e');
      rethrow;
    }
  }

  // Update a main goal in Supabase
  Future<MainGoalModel> updateMainGoal(MainGoalModel goal) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      // Convert goal to JSON
      final goalJson = goal.toJson();
      // Maintain correct user scoping column
      goalJson['user_id'] = currentUser!.id;

      // Update goal in main_goals table and return the updated record
      final response = await client
          .from('main_goals')
          .update(goalJson)
          .eq('id', goal.id)
          .select()
          .single();

      // Parse the response to get the updated goal
      final updatedGoal = MainGoalModel.fromJson(response);
      debugPrint('Main goal updated successfully: ${updatedGoal.id}');

      return updatedGoal;
    } catch (e) {
      debugPrint('Error updating main goal: $e');
      rethrow;
    }
  }

  // Delete main goal from Supabase
  Future<void> deleteMainGoal(String goalId) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      // Skip if this is a temporary goal not yet in Supabase
      if (goalId.startsWith('temp_')) return;

      await client.from('main_goals').delete().eq('id', goalId).eq('user_id',
          currentUser!.id); // Ensure user can only delete their own goals

      debugPrint('Main goal deleted successfully: $goalId');
    } catch (e) {
      debugPrint('Error deleting main goal: $e');
      rethrow;
    }
  }

  // Fetch all main goals for current user
  Future<List<MainGoalModel>> fetchMainGoals() async {
    try {
      if (currentUser == null) return [];

      final response = await client
          .from('main_goals')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false);

      // Supabase returns a List of dynamic maps
      final List<MainGoalModel> goals = [];

      // Process the response
      try {
        for (var item in response as List) {
          try {
            goals.add(MainGoalModel.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('Error parsing goal: $e');
          }
        }
      } catch (e) {
        debugPrint('Error processing response: $e');
      }

      return goals;
    } catch (e) {
      debugPrint('Error fetching main goals: $e');
      return [];
    }
  }

  // Save daily goal to Supabase
  Future<DailyGoalModel> saveDailyGoal(DailyGoalModel goal) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      // Convert goal to JSON format
      final goalJson = goal.toJson();

      // Remove the ID if it's temporary or not a valid UUID format
      if (goal.id.startsWith('temp_') || !_isValidUuid(goal.id)) {
        goalJson.remove('id');
      }

      // Make sure user_id is set to the current user
      goalJson['user_id'] = currentUser!.id;

      // Insert goal into daily_goals table
      final response =
          await client.from('daily_goals').insert(goalJson).select().single();

      // Map the response back to our model
      final updatedGoal = DailyGoalModel(
        id: response['id'],
        userId: response['user_id'],
        title: response['title'],
        date: DateTime.parse(response['date']),
        isCompleted: response['is_completed'],
        mainGoalId: response['main_goal_id'],
        xpValue: response['xp_value'],
      );

      debugPrint('Daily goal saved successfully with ID: ${updatedGoal.id}');
      return updatedGoal;
    } catch (e) {
      debugPrint('Error saving daily goal: $e');
      rethrow;
    }
  }

  // Update daily goal in Supabase
  Future<DailyGoalModel> updateDailyGoal(DailyGoalModel goal) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      // Skip if this is a temporary goal not yet in Supabase
      if (goal.id.startsWith('temp_')) {
        return goal;
      }

      // Prepare the update data
      final updateData = {
        'title': goal.title,
        'date': goal.date.toIso8601String(),
        'is_completed': goal.isCompleted,
        'xp_value': goal.xpValue,
        'main_goal_id': goal.mainGoalId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update the goal
      final response = await client
          .from('daily_goals')
          .update(updateData)
          .eq('id', goal.id)
          .select()
          .single();

      // Map the response back to our model
      final updatedGoal = DailyGoalModel(
        id: response['id'],
        userId: response['user_id'],
        title: response['title'],
        date: DateTime.parse(response['date']),
        isCompleted: response['is_completed'],
        mainGoalId: response['main_goal_id'],
        xpValue: response['xp_value'],
      );

      debugPrint('Daily goal updated successfully: ${updatedGoal.id}');
      return updatedGoal;
    } catch (e) {
      debugPrint('Error updating daily goal: $e');
      rethrow;
    }
  }

  // Delete daily goal from Supabase
  Future<void> deleteDailyGoal(String goalId) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      // Skip if this is a temporary goal not yet in Supabase
      if (goalId.startsWith('temp_')) return;

      await client.from('daily_goals').delete().eq('id', goalId);

      debugPrint('Daily goal deleted successfully: $goalId');
    } catch (e) {
      debugPrint('Error deleting daily goal: $e');
      rethrow;
    }
  }

  // Fetch all daily goals for current user
  Future<List<DailyGoalModel>> fetchDailyGoals() async {
    try {
      if (currentUser == null) return [];

      final response = await client
          .from('daily_goals')
          .select()
          .eq('user_id', currentUser!.id)
          .order('date', ascending: false);

      final List<DailyGoalModel> goals = [];

      try {
        for (var item in response as List) {
          try {
            goals.add(DailyGoalModel(
              id: item['id'],
              userId: item['user_id'],
              title: item['title'],
              date: DateTime.parse(item['date']),
              isCompleted: item['is_completed'] ?? false,
              mainGoalId: item['main_goal_id'],
              xpValue: item['xp_value'] ?? 10,
            ));
          } catch (e) {
            debugPrint('Error parsing daily goal: $e');
          }
        }
      } catch (e) {
        debugPrint('Error processing daily goals response: $e');
      }

      return goals;
    } catch (e) {
      debugPrint('Error fetching daily goals: $e');
      return [];
    }
  }

  // CHALLENGE SYSTEM METHODS

  // Fetch all challenges (excludes expired challenges)
  Future<List<ChallengeModel>> fetchChallenges() async {
    try {
      // Select relational count of participants from user_challenges
      // Filter out expired challenges (end_date must be in the future)
      final response = await client
          .from('challenges')
          .select('*, user_challenges(count)')
          .gte('end_date', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final List<ChallengeModel> challenges = [];

      try {
        for (var item in response as List) {
          try {
            // Map relational count into participants_count for our model
            final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
            int participants = 0;
            try {
              final uc = map['user_challenges'] as List?;
              if (uc != null && uc.isNotEmpty) {
                final count = (uc.first['count'] as num?)?.toInt();
                if (count != null) participants = count;
              }
            } catch (_) {}
            map['participants_count'] = participants;

            challenges.add(ChallengeModel.fromJson(map));
          } catch (e) {
            debugPrint('Error parsing challenge: $e');
          }
        }
      } catch (e) {
        debugPrint('Error processing challenges response: $e');
      }

      return challenges;
    } catch (e) {
      debugPrint('Error fetching challenges: $e');
      return [];
    }
  }

  // Fetch user's active challenges
  Future<List<UserChallengeModel>> fetchUserChallenges() async {
    try {
      if (currentUser == null) return [];

      final response = await client
          .from('user_challenges')
          .select('*, challenge:challenge_id(*)')
          .eq('user_id', currentUser!.id);

      final List<UserChallengeModel> userChallenges = [];

      try {
        for (var item in response as List) {
          try {
            final challengeData = item['challenge'] as Map<String, dynamic>;
            final challenge = ChallengeModel.fromJson(challengeData);

            userChallenges.add(UserChallengeModel(
              id: item['id'],
              userId: item['user_id'],
              challengeId: challengeData['id'],
              challenge: challenge,
              startDate: DateTime.parse(item['start_date']),
              endDate: item['end_date'] != null
                  ? DateTime.parse(item['end_date'])
                  : null,
              isCompleted: item['is_completed'] ?? false,
              completionDate: item['completion_date'] != null
                  ? DateTime.parse(item['completion_date'])
                  : null,
              progress: item['progress'] ?? 0,
            ));
          } catch (e) {
            debugPrint('Error parsing user challenge: $e');
          }
        }
      } catch (e) {
        debugPrint('Error processing user challenges response: $e');
      }

      return userChallenges;
    } catch (e) {
      debugPrint('Error fetching user challenges: $e');
      return [];
    }
  }

  // Start a challenge
  Future<UserChallengeModel> startChallenge(String challengeId) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      // First get the challenge details
      final challengeResponse = await client
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .single();

      final challenge =
          ChallengeModel.fromJson(Map<String, dynamic>.from(challengeResponse));

      // Use challenge dates
      final startDate = DateTime.now();
      final endDate = challenge.endDate;

      // If it's a premium challenge, spend coins
      if (challenge.isPremium && challenge.coinsCost > 0) {
        await spendCoins(challenge.coinsCost.toDouble());
      }

      // Insert or reset (upsert) into user_challenges. This allows re-join after leaving
      final userChallengeData = {
        'user_id': currentUser!.id,
        'challenge_id': challengeId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'progress': 0,
        'is_completed': false,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert on (user_id, challenge_id) to handle rejoin without unique violation
      final response = await client
          .from('user_challenges')
          .upsert(userChallengeData, onConflict: 'user_id,challenge_id')
          .select()
          .single();

      final userChallenge = UserChallengeModel(
        id: response['id'],
        userId: response['user_id'],
        challengeId: challengeId,
        challenge: challenge,
        startDate: DateTime.parse(response['start_date']),
        endDate: DateTime.parse(response['end_date']),
        isCompleted: response['is_completed'] ?? false,
        progress: response['progress'] ?? 0,
      );

      debugPrint('Challenge started: ${challenge.title}');
      return userChallenge;
    } catch (e) {
      debugPrint('Error starting challenge: $e');
      rethrow;
    }
  }

  // Update challenge progress
  Future<UserChallengeModel> updateChallengeProgress(
      String challengeId, int progress) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      // Find the user challenge record
      final userChallengeResponse = await client
          .from('user_challenges')
          .select('*, challenges(*)')
          .eq('user_id', currentUser!.id)
          .eq('challenge_id', challengeId)
          .single();

      // Check if the challenge is already completed
      if (userChallengeResponse['is_completed'] == true) {
        throw Exception('Challenge already completed');
      }

      // Update the progress
      final updateData = {
        'progress': progress,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if challenge is completed now
      if (progress >= 100) {
        updateData['is_completed'] = true;
        updateData['completion_date'] = DateTime.now().toIso8601String();
      }

      final response = await client
          .from('user_challenges')
          .update(updateData)
          .eq('id', userChallengeResponse['id'])
          .select('*, challenges(*)')
          .single();

      // Process reward if the challenge was just completed
      if (progress >= 100 && userChallengeResponse['is_completed'] == false) {
        // Get challenge details
        final challengeData = response['challenges'] as Map<String, dynamic>;

        // Add XP to user (only if xp_reward > 0)
        // FIX: Previously used coin_reward which caused XP inflation
        final xpReward = (challengeData['xp_reward'] as num?)?.toInt() ?? 0;
        if (xpReward > 0) {
          await addXp(xpReward);
        }

        // Add coin reward
        await addCoins(
            (challengeData['coin_reward'] as num?)?.toDouble() ?? 50.0);
      }

      // Map to user challenge model
      final challengeData = response['challenges'] as Map<String, dynamic>;
      final challenge = ChallengeModel(
        id: challengeData['id'],
        title: challengeData['title'],
        description: challengeData['description'],
        type: (challengeData['is_premium'] ?? false)
            ? ChallengeType.premium
            : ChallengeType.basic,
        realWorldPrize: challengeData['real_world_prize'],
        startDate: DateTime.parse(
            challengeData['start_date'] ?? DateTime.now().toIso8601String()),
        endDate: DateTime.parse(challengeData['end_date'] ??
            DateTime.now().add(Duration(days: 30)).toIso8601String()),
        participantsCount: challengeData['participants_count'] ?? 0,
        organizationId: challengeData['organization_id'] ?? 'default',
        organizationName: challengeData['organization_name'] ?? 'MLQ',
        organizationLogo: challengeData['organization_logo'] ??
            'assets/images/sponsors/default_logo.png',
        criteria: List<String>.from(
            challengeData['criteria'] ?? ['Complete the challenge']),
        timeline: challengeData['timeline'] ?? '30 days',
        isTeamChallenge: challengeData['is_team_challenge'] ?? false,
        coinReward: challengeData['coin_reward'] ?? 50,
        xpReward: (challengeData['xp_reward'] as num?)?.toInt() ?? 0,
      );

      final userChallenge = UserChallengeModel(
        id: response['id'],
        userId: response['user_id'],
        challengeId: challengeData['id'],
        challenge: challenge,
        startDate: DateTime.parse(response['start_date']),
        endDate: response['end_date'] != null
            ? DateTime.parse(response['end_date'])
            : null,
        isCompleted: response['is_completed'] ?? false,
        completionDate: response['completion_date'] != null
            ? DateTime.parse(response['completion_date'])
            : null,
        progress: response['progress'] ?? 0,
      );

      debugPrint('Challenge progress updated: ${challenge.title} - $progress%');
      return userChallenge;
    } catch (e) {
      debugPrint('Error updating challenge progress: $e');
      rethrow;
    }
  }

  // AI COACH METHODS

  // Create a new conversation
  Future<String> createAiCoachConversation(String title) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      final data = {
        'user_id': currentUser!.id,
        'title': title,
      };

      final response = await client
          .from('ai_coach_conversations')
          .insert(data)
          .select()
          .single();

      return response['id'];
    } catch (e) {
      debugPrint('Error creating AI coach conversation: $e');
      rethrow;
    }
  }

  // Get all conversations for current user
  Future<List<Map<String, dynamic>>> getAiCoachConversations() async {
    try {
      if (currentUser == null) return [];

      final response = await client
          .from('ai_coach_conversations')
          .select()
          .eq('user_id', currentUser!.id)
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting AI coach conversations: $e');
      return [];
    }
  }

  // Get messages for a specific conversation
  Future<List<Map<String, dynamic>>> getAiCoachMessages(
      String conversationId) async {
    try {
      if (currentUser == null) return [];

      final response = await client
          .from('ai_coach_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting AI coach messages: $e');
      return [];
    }
  }

  // Save a message to the conversation
  Future<Map<String, dynamic>> saveAiCoachMessage(
      String conversationId, String content, bool isUserMessage) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      final data = {
        'conversation_id': conversationId,
        'user_id': currentUser!.id,
        'content': content,
        'is_user_message': isUserMessage,
      };

      final response =
          await client.from('ai_coach_messages').insert(data).select().single();

      // Update the conversation's updated_at timestamp
      await client
          .from('ai_coach_conversations')
          .update({'updated_at': DateTime.now().toIso8601String()}).eq(
              'id', conversationId);

      return response;
    } catch (e) {
      debugPrint('Error saving AI coach message: $e');
      rethrow;
    }
  }

  // Helper method to map Supabase response to UserModel
  UserModel _mapToUserModel(Map<String, dynamic> data, {bool isAdmin = false}) {
    return UserModel(
      id: data['id'],
      name: data['name'] ?? 'Unknown User',
      age: (data['age'] as int?) ?? 0, // Handle null age values
      avatarUrl: data['avatar_url'],
      xp: (data['xp'] as int?) ?? 0,
      monthlyXp: (data['monthly_xp'] as int?) ?? 0,
      coins: (data['coins'] as num?)?.toDouble() ?? 0.0,
      badges: List<String>.from(data['badges'] ?? []),
      interests: List<String>.from(data['interests'] ?? []),
      email: currentUser?.email,
      parentEmail: data['parent_email'],
      weeklyReportsEnabled: data['weekly_reports_enabled'] ?? false,
      isPremium: data['is_premium'] ?? false,
      isAdmin: isAdmin,
      timezone: data['timezone'],
      preferredSendDow: (data['preferred_send_dow'] as int?),
      preferredSendHour: (data['preferred_send_hour'] as int?),
      preferredSendMinute: (data['preferred_send_minute'] as int?),
      schoolId: data['school_id'],
      schoolName: data['school_name'],
      rank: null,
    );
  }

  // Duplicate method removed - using the implementation defined earlier in the file

  // ==========================================
  // AUTHENTICATION METHODS
  // ==========================================

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('Attempting to sign in user: $email');

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('Sign in successful for user: ${response.user!.email}');
      } else {
        debugPrint('Sign in failed: No user returned');
      }

      return response;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    int? age,
  }) async {
    try {
      debugPrint('Attempting to sign up user: $email');

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'age': age,
        },
      );

      if (response.user != null) {
        debugPrint('Sign up successful for user: ${response.user!.email}');

        // Create user profile in profiles table
        await _createUserProfile(
          userId: response.user!.id,
          name: name,
          age: age,
        );
      } else {
        debugPrint('Sign up failed: No user returned');
      }

      return response;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    }
  }

  /// Create user profile in profiles table
  Future<void> _createUserProfile({
    required String userId,
    required String name,
    int? age,
  }) async {
    try {
      await client.from('profiles').insert({
        'id': userId,
        'name': name,
        'age': age ?? 13,
        'xp': 0,
        'coins': 0,
        'badges': [],
        'interests': [],
        'is_premium': false,
        'weekly_reports_enabled': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('User profile created successfully for: $userId');
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      rethrow;
    }
  }

  /// Get current user session
  Session? get currentSession => client.auth.currentSession;

  /// Check if session is valid and not expired
  bool get hasValidSession {
    final session = currentSession;
    if (session == null) return false;

    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    final isExpired = DateTime.now().isAfter(expiresAt);

    debugPrint('Session check: expires at $expiresAt, expired: $isExpired');
    return !isExpired;
  }

  /// Refresh current session
  Future<AuthResponse> refreshSession() async {
    try {
      debugPrint('Refreshing current session');
      final response = await client.auth.refreshSession();
      debugPrint(
          'Session refresh ${response.session != null ? "successful" : "failed"}');
      return response;
    } catch (e) {
      debugPrint('Session refresh error: $e');
      rethrow;
    }
  }

  /// Auto-refresh session if needed
  Future<bool> ensureValidSession() async {
    try {
      if (!hasValidSession) {
        debugPrint('Session invalid, attempting refresh');
        final response = await refreshSession();
        return response.session != null;
      }
      return true;
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }

  /// Helper method to validate UUID format
  bool _isValidUuid(String id) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(id);
  }
}

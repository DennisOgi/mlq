import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';

/// Free tier (from day 1): Goals, Gratitude Jar, view-only leaderboard,
/// and Mini-Courses for [miniCourseFreeDays] days.
///
/// Paid / school seat / admin: full app (library, wallet, challenges,
/// Victory Wall posts, AI, mini-courses with no time limit).
class Entitlements {
  static const miniCourseFreeDays = 7;

  /// Paid plan, school student, school org seat, or admin.
  /// Trial / consumer free-tier do NOT count.
  static bool hasPaidAccess(UserModel? user) {
    if (user == null) return false;
    if (user.isAdmin) return true;
    if (user.schoolId != null && user.schoolId!.trim().isNotEmpty) {
      return true;
    }
    return user.isPremium;
  }

  static bool of(UserProvider provider) => hasPaidAccess(provider.user);

  static bool canUseGoals(UserModel? user) => user != null;

  static bool canUseGratitude(UserModel? user) => user != null;

  static bool canViewLeaderboard(UserModel? user) => user != null;

  static bool canUseMiniCourses(UserModel? user) {
    if (hasPaidAccess(user)) return true;
    if (user == null) return false;
    return miniCourseDaysRemaining(user) > 0;
  }

  /// Days of free mini-courses left (0 when locked). Paid users get a
  /// non-zero sentinel so callers can skip countdown UI.
  static int miniCourseDaysRemaining(UserModel? user) {
    if (hasPaidAccess(user)) return miniCourseFreeDays;
    final created = accountCreatedAt();
    if (created == null) return 0;
    final end = created.add(const Duration(days: miniCourseFreeDays));
    final remaining = end.difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds <= 0) return 0;
    final days =
        (remaining.inMilliseconds / Duration.millisecondsPerDay).ceil();
    return days < 1 ? 1 : days;
  }

  static DateTime? accountCreatedAt() {
    try {
      final raw = Supabase.instance.client.auth.currentUser?.createdAt;
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    } catch (_) {
      return null;
    }
  }
}

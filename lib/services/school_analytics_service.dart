import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/school_analytics_model.dart';

class SchoolAnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get school analytics overview
  Future<SchoolAnalytics?> getSchoolAnalytics(String schoolId) async {
    try {
      final response = await _supabase.functions.invoke(
        'school-analytics',
        body: {
          'action': 'get_school_overview',
          'school_id': schoolId,
        },
      );

      if (response.data != null) {
        return SchoolAnalytics.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching school analytics: $e');
      return null;
    }
  }

  /// Get monthly top 20 leaderboard for a school
  Future<MonthlyLeaderboard?> getMonthlyLeaderboard(
    String schoolId, {
    String? monthKey, // Format: YYYY-MM, defaults to current month
  }) async {
    try {
      final month = monthKey ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

      final response = await _supabase.functions.invoke(
        'school-analytics',
        body: {
          'action': 'get_monthly_leaderboard',
          'school_id': schoolId,
          'month_key': month,
        },
      );

      if (response.data != null) {
        return MonthlyLeaderboard.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching monthly leaderboard: $e');
      return null;
    }
  }

  /// Get student performance details
  Future<StudentPerformance?> getStudentPerformance(
    String userId,
    String schoolId,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'school-analytics',
        body: {
          'action': 'get_student_performance',
          'user_id': userId,
          'school_id': schoolId,
        },
      );

      if (response.data != null) {
        return StudentPerformance.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching student performance: $e');
      return null;
    }
  }

  /// Get school trends over time
  Future<SchoolTrends?> getSchoolTrends(
    String schoolId, {
    int months = 6,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'school-analytics',
        body: {
          'action': 'get_school_trends',
          'school_id': schoolId,
          'months': months,
        },
      );

      if (response.data != null) {
        return SchoolTrends.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error fetching school trends: $e');
      return null;
    }
  }

  /// Get all students in a school with their performance
  Future<List<StudentPerformance>> getAllStudents(String schoolId) async {
    try {
      final response = await _supabase.functions.invoke(
        'school-analytics',
        body: {
          'action': 'get_all_students',
          'school_id': schoolId,
        },
      );

      if (response.data != null && response.data['students'] != null) {
        return (response.data['students'] as List)
            .map((e) => StudentPerformance.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching all students: $e');
      return [];
    }
  }

  /// Get students at risk (low engagement)
  Future<List<StudentPerformance>> getStudentsAtRisk(String schoolId) async {
    try {
      final response = await _supabase.functions.invoke(
        'school-analytics',
        body: {
          'action': 'get_students_at_risk',
          'school_id': schoolId,
        },
      );

      if (response.data != null && response.data['students'] != null) {
        return (response.data['students'] as List)
            .map((e) => StudentPerformance.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching students at risk: $e');
      return [];
    }
  }

  /// Check if current user has school admin access
  Future<bool> hasSchoolAdminAccess() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('role, school_id')
          .eq('id', user.id)
          .single();

      final role = response['role'] as String?;
      final schoolId = response['school_id'] as String?;

      return (role == 'teacher' || role == 'school_admin') &&
          schoolId != null;
    } catch (e) {
      print('Error checking school admin access: $e');
      return false;
    }
  }

  /// Get current user's school ID
  Future<String?> getCurrentUserSchoolId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select('school_id')
          .eq('id', user.id)
          .single();

      return response['school_id'] as String?;
    } catch (e) {
      print('Error getting user school ID: $e');
      return null;
    }
  }

  /// Get available months for historical leaderboards
  Future<List<String>> getAvailableMonths(String schoolId) async {
    try {
      final response = await _supabase.functions.invoke(
        'school-analytics',
        body: {
          'action': 'get_available_months',
          'school_id': schoolId,
        },
      );

      if (response.data != null && response.data['months'] != null) {
        return List<String>.from(response.data['months']);
      }
      return [];
    } catch (e) {
      print('Error fetching available months: $e');
      return [];
    }
  }
}

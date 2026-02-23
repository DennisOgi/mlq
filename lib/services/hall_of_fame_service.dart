import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class HallOfFameEntry {
  final String monthKey;
  final int rank;
  final String userId;
  final String? name;
  final String? avatarUrl;
  final String? schoolName;
  final int? monthlyXp;

  HallOfFameEntry({
    required this.monthKey,
    required this.rank,
    required this.userId,
    this.name,
    this.avatarUrl,
    this.schoolName,
    this.monthlyXp,
  });

  factory HallOfFameEntry.fromJson(Map<String, dynamic> json) {
    return HallOfFameEntry(
      monthKey: (json['month_key'] ?? '').toString(),
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      userId: (json['user_id'] ?? '').toString(),
      name: (json['name'] as String?),
      avatarUrl: (json['avatar_url'] as String?),
      schoolName: (json['school_name'] as String?),
      monthlyXp: (json['monthly_xp'] as num?)?.toInt(),
    );
  }
}

class HallOfFameService {
  static final HallOfFameService _instance = HallOfFameService._internal();

  static HallOfFameService get instance => _instance;

  factory HallOfFameService() {
    return _instance;
  }

  HallOfFameService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;

  Future<List<HallOfFameEntry>> fetchMonthlyWinners({int? rank}) async {
    try {
      var query = _client
          .from('monthly_winners')
          .select('month_key,rank,user_id,name,avatar_url,school_name,monthly_xp,awarded_at');

      if (rank != null) {
        query = query.eq('rank', rank);
      }

      final resp = await query.order('month_key', ascending: false);
      return (resp as List)
          .map((r) => HallOfFameEntry.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching hall of fame: $e');
      return [];
    }
  }

  Future<HallOfFameEntry?> fetchWinnerForMonth({
    required String monthKey,
    required int rank,
  }) async {
    try {
      final resp = await _client
          .from('monthly_winners')
          .select('month_key,rank,user_id,name,avatar_url,school_name,monthly_xp,awarded_at')
          .eq('month_key', monthKey)
          .eq('rank', rank)
          .maybeSingle();

      if (resp == null) return null;
      return HallOfFameEntry.fromJson(Map<String, dynamic>.from(resp));
    } catch (e) {
      debugPrint('Error fetching winner for $monthKey rank $rank: $e');
      return null;
    }
  }
}

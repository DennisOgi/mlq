enum ChallengeType { basic, premium }

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final String? realWorldPrize;
  final DateTime startDate;
  final DateTime endDate;
  final int participantsCount;
  final String organizationId;
  final String organizationName;
  final String organizationLogo;
  final List<String> criteria;
  final String timeline;
  final bool isTeamChallenge;
  final int coinReward;
  final int xpReward;
  // DB-aligned fields
  final String validationMode; // 'in_app' | 'external'
  final double coinCost; // numeric in DB
  final Map<String, dynamic>? rules; // jsonb
  final String? externalJoinUrl; // external_join_url

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.realWorldPrize,
    required this.startDate,
    required this.endDate,
    this.participantsCount = 0,
    required this.organizationId,
    required this.organizationName,
    required this.organizationLogo,
    required this.criteria,
    required this.timeline,
    required this.isTeamChallenge,
    required this.coinReward,
    this.xpReward = 0,
    this.validationMode = 'in_app',
    this.coinCost = 0.0,
    this.rules,
    this.externalJoinUrl,
  });

  bool get isPremium => type == ChallengeType.premium;
  int get coinsCost => coinCost.round();
  
  /// Check if the challenge has expired (end date is in the past)
  bool get isExpired => DateTime.now().isAfter(endDate);
  
  /// Check if the challenge has started (start date is in the past or now)
  bool get hasStarted => DateTime.now().isAfter(startDate) || DateTime.now().isAtSameMomentAs(startDate);
  
  /// Check if the challenge is currently active (started but not expired)
  bool get isActive => hasStarted && !isExpired;
  
  /// Check if the challenge is upcoming (not yet started)
  bool get isUpcoming => !hasStarted;
  
  /// Get a human-readable status string for the challenge
  String get statusText {
    if (isExpired) return 'Expired';
    if (isUpcoming) return 'Upcoming';
    return 'Active';
  }
  
  /// Get days remaining until challenge ends (0 if expired)
  int get daysRemaining {
    if (isExpired) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }
  
  ChallengeModel copyWith({
    String? id,
    String? title,
    String? description,
    ChallengeType? type,
    String? realWorldPrize,
    DateTime? startDate,
    DateTime? endDate,
    int? participantsCount,
    String? organizationId,
    String? organizationName,
    String? organizationLogo,
    List<String>? criteria,
    String? timeline,
    bool? isTeamChallenge,
    int? coinReward,
    int? xpReward,
    String? validationMode,
    double? coinCost,
    Map<String, dynamic>? rules,
    String? externalJoinUrl,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      realWorldPrize: realWorldPrize ?? this.realWorldPrize,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      participantsCount: participantsCount ?? this.participantsCount,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      organizationLogo: organizationLogo ?? this.organizationLogo,
      criteria: criteria ?? this.criteria,
      timeline: timeline ?? this.timeline,
      isTeamChallenge: isTeamChallenge ?? this.isTeamChallenge,
      coinReward: coinReward ?? this.coinReward,
      xpReward: xpReward ?? this.xpReward,
      validationMode: validationMode ?? this.validationMode,
      coinCost: coinCost ?? this.coinCost,
      rules: rules ?? this.rules,
      externalJoinUrl: externalJoinUrl ?? this.externalJoinUrl,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'type': type == ChallengeType.premium ? 'premium' : 'basic',
      'real_world_prize': realWorldPrize,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'organization_id': organizationId,
      'organization_name': organizationName,
      'organization_logo': organizationLogo,
      'criteria': criteria,
      'timeline': timeline,
      'is_team_challenge': isTeamChallenge,
      'coin_reward': coinReward,
      'xp_reward': xpReward,
      'validation_mode': validationMode,
      'coin_cost': coinCost,
      if (rules != null) 'rules': rules,
      if (externalJoinUrl != null) 'external_join_url': externalJoinUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
    return map;
  }

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    final startRaw = json['start_date'];
    final endRaw = json['end_date'];
    final start = startRaw is String ? DateTime.tryParse(startRaw) : null;
    final end = endRaw is String ? DateTime.tryParse(endRaw) : null;

    return ChallengeModel(
      id: json['id'],
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      // Handle string type values for challenge type
      type: json['type'] == 'premium' ? ChallengeType.premium : ChallengeType.basic,
      realWorldPrize: json['real_world_prize'],
      // Properly parse timestamps from PostgreSQL
      startDate: start ?? DateTime.now(),
      endDate: end ?? DateTime.now(),
      // Handle optional participants_count
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
      organizationId: (json['organization_id'] as String?) ?? 'default',
      organizationName: (json['organization_name'] as String?) ?? 'MLQ',
      organizationLogo: (json['organization_logo'] as String?) ?? '',
      // Handle jsonb array to List<String>
      criteria: json['criteria'] is List 
          ? List<String>.from(json['criteria']) 
          : json['criteria'] != null 
              ? List<String>.from(json['criteria'] as List) 
              : [],
      timeline: (json['timeline'] as String?) ?? '',
      isTeamChallenge: (json['is_team_challenge'] as bool?) ?? false,
      coinReward: (json['coin_reward'] as num?)?.toInt() ?? 0,
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      validationMode: (json['validation_mode'] as String?) ?? 'in_app',
      coinCost: (json['coin_cost'] is num) ? (json['coin_cost'] as num).toDouble() : 0.0,
      rules: json['rules'] as Map<String, dynamic>?,
      externalJoinUrl: json['external_join_url'] as String?,
    );
  }

  // Mock challenges for development
  static List<ChallengeModel> mockChallenges() {
    final now = DateTime.now();
    final nextWeek = DateTime(now.year, now.month, now.day + 7);
    final nextMonth = DateTime(now.year, now.month + 1, now.day);
    
    return [
      // Basic challenges
      ChallengeModel(
        id: '1',
        title: 'Reading Marathon',
        description: 'Read for at least 20 minutes every day for a week.',
        type: ChallengeType.basic,
        coinReward: 50,
        startDate: now,
        endDate: nextWeek,
        participantsCount: 24,
        organizationId: 'org1',
        organizationName: 'Reading Club',
        organizationLogo: 'assets/images/sponsors/reading_club_logo.png',
        criteria: ['Read 20 minutes daily', 'Log your reading time', 'Share a book review'],
        timeline: '7 days',
        isTeamChallenge: false,
      ),
      ChallengeModel(
        id: '2',
        title: 'Kindness Challenge',
        description: 'Do one kind deed each day for 5 days.',
        type: ChallengeType.basic,
        coinReward: 75,
        startDate: now,
        endDate: DateTime(now.year, now.month, now.day + 5),
        participantsCount: 42,
        organizationId: 'org2',
        organizationName: 'Kind Hearts Foundation',
        organizationLogo: 'assets/images/sponsors/kind_hearts_logo.png',
        criteria: ['Do one kind deed daily', 'Document your deed', 'Share your experience'],
        timeline: '5 days',
        isTeamChallenge: false,
      ),
      ChallengeModel(
        id: '3',
        title: 'Fitness Fun',
        description: 'Complete 10 minutes of exercise daily for 10 days.',
        type: ChallengeType.basic,
        coinReward: 100,
        startDate: now,
        endDate: DateTime(now.year, now.month, now.day + 10),
        participantsCount: 18,
        organizationId: 'org3',
        organizationName: 'Active Kids',
        organizationLogo: 'assets/images/sponsors/active_kids_logo.png',
        criteria: ['Exercise 10 minutes daily', 'Track your activities', 'Share a workout photo'],
        timeline: '10 days',
        isTeamChallenge: true,
      ),
      
      // Premium challenges
      ChallengeModel(
        id: '4',
        title: 'Science Explorer',
        description: 'Complete 3 science experiments and document your findings.',
        type: ChallengeType.premium,
        coinReward: 200,
        realWorldPrize: 'Science Kit',
        startDate: now,
        endDate: nextMonth,
        participantsCount: 12,
        organizationId: 'org4',
        organizationName: 'Science Academy',
        organizationLogo: 'assets/images/sponsors/science_academy_logo.png',
        criteria: ['Complete 3 experiments', 'Document findings', 'Create presentation'],
        timeline: '30 days',
        isTeamChallenge: true,
      ),
      ChallengeModel(
        id: '5',
        title: 'Creative Writing',
        description: 'Write a short story with at least 500 words.',
        type: ChallengeType.premium,
        coinReward: 150,
        realWorldPrize: 'Notebook Set',
        startDate: now,
        endDate: nextMonth,
        participantsCount: 8,
        organizationId: 'org5',
        organizationName: 'Young Writers Club',
        organizationLogo: 'assets/images/sponsors/writers_club_logo.png',
        criteria: ['Write 500+ words', 'Include dialogue', 'Create character profiles'],
        timeline: '30 days',
        isTeamChallenge: false,
      ),
    ];
  }
}

class UserModel {
  final String id;
  final String name;
  final int age;
  final String? avatarUrl;
  int xp;
  int monthlyXp; // XP earned this month (for monthly leaderboard)
  double coins;
  final List<String> badges;
  final List<String> interests;
  final String? email;
  final String? password;
  final String? parentEmail;
  final bool weeklyReportsEnabled;
  final bool isPremium;
  final bool isAdmin;
  // Parent reports scheduling preferences
  final String? timezone; // IANA timezone, e.g. "Europe/London"
  final int? preferredSendDow; // 0-6 (Sunday-Saturday)
  final int? preferredSendHour; // 0-23
  final int? preferredSendMinute; // 0-59
  // School and leaderboard context
  final String? schoolId;
  final String? schoolName;
  final int? rank; // optional, used in leaderboard contexts
  // Trial status
  final DateTime? trialEndsAt;
  final String? subscriptionStatus; // 'free', 'trial', 'active', 'expired'
  
  // Returns true if the user has a parent email set up
  bool get isParent => parentEmail != null && parentEmail!.isNotEmpty;
  
  // Returns true if user should have premium checkmark (either isPremium flag OR from premium schools)
  bool get hasPremiumCheckmark => isPremium || 
    (schoolName?.toLowerCase().contains('pearls garden high') ?? false) ||
    (schoolName?.toLowerCase().contains('wellspring college') ?? false);

  // Returns true if user is in a trial period
  bool get isTrial => subscriptionStatus == 'trial' && 
    (trialEndsAt?.isAfter(DateTime.now()) ?? false);

  UserModel({
    required this.id,
    required this.name,
    required this.age,
    this.avatarUrl,
    this.xp = 0,
    this.monthlyXp = 0,
    this.coins = 0.0,
    this.badges = const [],
    this.interests = const [],
    this.email,
    this.password,
    this.parentEmail,
    this.weeklyReportsEnabled = false,
    this.isPremium = false,
    this.isAdmin = false,
    this.timezone,
    this.preferredSendDow,
    this.preferredSendHour,
    this.preferredSendMinute,
    this.schoolId,
    this.schoolName,
    this.rank,
    this.trialEndsAt,
    this.subscriptionStatus,
  });

    UserModel copyWith({
    String? id,
    String? name,
    int? age,
    String? avatarUrl,
    int? xp,
    int? monthlyXp,
    double? coins,
    List<String>? badges,
    List<String>? interests,
    String? email,
    String? password,
    String? parentEmail,
    bool? weeklyReportsEnabled,
    bool? isPremium,
    bool? isAdmin,
    String? timezone,
    int? preferredSendDow,
    int? preferredSendHour,
    int? preferredSendMinute,
    String? schoolId,
    String? schoolName,
    int? rank,
    DateTime? trialEndsAt,
    String? subscriptionStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      xp: xp ?? this.xp,
      monthlyXp: monthlyXp ?? this.monthlyXp,
      coins: coins ?? this.coins,
      badges: badges ?? this.badges,
      interests: interests ?? this.interests,
      email: email ?? this.email,
      password: password ?? this.password,
      parentEmail: parentEmail ?? this.parentEmail,
      weeklyReportsEnabled: weeklyReportsEnabled ?? this.weeklyReportsEnabled,
      isPremium: isPremium ?? this.isPremium,
      isAdmin: isAdmin ?? this.isAdmin,
      timezone: timezone ?? this.timezone,
      preferredSendDow: preferredSendDow ?? this.preferredSendDow,
      preferredSendHour: preferredSendHour ?? this.preferredSendHour,
      preferredSendMinute: preferredSendMinute ?? this.preferredSendMinute,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      rank: rank ?? this.rank,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'avatarUrl': avatarUrl,
      'xp': xp,
      'monthlyXp': monthlyXp,
      'coins': coins,
      'badges': badges,
      'interests': interests,
      'email': email,
      'password': password,
      'parentEmail': parentEmail,
      'weeklyReportsEnabled': weeklyReportsEnabled,
      'isPremium': isPremium,
      'isAdmin': isAdmin,
      'timezone': timezone,
      'preferredSendDow': preferredSendDow,
      'preferredSendHour': preferredSendHour,
      'preferredSendMinute': preferredSendMinute,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'rank': rank,
      'trialEndsAt': trialEndsAt?.toIso8601String(),
      'subscriptionStatus': subscriptionStatus,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      age: json['age'],
      avatarUrl: json['avatarUrl'],
      xp: json['xp'] ?? 0,
      monthlyXp: json['monthlyXp'] ?? 0,
      coins: json['coins'] ?? 0.0,
      badges: List<String>.from(json['badges'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      email: json['email'],
      password: json['password'],
      parentEmail: json['parentEmail'],
      weeklyReportsEnabled: json['weeklyReportsEnabled'] ?? false,
      isPremium: json['isPremium'] ?? false,
      isAdmin: json['isAdmin'] ?? false,
      timezone: json['timezone'],
      preferredSendDow: json['preferredSendDow'],
      preferredSendHour: json['preferredSendHour'],
      preferredSendMinute: json['preferredSendMinute'],
      schoolId: json['schoolId'],
      schoolName: json['schoolName'],
      rank: json['rank'],
      trialEndsAt: json['trial_ends_at'] != null 
          ? DateTime.parse(json['trial_ends_at']) 
          : null,
      subscriptionStatus: json['subscription_status'],
    );
  }

  // Mock user for development
  static UserModel mockUser() {
    // Use a valid UUID format for compatibility with Supabase
    return UserModel(
      id: '00000000-0000-0000-0000-000000000001', // Valid UUID format
      name: 'Alex',
      age: 10,
      avatarUrl: 'assets/images/avatars/avatar_1.png',
      xp: 350,
      coins: 25.0,
      badges: ['goal_ninja', 'challenge_champion'],
      interests: ['Leadership', 'Science', 'Art'],
      email: 'alex@example.com',
      password: 'password123',
      parentEmail: 'parent@example.com',
      weeklyReportsEnabled: true,
      isPremium: true,
      isAdmin: true, // Set to true for testing admin features
      timezone: 'Europe/London',
      preferredSendDow: 0,
      preferredSendHour: 9,
      preferredSendMinute: 0,
      schoolId: null,
      schoolName: null,
      rank: null,
      trialEndsAt: DateTime.now().add(const Duration(days: 14)),
      subscriptionStatus: 'trial',
    );
  }
  
  // Mock non-admin user for development
  static UserModel mockNonAdminUser() {
    return UserModel(
      id: '00000000-0000-0000-0000-000000000002', // Valid UUID format
      name: 'Sam',
      age: 12,
      avatarUrl: 'assets/images/avatars/avatar_2.png',
      xp: 250,
      coins: 15.0,
      badges: ['goal_setter'],
      interests: ['Sports', 'Reading', 'Music'],
      email: 'sam@example.com',
      password: 'password123',
      parentEmail: 'samparent@example.com',
      weeklyReportsEnabled: false,
      isPremium: false,
      isAdmin: false,
      timezone: 'Europe/London',
      preferredSendDow: 0,
      preferredSendHour: 9,
      preferredSendMinute: 0,
      schoolId: null,
      schoolName: null,
      rank: null,
      subscriptionStatus: 'free',
    );
  }
}

enum BadgeType {
  goalNinja,
  challengeChampion,
  streakMaster,
  helpfulHero,
  knowledgeSeeker,
  healthyHabitHero,
  socialButterfly,
  academicAce,
  questorFriend,
  victoryVeteran
}

class BadgeModel {
  final String id;
  final String userId;
  final BadgeType type;
  final DateTime earnedDate;
  final String? description;

  BadgeModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.earnedDate,
    this.description,
  });

  String get name {
    switch (type) {
      case BadgeType.goalNinja:
        return 'Goal Ninja';
      case BadgeType.challengeChampion:
        return 'Challenge Champion';
      case BadgeType.streakMaster:
        return 'Streak Master';
      case BadgeType.helpfulHero:
        return 'Helpful Hero';
      case BadgeType.knowledgeSeeker:
        return 'Knowledge Seeker';
      case BadgeType.healthyHabitHero:
        return 'Healthy Habit Hero';
      case BadgeType.socialButterfly:
        return 'Social Butterfly';
      case BadgeType.academicAce:
        return 'Academic Ace';
      case BadgeType.questorFriend:
        return 'Questor Friend';
      case BadgeType.victoryVeteran:
        return 'Victory Veteran';
    }
  }

  String get imageAsset {
    switch (type) {
      case BadgeType.goalNinja:
        return 'assets/images/badges/jadebadge.png';
      case BadgeType.challengeChampion:
        return 'assets/images/badges/rubybadge.png';
      case BadgeType.streakMaster:
        return 'assets/images/badges/sapphirebadge.png';
      case BadgeType.helpfulHero:
        return 'assets/images/badges/pearlbadge.png';
      case BadgeType.knowledgeSeeker:
        return 'assets/images/badges/topazbadge.png';
      case BadgeType.healthyHabitHero:
        return 'assets/images/badges/bronzebadge.png';
      case BadgeType.socialButterfly:
        return 'assets/images/badges/goldbadge.png';
      case BadgeType.academicAce:
        return 'assets/images/badges/platinumbadge.png';
      case BadgeType.questorFriend:
        return 'assets/images/badges/emeraldbadge.png';
      case BadgeType.victoryVeteran:
        return 'assets/images/badges/diamondbadge.png';
    }
  }

  String get defaultDescription {
    switch (type) {
      case BadgeType.goalNinja:
        return 'Completed 5 main goals';
      case BadgeType.challengeChampion:
        return 'Won 3 challenges';
      case BadgeType.streakMaster:
        return 'Maintained a 5-day streak';
      case BadgeType.helpfulHero:
        return 'Helped 3 friends with their goals';
      case BadgeType.knowledgeSeeker:
        return 'Completed 3 mini-courses';
      case BadgeType.healthyHabitHero:
        return 'Completed 10 health goals';
      case BadgeType.socialButterfly:
        return 'Completed 10 social goals';
      case BadgeType.academicAce:
        return 'Completed 10 academic goals';
      case BadgeType.questorFriend:
        return 'Had 10 conversations with Questor';
      case BadgeType.victoryVeteran:
        return 'Made 5 posts on the Victory Wall';
    }
  }

  BadgeModel copyWith({
    String? id,
    String? userId,
    BadgeType? type,
    DateTime? earnedDate,
    String? description,
  }) {
    return BadgeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      earnedDate: earnedDate ?? this.earnedDate,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.index,
      'earnedDate': earnedDate.millisecondsSinceEpoch,
      'description': description,
    };
  }

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'],
      userId: json['userId'],
      type: BadgeType.values[json['type']],
      earnedDate: DateTime.fromMillisecondsSinceEpoch(json['earnedDate']),
      description: json['description'],
    );
  }

  // Mock badges for development
  static List<BadgeModel> mockBadges() {
    final userId = 'user123';
    final now = DateTime.now();
    
    return [
      BadgeModel(
        id: '1',
        userId: userId,
        type: BadgeType.goalNinja,
        earnedDate: DateTime(now.year, now.month - 1, 15),
      ),
      BadgeModel(
        id: '2',
        userId: userId,
        type: BadgeType.challengeChampion,
        earnedDate: DateTime(now.year, now.month, 1),
      ),
      BadgeModel(
        id: '3',
        userId: userId,
        type: BadgeType.streakMaster,
        earnedDate: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}

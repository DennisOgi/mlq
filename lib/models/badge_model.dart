import 'package:flutter/material.dart';

enum BadgeType {
  goalNinja,
  challengeChampion,
  streakMaster,
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

  /// A Material icon used to render the badge when its image asset is missing.
  /// The badge art (assets/images/badges/*.png) is not bundled, so every render
  /// path falls back to these themed icons instead of a broken image.
  IconData get fallbackIcon {
    switch (type) {
      case BadgeType.goalNinja:
        return Icons.flag_rounded;
      case BadgeType.challengeChampion:
        return Icons.emoji_events_rounded;
      case BadgeType.streakMaster:
        return Icons.local_fire_department_rounded;
      case BadgeType.knowledgeSeeker:
        return Icons.menu_book_rounded;
      case BadgeType.healthyHabitHero:
        return Icons.favorite_rounded;
      case BadgeType.socialButterfly:
        return Icons.groups_rounded;
      case BadgeType.academicAce:
        return Icons.school_rounded;
      case BadgeType.questorFriend:
        return Icons.chat_bubble_rounded;
      case BadgeType.victoryVeteran:
        return Icons.military_tech_rounded;
    }
  }

  /// Accent color used for the fallback badge medallion.
  Color get accentColor {
    switch (type) {
      case BadgeType.goalNinja:
        return const Color(0xFF2E7D32);
      case BadgeType.challengeChampion:
        return const Color(0xFFC62828);
      case BadgeType.streakMaster:
        return const Color(0xFF1565C0);
      case BadgeType.knowledgeSeeker:
        return const Color(0xFFF9A825);
      case BadgeType.healthyHabitHero:
        return const Color(0xFFAD1457);
      case BadgeType.socialButterfly:
        return const Color(0xFF6A1B9A);
      case BadgeType.academicAce:
        return const Color(0xFF455A64);
      case BadgeType.questorFriend:
        return const Color(0xFF00695C);
      case BadgeType.victoryVeteran:
        return const Color(0xFF4527A0);
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

/// Renders a badge's artwork, gracefully falling back to a themed medallion
/// icon when the PNG asset is not bundled (which is currently always the case).
/// Use this everywhere instead of `Image.asset(badge.imageAsset)` directly.
class BadgeImage extends StatelessWidget {
  final BadgeModel badge;

  /// Fixed dimension for the badge. When null, the badge fills its parent's
  /// constraints (used inside ClipRRect/avatar containers).
  final double? size;
  final BoxFit fit;

  const BadgeImage({
    super.key,
    required this.badge,
    this.size,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      badge.imageAsset,
      height: size,
      width: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() {
    final fixed = size;
    if (fixed != null) return _medallion(fixed);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        final dim = shortest.isFinite && shortest > 0 ? shortest : 64.0;
        return _medallion(dim);
      },
    );
  }

  Widget _medallion(double dim) {
    return Container(
      height: dim,
      width: dim,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badge.accentColor,
            Color.lerp(badge.accentColor, Colors.black, 0.25) ??
                badge.accentColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: badge.accentColor.withValues(alpha: 0.35),
            blurRadius: dim * 0.12,
            offset: Offset(0, dim * 0.05),
          ),
        ],
      ),
      child: Icon(
        badge.fallbackIcon,
        color: Colors.white,
        size: dim * 0.5,
      ),
    );
  }
}

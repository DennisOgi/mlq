enum SkillCategory {
  communication,
  teamwork,
  problemSolving,
  empathy,
  resilience,
}

class Skill {
  final String id;
  final String name;
  final String description;
  final SkillCategory category;
  final int level; // 1-10
  final int requiredXP;
  final List<String> prerequisites; // IDs of skills that must be unlocked first
  final String? unlockedAbility; // Special ability unlocked at this level
  final String iconName;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.level,
    required this.requiredXP,
    this.prerequisites = const [],
    this.unlockedAbility,
    required this.iconName,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: SkillCategory.values.firstWhere(
        (e) => e.toString() == 'SkillCategory.${json['category']}',
      ),
      level: json['level'] as int,
      requiredXP: json['required_xp'] as int,
      prerequisites: (json['prerequisites'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      unlockedAbility: json['unlocked_ability'] as String?,
      iconName: json['icon_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toString().split('.').last,
      'level': level,
      'required_xp': requiredXP,
      'prerequisites': prerequisites,
      'unlocked_ability': unlockedAbility,
      'icon_name': iconName,
    };
  }
}

class UserSkillProgress {
  final String userId;
  final Map<SkillCategory, int> categoryXP; // XP per category
  final List<String> unlockedSkillIds;
  final List<String> unlockedAbilities;
  final int totalSkillPoints;

  UserSkillProgress({
    required this.userId,
    required this.categoryXP,
    required this.unlockedSkillIds,
    required this.unlockedAbilities,
    required this.totalSkillPoints,
  });

  factory UserSkillProgress.fromJson(Map<String, dynamic> json) {
    return UserSkillProgress(
      userId: json['user_id'] as String,
      categoryXP: (json['category_xp'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          SkillCategory.values.firstWhere(
            (e) => e.toString() == 'SkillCategory.$key',
          ),
          value as int,
        ),
      ),
      unlockedSkillIds: (json['unlocked_skill_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      unlockedAbilities: (json['unlocked_abilities'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      totalSkillPoints: json['total_skill_points'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'category_xp': categoryXP.map(
        (key, value) => MapEntry(key.toString().split('.').last, value),
      ),
      'unlocked_skill_ids': unlockedSkillIds,
      'unlocked_abilities': unlockedAbilities,
      'total_skill_points': totalSkillPoints,
    };
  }

  bool isSkillUnlocked(String skillId) {
    return unlockedSkillIds.contains(skillId);
  }

  bool hasAbility(String ability) {
    return unlockedAbilities.contains(ability);
  }

  int getXPForCategory(SkillCategory category) {
    return categoryXP[category] ?? 0;
  }
}

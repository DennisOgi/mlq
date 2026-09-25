import 'ai_challenge_generator_service.dart';

/// Pre-built challenge templates for common scenarios
/// These serve as examples and can be used for quick challenge creation
class ChallengeTemplates {
  
  /// Get all available templates
  static List<ChallengeTemplate> getAllTemplates() {
    return [
      // Gratitude Templates
      gratitudeWarrior,
      gratitudeStreak7Days,
      gratitudeMonth,
      
      // Goal Templates
      goalStreak5Days,
      goalCrusher20,
      balancedAchiever,
      
      // Learning Templates
      learningChampion,
      knowledgeSeeker,
      
      // Mixed Templates
      consistencyKing,
      weeklyWarrior,
      monthlyMaster,
    ];
  }

  /// Get templates by category
  static List<ChallengeTemplate> getByCategory(String category) {
    return getAllTemplates().where((t) => t.category == category).toList();
  }

  /// Get template by ID
  static ChallengeTemplate? getById(String id) {
    try {
      return getAllTemplates().firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // GRATITUDE TEMPLATES
  // ============================================================================

  static final gratitudeWarrior = ChallengeTemplate(
    id: 'gratitude_warrior',
    name: 'Gratitude Warrior',
    category: 'gratitude',
    difficulty: 'easy',
    description: 'Write 10 gratitude entries this month to cultivate thankfulness',
    theme: 'Gratitude and Mindfulness',
    targetAudience: '10-15 year olds',
    durationDays: 30,
    coinReward: 75,
    criteria: [
      'Write at least 10 gratitude entries',
      'Entries can be written any day within the month',
      'Each entry should be thoughtful and meaningful',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'gratitude_count_in_window',
        targetValue: 10,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  static final gratitudeStreak7Days = ChallengeTemplate(
    id: 'gratitude_streak_7',
    name: '7-Day Gratitude Streak',
    category: 'gratitude',
    difficulty: 'medium',
    description: 'Build a 7-day gratitude streak to develop daily thankfulness',
    theme: 'Consistency and Gratitude',
    targetAudience: '10-15 year olds',
    durationDays: 14,
    coinReward: 100,
    criteria: [
      'Write gratitude entries for 7 consecutive days',
      'No skipping days (1-day grace period for today)',
      'Build the habit of daily reflection',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'gratitude_streak_days',
        targetValue: 7,
        windowType: 'per_user_enrollment',
        consecutiveRequired: true,
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  static final gratitudeMonth = ChallengeTemplate(
    id: 'gratitude_month',
    name: 'Gratitude Month Challenge',
    category: 'gratitude',
    difficulty: 'hard',
    description: 'Master gratitude with 20 entries in 30 days',
    theme: 'Gratitude Mastery',
    targetAudience: '13-18 year olds',
    durationDays: 30,
    coinReward: 200,
    criteria: [
      'Write 20 gratitude entries within 30 days',
      'Maintain consistency throughout the month',
      'Reflect on your growth at the end',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'gratitude_count_in_window',
        targetValue: 20,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  // ============================================================================
  // GOAL TEMPLATES
  // ============================================================================

  static final goalStreak5Days = ChallengeTemplate(
    id: 'goal_streak_5',
    name: '5-Day Goal Streak',
    category: 'goals',
    difficulty: 'easy',
    description: 'Complete your daily goals for 5 consecutive days',
    theme: 'Consistency and Achievement',
    targetAudience: '10-15 year olds',
    durationDays: 7,
    coinReward: 75,
    criteria: [
      'Complete at least one daily goal each day',
      'Maintain a 5-day streak',
      'Build momentum with daily wins',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'daily_goal_streak_days',
        targetValue: 5,
        windowType: 'per_user_enrollment',
        consecutiveRequired: true,
        maxGapDays: 0,
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  static final goalCrusher20 = ChallengeTemplate(
    id: 'goal_crusher_20',
    name: 'Goal Crusher',
    category: 'goals',
    difficulty: 'medium',
    description: 'Complete 20 goals of any type to show your dedication',
    theme: 'Achievement and Persistence',
    targetAudience: '10-15 year olds',
    durationDays: 14,
    coinReward: 150,
    criteria: [
      'Complete 20 goals (daily or main)',
      'Can be any combination of goal types',
      'Focus on consistent progress',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'any_goals_completed',
        targetValue: 20,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  static final balancedAchiever = ChallengeTemplate(
    id: 'balanced_achiever',
    name: 'Balanced Achiever',
    category: 'goals',
    difficulty: 'hard',
    description: 'Show balance by completing both daily and main goals',
    theme: 'Balance and Holistic Growth',
    targetAudience: '13-18 year olds',
    durationDays: 14,
    coinReward: 250,
    criteria: [
      'Complete 10 daily goals',
      'Complete 2 main goals',
      'Demonstrate balanced progress',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'daily_goal_count_in_window',
        targetValue: 10,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
      ChallengeRule(
        ruleType: 'main_goals_completed',
        targetValue: 2,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  // ============================================================================
  // LEARNING TEMPLATES
  // ============================================================================

  static final learningChampion = ChallengeTemplate(
    id: 'learning_champion',
    name: 'Learning Champion',
    category: 'learning',
    difficulty: 'medium',
    description: 'Complete 3 mini courses to expand your knowledge',
    theme: 'Learning and Growth',
    targetAudience: '10-15 year olds',
    durationDays: 30,
    coinReward: 200,
    criteria: [
      'Complete 3 mini courses',
      'Score at least 70% on each course',
      'Apply what you learn',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'mini_courses_completed',
        targetValue: 3,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  static final knowledgeSeeker = ChallengeTemplate(
    id: 'knowledge_seeker',
    name: 'Knowledge Seeker',
    category: 'learning',
    difficulty: 'hard',
    description: 'Master learning by completing 5 courses in 60 days',
    theme: 'Continuous Learning',
    targetAudience: '13-18 year olds',
    durationDays: 60,
    coinReward: 300,
    criteria: [
      'Complete 5 mini courses',
      'Maintain 70%+ average score',
      'Demonstrate mastery of topics',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'mini_courses_completed',
        targetValue: 5,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  // ============================================================================
  // MIXED TEMPLATES
  // ============================================================================

  static final consistencyKing = ChallengeTemplate(
    id: 'consistency_king',
    name: 'Consistency King',
    category: 'mixed',
    difficulty: 'hard',
    description: 'Master consistency across goals and gratitude',
    theme: 'Consistency and Discipline',
    targetAudience: '13-18 year olds',
    durationDays: 14,
    coinReward: 250,
    criteria: [
      'Maintain a 7-day goal streak',
      'Write 10 gratitude entries',
      'Show consistent daily effort',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'daily_goal_streak_days',
        targetValue: 7,
        windowType: 'per_user_enrollment',
        consecutiveRequired: true,
        groupId: 'main',
        groupOperator: 'all',
      ),
      ChallengeRule(
        ruleType: 'gratitude_count_in_window',
        targetValue: 10,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  static final weeklyWarrior = ChallengeTemplate(
    id: 'weekly_warrior',
    name: 'Weekly Warrior',
    category: 'mixed',
    difficulty: 'medium',
    description: 'Conquer the week with goals and learning',
    theme: 'Weekly Excellence',
    targetAudience: '10-15 year olds',
    durationDays: 7,
    coinReward: 150,
    criteria: [
      'Complete 5 daily goals',
      'Complete 1 mini course',
      'Finish strong by week end',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'daily_goal_count_in_window',
        targetValue: 5,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
      ChallengeRule(
        ruleType: 'mini_courses_completed',
        targetValue: 1,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );

  static final monthlyMaster = ChallengeTemplate(
    id: 'monthly_master',
    name: 'Monthly Master',
    category: 'mixed',
    difficulty: 'hard',
    description: 'Achieve mastery across all areas in 30 days',
    theme: 'Holistic Excellence',
    targetAudience: '13-18 year olds',
    durationDays: 30,
    coinReward: 300,
    criteria: [
      'Complete 15 daily goals',
      'Complete 2 main goals',
      'Complete 2 mini courses',
      'Write 10 gratitude entries',
    ],
    rules: [
      ChallengeRule(
        ruleType: 'daily_goal_count_in_window',
        targetValue: 15,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
      ChallengeRule(
        ruleType: 'main_goals_completed',
        targetValue: 2,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
      ChallengeRule(
        ruleType: 'mini_courses_completed',
        targetValue: 2,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
      ChallengeRule(
        ruleType: 'gratitude_count_in_window',
        targetValue: 10,
        windowType: 'per_user_enrollment',
        groupId: 'main',
        groupOperator: 'all',
      ),
    ],
  );
}

/// Challenge template model
class ChallengeTemplate {
  final String id;
  final String name;
  final String category;
  final String difficulty;
  final String description;
  final String theme;
  final String targetAudience;
  final int durationDays;
  final int coinReward;
  final List<String> criteria;
  final List<ChallengeRule> rules;

  ChallengeTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.description,
    required this.theme,
    required this.targetAudience,
    required this.durationDays,
    required this.coinReward,
    required this.criteria,
    required this.rules,
  });

  /// Convert template to GeneratedChallenge
  GeneratedChallenge toGeneratedChallenge() {
    return GeneratedChallenge(
      title: name,
      description: description,
      coinReward: coinReward,
      durationDays: durationDays,
      criteria: criteria,
      rules: rules,
      qualityScore: 9.0, // Templates are pre-validated
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'difficulty': difficulty,
      'description': description,
      'theme': theme,
      'targetAudience': targetAudience,
      'durationDays': durationDays,
      'coinReward': coinReward,
      'criteria': criteria,
      'rules': rules.map((r) => r.toJson()).toList(),
    };
  }
}

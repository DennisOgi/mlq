import 'package:flutter/foundation.dart';
import '../models/skill_tree_model.dart';
import 'supabase_service.dart';

class SkillTreeService {
  static final SkillTreeService _instance = SkillTreeService._internal();
  static SkillTreeService get instance => _instance;
  factory SkillTreeService() => _instance;

  SkillTreeService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Define all skills (in production, this would come from database)
  static final List<Skill> _allSkills = [
    // Communication Skills
    Skill(
      id: 'comm_1',
      name: 'Active Listener',
      description: 'Learn to truly hear what others are saying',
      category: SkillCategory.communication,
      level: 1,
      requiredXP: 100,
      iconName: 'hearing',
    ),
    Skill(
      id: 'comm_2',
      name: 'Clear Speaker',
      description: 'Express your ideas clearly and confidently',
      category: SkillCategory.communication,
      level: 2,
      requiredXP: 250,
      prerequisites: ['comm_1'],
      iconName: 'record_voice_over',
    ),
    Skill(
      id: 'comm_3',
      name: 'Storyteller',
      description: 'Engage others with compelling narratives',
      category: SkillCategory.communication,
      level: 3,
      requiredXP: 500,
      prerequisites: ['comm_2'],
      iconName: 'auto_stories',
    ),
    Skill(
      id: 'comm_4',
      name: 'Presenter',
      description: 'Deliver presentations with confidence',
      category: SkillCategory.communication,
      level: 4,
      requiredXP: 1000,
      prerequisites: ['comm_3'],
      unlockedAbility: 'Create public challenges',
      iconName: 'present_to_all',
    ),

    // Teamwork Skills
    Skill(
      id: 'team_1',
      name: 'Team Player',
      description: 'Work well with others towards common goals',
      category: SkillCategory.teamwork,
      level: 1,
      requiredXP: 100,
      iconName: 'groups',
    ),
    Skill(
      id: 'team_2',
      name: 'Collaborator',
      description: 'Actively contribute to group success',
      category: SkillCategory.teamwork,
      level: 2,
      requiredXP: 250,
      prerequisites: ['team_1'],
      iconName: 'handshake',
    ),
    Skill(
      id: 'team_3',
      name: 'Team Leader',
      description: 'Guide and motivate your team',
      category: SkillCategory.teamwork,
      level: 3,
      requiredXP: 500,
      prerequisites: ['team_2'],
      unlockedAbility: 'Create teams',
      iconName: 'supervisor_account',
    ),

    // Problem Solving Skills
    Skill(
      id: 'prob_1',
      name: 'Critical Thinker',
      description: 'Analyze situations carefully',
      category: SkillCategory.problemSolving,
      level: 1,
      requiredXP: 100,
      iconName: 'psychology',
    ),
    Skill(
      id: 'prob_2',
      name: 'Creative Solver',
      description: 'Find innovative solutions',
      category: SkillCategory.problemSolving,
      level: 2,
      requiredXP: 250,
      prerequisites: ['prob_1'],
      iconName: 'lightbulb',
    ),

    // Empathy Skills
    Skill(
      id: 'emp_1',
      name: 'Understanding',
      description: 'Recognize others\' feelings',
      category: SkillCategory.empathy,
      level: 1,
      requiredXP: 100,
      iconName: 'favorite',
    ),
    Skill(
      id: 'emp_2',
      name: 'Compassionate',
      description: 'Show care and concern for others',
      category: SkillCategory.empathy,
      level: 2,
      requiredXP: 250,
      prerequisites: ['emp_1'],
      iconName: 'volunteer_activism',
    ),
    Skill(
      id: 'emp_3',
      name: 'Mentor',
      description: 'Guide and support others',
      category: SkillCategory.empathy,
      level: 3,
      requiredXP: 500,
      prerequisites: ['emp_2'],
      unlockedAbility: 'Become a peer mentor',
      iconName: 'school',
    ),

    // Resilience Skills
    Skill(
      id: 'res_1',
      name: 'Persistent',
      description: 'Keep going when things get tough',
      category: SkillCategory.resilience,
      level: 1,
      requiredXP: 100,
      iconName: 'fitness_center',
    ),
    Skill(
      id: 'res_2',
      name: 'Adaptable',
      description: 'Adjust to new situations',
      category: SkillCategory.resilience,
      level: 2,
      requiredXP: 250,
      prerequisites: ['res_1'],
      iconName: 'change_circle',
    ),
  ];

  List<Skill> getAllSkills() => _allSkills;

  List<Skill> getSkillsByCategory(SkillCategory category) {
    return _allSkills.where((s) => s.category == category).toList();
  }

  Skill? getSkillById(String id) {
    try {
      return _allSkills.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get user's skill progress
  Future<UserSkillProgress> getUserSkillProgress(String userId) async {
    try {
      if (!_supabaseService.isAuthenticated) {
        return _getDefaultProgress(userId);
      }

      final response = await _supabaseService.client
          .from('user_skill_progress')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return _getDefaultProgress(userId);
      }

      return UserSkillProgress.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching skill progress: $e');
      return _getDefaultProgress(userId);
    }
  }

  UserSkillProgress _getDefaultProgress(String userId) {
    return UserSkillProgress(
      userId: userId,
      categoryXP: {
        SkillCategory.communication: 0,
        SkillCategory.teamwork: 0,
        SkillCategory.problemSolving: 0,
        SkillCategory.empathy: 0,
        SkillCategory.resilience: 0,
      },
      unlockedSkillIds: [],
      unlockedAbilities: [],
      totalSkillPoints: 0,
    );
  }

  // Award skill XP based on activity
  Future<void> awardSkillXP({
    required String userId,
    required SkillCategory category,
    required int xp,
  }) async {
    try {
      final progress = await getUserSkillProgress(userId);
      final currentXP = progress.getXPForCategory(category);
      final newXP = currentXP + xp;

      final updatedCategoryXP = Map<SkillCategory, int>.from(progress.categoryXP);
      updatedCategoryXP[category] = newXP;

      // Check for newly unlocked skills
      final newlyUnlocked = _checkForUnlockedSkills(
        progress.unlockedSkillIds,
        updatedCategoryXP,
      );

      final updatedProgress = UserSkillProgress(
        userId: userId,
        categoryXP: updatedCategoryXP,
        unlockedSkillIds: [...progress.unlockedSkillIds, ...newlyUnlocked],
        unlockedAbilities: [
          ...progress.unlockedAbilities,
          ..._getNewAbilities(newlyUnlocked),
        ],
        totalSkillPoints: progress.totalSkillPoints + newlyUnlocked.length,
      );

      if (_supabaseService.isAuthenticated) {
        await _supabaseService.client
            .from('user_skill_progress')
            .upsert(updatedProgress.toJson());
      }

      debugPrint('Awarded $xp XP to ${category.toString().split('.').last}');
    } catch (e) {
      debugPrint('Error awarding skill XP: $e');
    }
  }

  List<String> _checkForUnlockedSkills(
    List<String> currentlyUnlocked,
    Map<SkillCategory, int> categoryXP,
  ) {
    final newlyUnlocked = <String>[];

    for (final skill in _allSkills) {
      if (currentlyUnlocked.contains(skill.id)) continue;

      // Check if user has enough XP
      final userXP = categoryXP[skill.category] ?? 0;
      if (userXP < skill.requiredXP) continue;

      // Check if prerequisites are met
      final prerequisitesMet = skill.prerequisites.every(
        (prereq) => currentlyUnlocked.contains(prereq) || newlyUnlocked.contains(prereq),
      );

      if (prerequisitesMet) {
        newlyUnlocked.add(skill.id);
      }
    }

    return newlyUnlocked;
  }

  List<String> _getNewAbilities(List<String> newlyUnlockedSkillIds) {
    return newlyUnlockedSkillIds
        .map((id) => getSkillById(id))
        .where((skill) => skill?.unlockedAbility != null)
        .map((skill) => skill!.unlockedAbility!)
        .toList();
  }

  // Map goal categories to skill categories
  SkillCategory getSkillCategoryForGoal(String goalCategory) {
    switch (goalCategory.toLowerCase()) {
      case 'academic':
        return SkillCategory.problemSolving;
      case 'social':
        return SkillCategory.communication;
      case 'health':
        return SkillCategory.resilience;
      default:
        return SkillCategory.problemSolving;
    }
  }
}

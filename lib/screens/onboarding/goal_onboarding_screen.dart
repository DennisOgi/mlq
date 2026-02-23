import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class GoalOnboardingScreen extends StatefulWidget {
  const GoalOnboardingScreen({super.key});

  @override
  State<GoalOnboardingScreen> createState() => _GoalOnboardingScreenState();
}

class _GoalOnboardingScreenState extends State<GoalOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Define categories and titles for each page
  final List<GoalCategory> _pageCategories = [
    GoalCategory.academic,
    GoalCategory.social,
    GoalCategory.health,
  ];
  
  final List<String> _titles = [
    'Set Your Academic Goal',
    'Set Your Social Goal',
    'Set Your Health Goal',
  ];
  
  // Goal creation state
  GoalTimeline _selectedTimeline = GoalTimeline.monthly;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  void _nextPage() {
    if (_currentPage < 2) {
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // All goals set, return to home screen
      Navigator.of(context).pop();
    }
  }
  
  Future<void> _createGoal() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a goal title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Get the current page's category
    final currentCategory = _pageCategories[_currentPage];
    
    // Create the goal based on selected timeline
    final MainGoalModel newGoal = _selectedTimeline == GoalTimeline.monthly
        ? MainGoalModel.createMonthlyGoal(
            userId: userProvider.user?.id ?? 'unknown',
            title: _titleController.text,
            category: currentCategory,
            description: _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
          )
        : MainGoalModel.createThreeMonthGoal(
            userId: userProvider.user?.id ?? 'unknown',
            title: _titleController.text,
            category: currentCategory,
            description: _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
          );
    
    try {
      // Add the goal (now async)
      await goalProvider.addMainGoal(newGoal);
      
      // Award coins for setting a goal
      await userProvider.addCoins(0.5);
      
      // Reset form for next goal
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedTimeline = GoalTimeline.monthly;
        // Don't increment _currentPage here as _nextPage will handle it
      });
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Move to next page or finish
      _nextPage();
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving goal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Helper methods for category properties
  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return AppColors.academic;
      case GoalCategory.social:
        return AppColors.social;
      case GoalCategory.health:
        return AppColors.health;
    }
  }

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return Icons.school;
      case GoalCategory.social:
        return Icons.people;
      case GoalCategory.health:
        return Icons.fitness_center;
    }
  }

  String _getCategoryName(GoalCategory category) {
    switch (category) {
      case GoalCategory.academic:
        return 'Academic';
      case GoalCategory.social:
        return 'Social';
      case GoalCategory.health:
        return 'Health';
    }
  }
  
  Widget _buildTimelineOption(
    String title,
    String subtitle,
    GoalTimeline value,
    GoalTimeline groupValue,
    ValueChanged<GoalTimeline> onChanged,
  ) {
    final isSelected = value == groupValue;
    
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary.withOpacity(0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: isSelected ? AppColors.secondary : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.secondary,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Duplicate methods removed
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentPage]),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: List.generate(3, (index) => _buildGoalForm()),
      ),
    );
  }
  
  Widget _buildGoalForm() {
    // Get the current page's category
    final currentCategory = _pageCategories[_currentPage];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: QuestProgressIndicator(
              progress: (_currentPage + 1) / 3,
              height: 8,
              label: 'Goal ${_currentPage + 1} of 3',
              showPercentage: true,
            ),
          ),
          
          // Animated intro text
          Text(
            'Setting main goals helps you focus on what matters most to you.',
            style: AppTextStyles.body,
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 24),
          
          // Goal title
          Text(
            'Goal Title',
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter your goal title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLength: 50,
          ),
          
          const SizedBox(height: 16),
          
          // Goal category (display only - not selectable)
          Text(
            'Goal Category',
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getCategoryColor(currentCategory).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getCategoryColor(currentCategory),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(currentCategory),
                  color: _getCategoryColor(currentCategory),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _getCategoryName(currentCategory),
                  style: AppTextStyles.bodyBold.copyWith(
                    color: _getCategoryColor(currentCategory),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.check_circle,
                  color: _getCategoryColor(currentCategory),
                  size: 24,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Goal timeline
          Text(
            'Goal Timeline',
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              _buildTimelineOption(
                'Monthly Goal',
                'A goal to achieve within one month',
                GoalTimeline.monthly,
                _selectedTimeline,
                (value) {
                  setState(() {
                    _selectedTimeline = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildTimelineOption(
                '3-Month Goal',
                'A bigger goal to achieve within three months',
                GoalTimeline.threeMonth,
                _selectedTimeline,
                (value) {
                  setState(() {
                    _selectedTimeline = value;
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Goal description
          Text(
            'Goal Description (Optional)',
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'Describe your goal in more detail',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 3,
          ),
          
          const SizedBox(height: 32),
          
          // Create goal button
          QuestButton(
            text: _currentPage < 2 ? 'Set Goal & Continue' : 'Complete Setup',
            isFullWidth: true,
            onPressed: _createGoal,
          ),
        ],
      ),
    );
  }
}

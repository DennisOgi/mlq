import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class AnimatedGoalStack extends StatefulWidget {
  final List<DailyGoalModel> goals;
  final DateTime selectedDate;

  const AnimatedGoalStack({
    super.key,
    required this.goals,
    required this.selectedDate,
  });

  @override
  State<AnimatedGoalStack> createState() => _AnimatedGoalStackState();
}

class _AnimatedGoalStackState extends State<AnimatedGoalStack>
    with TickerProviderStateMixin {
  int currentIndex = 0;
  Timer? _shuffleTimer;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    
    // Start shuffling if multiple goals
    if (widget.goals.length > 1) {
      _startShuffling();
    }
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedGoalStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset index if list length shrank
    if (currentIndex >= widget.goals.length) {
      setState(() {
        currentIndex = widget.goals.isEmpty ? 0 : 0;
      });
    }
    // Restart/stop shuffling depending on count
    _shuffleTimer?.cancel();
    if (widget.goals.length > 1) {
      _startShuffling();
    }
  }

  void _startShuffling() {
    _shuffleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _nextGoal();
      }
    });
  }

  void _nextGoal() {
    setState(() {
      currentIndex = (currentIndex + 1) % widget.goals.length;
    });
    
    // Restart slide animation
    _slideController.reset();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.goals.isEmpty) return const SizedBox.shrink();
    if (currentIndex >= widget.goals.length) {
      currentIndex = 0;
    }

    final currentGoal = widget.goals[currentIndex];
    final completedCount = widget.goals.where((g) => g.isCompleted).length;
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.primary.withOpacity(0.02),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(widget.selectedDate),
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedCount of ${widget.goals.length} completed',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (widget.goals.length > 1)
                  Row(
                    children: [
                      // Manual navigation buttons
                      IconButton(
                        onPressed: () {
                          setState(() {
                            currentIndex = currentIndex > 0 
                              ? currentIndex - 1 
                              : widget.goals.length - 1;
                          });
                          _slideController.reset();
                          _slideController.forward();
                        },
                        icon: const Icon(Icons.chevron_left),
                        iconSize: 20,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, 
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${currentIndex + 1}/${widget.goals.length}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _nextGoal();
                        },
                        icon: const Icon(Icons.chevron_right),
                        iconSize: 20,
                      ),
                    ],
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Animated goal content
            SizedBox(
              height: 100,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildGoalCard(currentGoal),
                ),
              ),
            ),
            
            // Progress dots for multiple goals
            if (widget.goals.length > 1) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.goals.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == currentIndex ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == currentIndex
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(DailyGoalModel goal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: goal.isCompleted 
          ? Colors.green.withOpacity(0.1)
          : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: goal.isCompleted 
            ? Colors.green.withOpacity(0.3)
            : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Completion status icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: goal.isCompleted ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              goal.isCompleted ? Icons.check : Icons.schedule,
              color: Colors.white,
              size: 16,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Goal content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  goal.title,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: goal.isCompleted 
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                    decoration: goal.isCompleted 
                      ? TextDecoration.lineThrough
                      : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  goal.isCompleted ? 'Completed' : 'Pending',
                  style: AppTextStyles.caption.copyWith(
                    color: goal.isCompleted 
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // XP badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${goal.xpValue} XP',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
  }
}

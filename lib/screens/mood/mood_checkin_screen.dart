import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/mood_entry_model.dart';
import '../../services/mood_tracking_service.dart';
import '../../providers/user_provider.dart';
import '../../widgets/enhanced_app_bar.dart';

class MoodCheckinScreen extends StatefulWidget {
  final bool isMorning;

  const MoodCheckinScreen({
    super.key,
    this.isMorning = true,
  });

  @override
  State<MoodCheckinScreen> createState() => _MoodCheckinScreenState();
}

class _MoodCheckinScreenState extends State<MoodCheckinScreen> {
  final MoodTrackingService _moodService = MoodTrackingService.instance;
  final TextEditingController _noteController = TextEditingController();
  
  MoodType? _selectedMood;
  final Set<MoodTrigger> _selectedTriggers = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitMoodEntry() async {
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.user?.id;

      if (userId == null) {
        throw Exception('User not found');
      }

      await _moodService.saveMoodEntry(
        userId: userId,
        mood: _selectedMood!,
        isMorning: widget.isMorning,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        triggers: _selectedTriggers.toList(),
      );

      // Award coins for checking in
      userProvider.addCoins(5.0);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mood logged! +5 coins'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving mood: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EnhancedAppBar(
        title: widget.isMorning ? 'Morning Check-in' : 'Evening Reflection',
        showBackButton: true,
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildMoodSelector(),
            const SizedBox(height: 24),
            _buildTriggerSelector(),
            const SizedBox(height: 24),
            _buildNoteInput(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            widget.isMorning ? Icons.wb_sunny : Icons.nightlight_round,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            widget.isMorning
                ? 'How are you feeling this morning?'
                : 'How was your day today?',
            style: AppTextStyles.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check in daily to track your emotional journey',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildMoodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select your mood', style: AppTextStyles.bodyBold),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: MoodType.values.map((mood) {
            final entry = MoodEntryModel(
              id: '',
              userId: '',
              timestamp: DateTime.now(),
              mood: mood,
              triggers: [],
              isMorning: true,
            );
            final isSelected = _selectedMood == mood;

            return InkWell(
              onTap: () => setState(() => _selectedMood = mood),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? entry.moodColor.withOpacity(0.2) : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? entry.moodColor : AppColors.neumorphicDark,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      entry.moodEmoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.moodLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected ? entry.moodColor : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildTriggerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What influenced your mood? (optional)', style: AppTextStyles.bodyBold),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MoodTrigger.values.map((trigger) {
            final isSelected = _selectedTriggers.contains(trigger);
            final label = trigger.toString().split('.').last;

            return FilterChip(
              label: Text(label[0].toUpperCase() + label.substring(1)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTriggers.add(trigger);
                  } else {
                    _selectedTriggers.remove(trigger);
                  }
                });
              },
              selectedColor: AppColors.secondary.withOpacity(0.3),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildNoteInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add a note (optional)', style: AppTextStyles.bodyBold),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 4,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: widget.isMorning
                ? 'What are you looking forward to today?'
                : 'What made today special?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitMoodEntry,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.black)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle),
                  const SizedBox(width: 8),
                  Text(
                    'Submit Check-in (+5 coins)',
                    style: AppTextStyles.button.copyWith(color: Colors.black),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }
}

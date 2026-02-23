import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../providers/gratitude_provider.dart';
import '../screens/gratitude/gratitude_jar_screen.dart';

class GratitudeSlider extends StatelessWidget {
  const GratitudeSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GratitudeProvider>(
      builder: (context, provider, child) {
        // Load entries if not already loaded
        if (provider.entries.isEmpty) {
          provider.loadEntries();
        }
        
        final recentEntries = provider.entries.take(5).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and view all button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gratitude Jar',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GratitudeJarScreen(),
                        ),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Gratitude entries slider
            SizedBox(
              height: 120,
              child: recentEntries.isEmpty
                  ? _buildEmptyState(context)
                  : _buildEntriesSlider(context, recentEntries),
            ),
          ],
        );
      },
    );
  }

  // Build empty state widget
  Widget _buildEmptyState(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GratitudeJarScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.volunteer_activism,
                size: 32,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Start your gratitude journey',
                style: AppTextStyles.bodyBold,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build slider with gratitude entries
  Widget _buildEntriesSlider(BuildContext context, List<GratitudeEntry> entries) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final formattedDate = DateFormat('MMM d').format(entry.date);
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GratitudeJarScreen(),
              ),
            );
          },
          child: Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getMoodColor(entry.mood).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getMoodColor(entry.mood).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and mood
                Row(
                  children: [
                    Text(
                      _getMoodEmoji(entry.mood),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Content
                Expanded(
                  child: Text(
                    entry.content,
                    style: AppTextStyles.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 300), delay: Duration(milliseconds: 50 * index));
      },
    );
  }

  // Get emoji for mood
  String _getMoodEmoji(String mood) {
    switch (mood) {
      case 'happy':
        return '😊';
      case 'grateful':
        return '🙏';
      case 'peaceful':
        return '😌';
      case 'excited':
        return '😃';
      default:
        return '😊';
    }
  }

  // Get color for mood
  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'happy':
        return Colors.amber;
      case 'grateful':
        return Colors.blue;
      case 'peaceful':
        return Colors.green;
      case 'excited':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }
}

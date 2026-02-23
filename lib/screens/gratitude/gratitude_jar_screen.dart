import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/gratitude_provider.dart';
import '../../services/badge_service.dart';
import '../../services/badge_notification_service.dart';

class GratitudeJarScreen extends StatefulWidget {
  const GratitudeJarScreen({super.key});

  @override
  State<GratitudeJarScreen> createState() => _GratitudeJarScreenState();
}

class _GratitudeJarScreenState extends State<GratitudeJarScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _gratitudeController = TextEditingController();
  String _selectedMood = 'happy';
  
  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _notesAnimationController;
  
  // Track if jar is being shaken
  bool _isShaking = false;
  
  // Store original positions of notes for animation
  final Map<int, Offset> _originalPositions = {};
  final Map<int, double> _originalRotations = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize shake animation controller
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // Initialize notes animation controller with longer duration
    _notesAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Add listeners to animation controllers
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });
    
    _notesAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isShaking = false;
        });
        _notesAnimationController.reset();
      }
    });
    
    // Load gratitude entries
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GratitudeProvider>(context, listen: false).loadEntries();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gratitudeController.dispose();
    _shakeController.dispose();
    _notesAnimationController.dispose();
    super.dispose();
  }

  // Show dialog to add a new gratitude entry
  void _showAddGratitudeDialog() {
    final parentContext = context;
    final gratitudeProvider = Provider.of<GratitudeProvider>(context, listen: false);
    
    // Check if user has already posted today
    if (gratitudeProvider.hasPostedToday()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('You\'ve already added a gratitude entry today. Come back tomorrow!'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    
    _gratitudeController.clear();
    _selectedMood = 'happy';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: Text(
          'Add to Gratitude Jar',
          style: AppTextStyles.heading3.copyWith(
            color: AppColors.primary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // XP reward indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '+${GratitudeProvider.gratitudeXpReward} XP',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'What are you grateful for today?',
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _gratitudeController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'I am grateful for...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How do you feel about this?',
                style: AppTextStyles.bodyBold,
              ),
              const SizedBox(height: 8),
              _buildMoodSelector(setDialogState),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_gratitudeController.text.trim().isNotEmpty) {
                final entry = GratitudeEntry(
                  content: _gratitudeController.text.trim(),
                  mood: _selectedMood,
                );
                
                Navigator.pop(context);
                
                try {
                  final xpAwarded = await Provider.of<GratitudeProvider>(parentContext, listen: false)
                      .addEntry(entry);
                  
                  if (mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  xpAwarded 
                                      ? 'Added to your gratitude jar! +${GratitudeProvider.gratitudeXpReward} XP'
                                      : 'Added to your gratitude jar!',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    });

                    // Scan for badges and show popups for any newly earned badges
                    try {
                      final earned = await BadgeService().checkForAchievements();
                      if (earned.isNotEmpty) {
                        for (final b in earned) {
                          try {
                            BadgeNotificationService().showBadgeEarnedNotification(parentContext, b);
                          } catch (_) {}
                        }
                      }
                    } catch (_) {}
                  }
                } catch (e) {
                  if (mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final errorMessage = e.toString().contains('one gratitude entry per day')
                          ? 'You can only add one gratitude entry per day!'
                          : 'Failed to save gratitude entry';
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(child: Text(errorMessage)),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    });
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
        ),
    );
  }

  // Build mood selector widget
  Widget _buildMoodSelector(StateSetter setDialogState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMoodOption('happy', '😊', 'Happy', setDialogState),
        _buildMoodOption('grateful', '🙏', 'Grateful', setDialogState),
        _buildMoodOption('peaceful', '😌', 'Peaceful', setDialogState),
        _buildMoodOption('excited', '😃', 'Excited', setDialogState),
      ],
    );
  }

  // Build individual mood option
  Widget _buildMoodOption(String mood, String emoji, String label, StateSetter setDialogState) {
    final isSelected = _selectedMood == mood;
    
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          _selectedMood = mood;
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.secondary.withOpacity(0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.neumorphicDark,
                width: 2,
              ),
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.secondary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Build list view of gratitude entries
  Widget _buildGratitudeList() {
    return Consumer<GratitudeProvider>(
      builder: (context, provider, child) {
        final entries = provider.entries;
        
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.volunteer_activism,
                  size: 64,
                  color: AppColors.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your gratitude jar is empty',
                  style: AppTextStyles.heading3,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first gratitude entry by tapping the + button',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(entry.date);
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _getMoodEmoji(entry.mood),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.content,
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Build jar view of gratitude entries
  Widget _buildGratitudeJar() {
    return Consumer<GratitudeProvider>(
      builder: (context, provider, child) {
        final entries = provider.entries;
        
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Empty jar with animation
                Container(
                  height: 250,
                  width: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Jar lid
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.7),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Jar shine effect
                      Positioned(
                        top: 50,
                        left: 20,
                        child: Container(
                          height: 100,
                          width: 20,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      
                      // Empty jar message
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_emotions_outlined,
                              size: 50,
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your jar is empty',
                              style: AppTextStyles.heading3.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Add your first gratitude note',
                                style: AppTextStyles.body.copyWith(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Add first note button
                ElevatedButton.icon(
                  onPressed: _showAddGratitudeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Note'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          );
        }
        
        return Stack(
          children: [
            // Jar container
            Center(
              child: AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  // Calculate jar shake offset
                  double offsetX = 0.0;
                  double offsetY = 0.0;
                  
                  if (_isShaking) {
                    final progress = _shakeController.value;
                    final amplitude = 8.0;
                    offsetX = sin(progress * pi * 8) * amplitude * (1.0 - progress);
                    offsetY = sin(progress * pi * 6) * amplitude * 0.5 * (1.0 - progress);
                  }
                  
                  return Transform.translate(
                    offset: Offset(offsetX, offsetY),
                    child: child!,
                  );
                },
                child: Container(
                  height: 350,
                  width: 250,
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Stack(
                    // Ensure notes never render outside the jar bounds
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Jar lid
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.7),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Jar shine effect
                      Positioned(
                        top: 50,
                        left: 20,
                        child: Container(
                          height: 150,
                          width: 20,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      
                      // Gratitude notes container
                      Positioned(
                        top: 50,
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: _buildGratitudeNotes(entries),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Shake jar button
            Positioned(
              bottom: 100, 
              right: 20,
              child: FloatingActionButton.small(
                onPressed: _isShaking ? null : _shakeJar,
                tooltip: 'Shake jar',
                backgroundColor:
                    _isShaking ? Colors.grey : AppColors.accent2,
                heroTag: 'gratitude_shake_fab',
                child: const Icon(Icons.shuffle),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Shake the jar and its contents with physics animation
  void _shakeJar() {
    // Prevent multiple shakes at once
    if (_isShaking) return;
    
    setState(() {
      _isShaking = true;
    });
    
    // Play haptic feedback if available
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore if haptic feedback is not available
    }
    
    // Start jar shake animation
    _shakeController.forward();
    
    // Start notes animation
    _notesAnimationController.forward();
    
    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shaking your gratitude jar! 🌟'),
        duration: Duration(seconds: 1),
        backgroundColor: AppColors.secondary,
      ),
    );
  }
  
  // Build the gratitude notes inside the jar
  Widget _buildGratitudeNotes(List<GratitudeEntry> entries) {
    // Limit to showing 15 notes maximum
    final displayEntries = entries.length > 15 ? entries.sublist(0, 15) : entries;
    // Dynamically scale notes as the jar fills up to avoid overflow/overlap
    final int n = displayEntries.length;
    final double scale = n <= 8 ? 1.0 : (n >= 15 ? 0.78 : (1.0 - (n - 8) * 0.03));
    
    return AnimatedBuilder(
      animation: _notesAnimationController,
      builder: (context, child) {
        return Stack(
          // Keep content inside the jar area
          clipBehavior: Clip.hardEdge,
          children: List.generate(
            displayEntries.length,
            (index) {
              final entry = displayEntries[index];
              
              // Create a more natural distribution of notes
              final random = (index * 31 + 17) % 360;
              // Slightly reduce scatter ranges to keep within padding
              final baseXPos = 16 + (random % 120).toDouble();
              final baseYPos = 18 + (random % 180).toDouble();
              final baseRotation = (random % 60 - 30) / 10;
              
              // Store original positions if not already stored
              if (!_originalPositions.containsKey(index)) {
                _originalPositions[index] = Offset(baseXPos, baseYPos);
                _originalRotations[index] = baseRotation;
              }
              
              // Calculate physics-based animation for position and rotation
              double xPos = baseXPos;
              double yPos = baseYPos;
              double rotation = baseRotation;
              
              if (_isShaking) {
                // Generate unique random movements for each note
                final shakeProgress = _notesAnimationController.value;
                final shakePhase = index * 0.3; // Different phase for each note
                
                // Physics-based movement calculation
                final amplitude = 30.0;
                final decay = 1.0 - shakeProgress; // Movement decreases over time
                
                // Sine wave movement with decay
                final xOffset = sin((shakeProgress * 10 + shakePhase) * 2 * pi) * amplitude * decay;
                final yOffset = cos((shakeProgress * 12 + shakePhase) * 2 * pi) * amplitude * decay;
                
                // Apply movement
                xPos = baseXPos + xOffset;
                yPos = baseYPos + yOffset;
                
                // Add rotation effect
                final rotationAmplitude = 0.5; // Max rotation in radians
                final rotationOffset = sin((shakeProgress * 8 + shakePhase) * pi * 2) * rotationAmplitude * decay;
                rotation = baseRotation + rotationOffset;
              }
              
              return Positioned(
                left: xPos,
                top: yPos,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: () => _showGratitudeNoteDetail(context, entry),
                      child: _buildGratitudeNote(entry, index),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  // Build an individual gratitude note with improved styling
  Widget _buildGratitudeNote(GratitudeEntry entry, int index) {
    final color = _getMoodColor(entry.mood);
    final noteColors = [
      Colors.yellow.shade100,
      Colors.pink.shade50,
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
    ];
    final noteColor = noteColors[index % noteColors.length];
    
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: noteColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            spreadRadius: 0.5,
            offset: const Offset(1, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mood emoji at the top
          Center(
            child: _getMoodEmoji(entry.mood),
          ),
          const SizedBox(height: 4),
          // Truncated content
          Text(
            entry.content.length > 20
                ? '${entry.content.substring(0, 20)}...'
                : entry.content,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 10,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  // Show a detailed view of the gratitude note
  void _showGratitudeNoteDetail(BuildContext context, GratitudeEntry entry) {
    final color = _getMoodColor(entry.mood);
    final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(entry.date);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: color.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with emoji and date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: _getMoodEmoji(entry.mood),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gratitude Note',
                          style: AppTextStyles.heading3.copyWith(color: color),
                        ),
                        Text(
                          formattedDate,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Divider
              Divider(color: color.withOpacity(0.3)),
              const SizedBox(height: 16),
              // Content
              Text(
                entry.content,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get emoji for mood
  Widget _getMoodEmoji(String mood) {
    String emoji;
    switch (mood.toLowerCase()) {
      case 'happy':
        emoji = '😊';
        break;
      case 'grateful':
        emoji = '🙏';
        break;
      case 'blessed':
        emoji = '✨';
        break;
      case 'peaceful':
        emoji = '😌';
        break;
      case 'excited':
        emoji = '🎉';
        break;
      default:
        emoji = '❤️';
    }
    
    return Text(emoji, style: const TextStyle(fontSize: 18));
  }

  // Get color for mood
  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'grateful':
        return Theme.of(context).primaryColor;
      case 'blessed':
        return Colors.purple;
      case 'peaceful':
        return Colors.lightBlue;
      case 'excited':
        return Colors.orange;
      default:
        return Theme.of(context).primaryColor.withOpacity(0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gratitude Jar'),
        backgroundColor: AppColors.primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.transparent, // Remove the underline
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(text: 'List View'),
            Tab(text: 'Jar View'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGratitudeList(),
          _buildGratitudeJar(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGratitudeDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}

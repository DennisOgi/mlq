import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/award_xp_dialog.dart';

class ChallengeParticipantsScreen extends StatefulWidget {
  final String challengeId;
  final String challengeTitle;

  const ChallengeParticipantsScreen({
    Key? key,
    required this.challengeId,
    required this.challengeTitle,
  }) : super(key: key);

  @override
  State<ChallengeParticipantsScreen> createState() => _ChallengeParticipantsScreenState();
}

class _ChallengeParticipantsScreenState extends State<ChallengeParticipantsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final participants = await AdminService.instance.getChallengeParticipants(widget.challengeId);
      setState(() {
        _participants = participants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading participants: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Participants: ${widget.challengeTitle}'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadParticipants,
              child: _participants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No participants yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No one has joined this challenge yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _participants.length,
                      itemBuilder: (context, index) {
                        final participant = _participants[index];
                        final user = participant['users'] as Map<String, dynamic>;
                        final name = user['name'] as String? ?? 'Unknown';
                        final email = user['email'] as String? ?? 'No email';
                        final joinDate = DateTime.tryParse(participant['joined_at'] ?? '') ?? DateTime.now();
                        final progress = participant['progress'] as int? ?? 0;
                        final completed = participant['completed'] as bool? ?? false;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (completed)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.tertiary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Completed',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Joined: ${_formatDate(joinDate)}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Progress: $progress%',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: progress / 100,
                                            backgroundColor: Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              completed ? AppColors.tertiary : AppColors.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Display awarded XP if any
                                    if (participant['xp_awarded'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${participant['xp_awarded']} XP Awarded',
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Award XP button
                                    ElevatedButton.icon(
                                      onPressed: () => _showAwardXpDialog(
                                        userId: user['id'] as String,
                                        userName: name,
                                        userEmail: email,
                                        isWinner: participant['is_winner'] == true,
                                        previousXp: participant['xp_awarded'] as int? ?? 0,
                                      ),
                                      icon: const Icon(Icons.emoji_events, size: 16),
                                      label: Text(participant['is_winner'] == true ? 'Update XP' : 'Award XP'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.tertiary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Future<void> _showAwardXpDialog({
    required String userId,
    required String userName,
    required String userEmail,
    required bool isWinner,
    required int previousXp,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AwardXpDialog(
        userName: userName,
        userEmail: userEmail,
        isWinner: isWinner,
        previousXp: previousXp,
      ),
    );
    
    if (result != null && mounted) {
      final int xpAmount = result['xpAmount'] as int;
      final bool markAsWinner = result['markAsWinner'] as bool;
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        final success = await AdminService.instance.awardChallengeXp(
          challengeId: widget.challengeId,
          userId: userId,
          xpAmount: xpAmount,
          markAsWinner: markAsWinner,
        );
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully awarded $xpAmount XP to $userName'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reload participants to update UI
          await _loadParticipants();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to award XP. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error awarding XP: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}

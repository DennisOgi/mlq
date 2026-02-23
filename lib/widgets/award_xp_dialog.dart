import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AwardXpDialog extends StatefulWidget {
  final String userName;
  final String userEmail;
  final bool isWinner;
  final int previousXp;

  const AwardXpDialog({
    Key? key,
    required this.userName,
    required this.userEmail,
    required this.isWinner,
    required this.previousXp,
  }) : super(key: key);

  @override
  State<AwardXpDialog> createState() => _AwardXpDialogState();
}

class _AwardXpDialogState extends State<AwardXpDialog> {
  late TextEditingController _xpController;
  late bool _markAsWinner;
  
  @override
  void initState() {
    super.initState();
    _xpController = TextEditingController(
      text: widget.previousXp > 0 ? widget.previousXp.toString() : '50'
    );
    _markAsWinner = widget.isWinner || widget.previousXp == 0;
  }
  
  @override
  void dispose() {
    _xpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: AppColors.tertiary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.previousXp > 0 ? 'Update XP Award' : 'Award XP to Winner',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Participant: ${widget.userName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              widget.userEmail,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'XP Amount to Award:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _xpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'Enter XP amount',
                prefixIcon: const Icon(Icons.star_border),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _markAsWinner,
                  onChanged: (value) {
                    setState(() {
                      _markAsWinner = value ?? true;
                    });
                  },
                  activeColor: AppColors.tertiary,
                ),
                const Text(
                  'Mark as Challenge Winner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Winners appear on the challenge leaderboard and receive a special badge.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Parse XP value
                    final xpText = _xpController.text.trim();
                    final xpAmount = int.tryParse(xpText);
                    
                    if (xpAmount == null || xpAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid XP amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    // Return result
                    Navigator.of(context).pop({
                      'xpAmount': xpAmount,
                      'markAsWinner': _markAsWinner,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(widget.previousXp > 0 ? 'Update' : 'Award XP'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

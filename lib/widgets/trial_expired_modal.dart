import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../screens/subscription/upgrade_subscription_screen.dart';

class TrialExpiredModal extends StatelessWidget {
  const TrialExpiredModal({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.lock_clock, color: AppColors.primary, size: 28),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Trial Expired',
              style: AppTextStyles.heading3,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your 14-day free trial has ended.',
              style: AppTextStyles.body,
            ),
            SizedBox(height: 16),
            Text(
              'Subscribe to continue accessing:',
              style: AppTextStyles.bodyBold,
            ),
            SizedBox(height: 12),
            _buildFeatureItem('✅ Mini Courses'),
            _buildFeatureItem('✅ Basic Challenges'),
            _buildFeatureItem('✅ Daily Goal Tracker'),
            _buildFeatureItem('✅ Gratitude Journal'),
            _buildFeatureItem('✅ AI Coach'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Start from just ₦50/month',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UpgradeSubscriptionScreen(
                  planId: 'premium_monthly',
                  planName: 'Premium',
                  price: 5000,
                  duration: 'Monthly',
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('Subscribe Now'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 8),
          Text(text, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

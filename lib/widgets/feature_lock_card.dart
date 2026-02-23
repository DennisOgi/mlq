import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../screens/subscription/upgrade_subscription_screen.dart';

class FeatureLockCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const FeatureLockCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(24),
          child: Stack(
            children: [
              // Blurred/faded content
              Opacity(
                opacity: 0.3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 64, color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      title,
                      style: AppTextStyles.heading3,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      description,
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Lock overlay
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock,
                        size: 48,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Subscribe to Unlock',
                      style: AppTextStyles.bodyBold.copyWith(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
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
                      icon: Icon(Icons.star),
                      label: Text('View Plans'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

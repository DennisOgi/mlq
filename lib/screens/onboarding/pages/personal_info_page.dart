import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../constants/app_constants.dart';
import '../../../widgets/quest_button.dart';
import '../../auth/login_screen.dart';
import '../../legal/legal_markdown_screen.dart';

class PersonalInfoPage extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController parentEmailController;
  final TextEditingController dobController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool useParentEmail;
  final bool agreedToTerms;
  final DateTime selectedDate;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final ValueChanged<bool> onToggleParentEmail;
  final ValueChanged<bool> onToggleTerms;
  final VoidCallback onPickDate;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PersonalInfoPage({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.parentEmailController,
    required this.dobController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.useParentEmail,
    required this.agreedToTerms,
    required this.selectedDate,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.onToggleParentEmail,
    required this.onToggleTerms,
    required this.onPickDate,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell us about yourself',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 20),
            Text(
              'Your name',
              style: AppTextStyles.bodyBold,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your email',
              style: AppTextStyles.bodyBold,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.accent1, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.accent1, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.accent1, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create a password',
              style: AppTextStyles.bodyBold,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                hintText: 'Create a password',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.secondary, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.secondary, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.secondary, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: onTogglePasswordVisibility,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Confirm password',
              style: AppTextStyles.bodyBold,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Re-enter your password',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.secondary, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.secondary, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.secondary, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: onToggleConfirmPasswordVisibility,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: useParentEmail,
                  activeColor: AppColors.primary,
                  onChanged: (value) => onToggleParentEmail(value ?? false),
                ),
                Expanded(
                  child: Text(
                    'Add parent email for weekly reports',
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
            if (useParentEmail) ...[
              const SizedBox(height: 10),
              TextField(
                controller: parentEmailController,
                decoration: InputDecoration(
                  labelText: 'Parent Email',
                  hintText: 'Enter parent/guardian email',
                  prefixIcon: const Icon(Icons.family_restroom),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.tertiary, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.tertiary, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.tertiary, width: 2),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Your date of birth',
              style: AppTextStyles.bodyBold,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onPickDate,
              child: AbsorbPointer(
                child: TextField(
                  controller: dobController,
                  decoration: InputDecoration(
                    hintText: 'DD/MM/YYYY',
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: const Icon(Icons.calendar_today,
                        color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.tertiary, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.tertiary, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.tertiary, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: agreedToTerms,
                  activeColor: AppColors.primary,
                  onChanged: (v) => onToggleTerms(v ?? false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      children: [
                        Text('I agree to the ', style: AppTextStyles.body),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TermsScreen()),
                          ),
                          child: Text(
                            'Terms & Conditions',
                            style: AppTextStyles.bodyBold
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                        Text('.', style: AppTextStyles.body),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTextStyles.body,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text(
                      'Log in',
                      style: AppTextStyles.bodyBold
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Navigation buttons
            Row(
              children: [
                Expanded(
                  child: QuestButton(
                    text: 'Back',
                    type: QuestButtonType.outline,
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: QuestButton(
                    text: 'Next',
                    type: QuestButtonType.primary,
                    icon: Icons.arrow_forward,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
  }
}

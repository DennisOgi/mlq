import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../main.dart';
import '../../services/subscription_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _emailController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  DateTime? _selectedBirthDate;

  final List<String> _interests = [];
  final List<String> _availableInterests = [
    'Leadership',
    'Science',
    'Art',
    'Sports',
    'Music',
    'Reading',
    'Math',
    'Coding',
    'Nature',
    'History',
    'Writing',
    'Public Speaking'
  ];

  String? _selectedSchoolId; // Optional school selection
  bool _loadingSchools = false;

  @override
  void initState() {
    super.initState();
    // Load schools after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      setState(() => _loadingSchools = true);
      await userProvider.loadSchools();
      if (mounted) setState(() => _loadingSchools = false);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdateController.dispose();
    _emailController.dispose();
    _parentEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    final hasHadBirthdayThisYear = (today.month > birthDate.month) ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    // Allow a reasonable range for 5-18 to pick, but validate later for 8-14
    final firstDate = DateTime(now.year - 18, now.month, now.day);
    final lastDate = DateTime(now.year - 5, now.month, now.day);
    final initialDate =
        _selectedBirthDate ?? DateTime(now.year - 10, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select your birthday',
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = DateTime(picked.year, picked.month, picked.day);
        _birthdateController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final age = _calculateAge(_selectedBirthDate!);

      await userProvider.completeOnboarding(
        name: _nameController.text.trim(),
        age: age,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        parentEmail: _parentEmailController.text.trim().isNotEmpty
            ? _parentEmailController.text.trim()
            : _emailController.text.trim(),
        interests: _interests,
      );

      // Grant 2-week free trial subscription
      try {
        final subscriptionService = SubscriptionService();
        final userId = userProvider.user?.id;
        if (userId != null) {
          await subscriptionService.activateTrialSubscription(userId);
          debugPrint('✅ Trial subscription granted to new user');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to grant trial subscription: $e');
        // Don't fail signup if trial creation fails
      }

      // Auto-assign school by email domain (e.g., wellspring.org → Wellspring College)
      try {
        final emailDomain =
            _emailController.text.trim().split('@').last.toLowerCase();
        if (emailDomain == 'wellspring.org') {
          // Ensure schools are loaded
          await userProvider.loadSchools(force: true);
          final match = userProvider.schools.firstWhere(
            (s) =>
                (s['name'] as String?)?.toLowerCase() == 'wellspring college',
            orElse: () => {},
          );
          if (match.isNotEmpty) {
            await userProvider.setUserSchool(match['id'] as String?);
          }
        }
      } catch (_) {}

      if (!mounted) return;

      // Show success animation before navigating
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome to My Leadership Quest, ${_nameController.text}!',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to home screen after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      });
    } catch (e) {
      final message = 'Error creating account: ${e.toString()}';
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Logo and app name
                  Center(
                    child: Image.asset(
                      'assets/images/questor 3.png',
                      height: 100,
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.0, 1.0),
                        duration: 600.ms,
                      ),
                  const SizedBox(height: 16),
                  Text(
                    'Join the Quest!',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Create your account to start your leadership journey',
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                  const SizedBox(height: 24),

                  // Error message if any
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().shake(duration: 300.ms),
                  const SizedBox(height: 16),

                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      hintText: 'What should we call you?',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.accent1,
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                  const SizedBox(height: 16),

                  // Birthday field (date picker)
                  TextFormField(
                    controller: _birthdateController,
                    readOnly: true,
                    onTap: _pickBirthDate,
                    decoration: InputDecoration(
                      labelText: 'Your Birthday',
                      hintText: 'Select your birthday',
                      prefixIcon: const Icon(Icons.cake),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.secondary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (_selectedBirthDate == null) {
                        return 'Please select your birthday';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
                  const SizedBox(height: 16),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Your Email',
                      hintText: 'Enter your email address',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.tertiary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
                  const SizedBox(height: 16),

                  // Parent Email field (optional)
                  TextFormField(
                    controller: _parentEmailController,
                    decoration: InputDecoration(
                      labelText: 'Parent Email (Optional)',
                      hintText: 'For weekly progress reports',
                      prefixIcon: const Icon(Icons.family_restroom),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.accent2,
                          width: 1.5,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email';
                        }
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 600.ms, delay: 900.ms),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Create a secure password',
                      prefixIcon: const Icon(Icons.lock),
                      helperText:
                          'At least 8 characters with letters and numbers',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      final hasMinLen = value.length >= 8;
                      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
                      final hasNumber = RegExp(r'\d').hasMatch(value);
                      if (!(hasMinLen && hasLetter && hasNumber)) {
                        return 'Password must be at least 8 characters and include letters and numbers';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
                  const SizedBox(height: 16),

                  // Confirm Password field
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Enter your password again',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.secondary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 600.ms, delay: 1100.ms),
                  const SizedBox(height: 24),

                  // Interests section
                  Text(
                    'What are you interested in? (Optional)',
                    style: AppTextStyles.bodyBold,
                    textAlign: TextAlign.left,
                  ).animate().fadeIn(duration: 600.ms, delay: 1200.ms),
                  const SizedBox(height: 8),

                  // Interest chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableInterests.map((interest) {
                      final isSelected = _interests.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        selectedColor: AppColors.secondary.withOpacity(0.3),
                        checkmarkColor: AppColors.secondary,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _interests.add(interest);
                            } else {
                              _interests.remove(interest);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ).animate().fadeIn(duration: 600.ms, delay: 1300.ms),
                  const SizedBox(height: 32),

                  // School selection removed: automatic assignment by domain during signup
                  const SizedBox(height: 24),

                  // Sign up button
                  QuestButton(
                    text: 'Create Account',
                    onPressed: _isLoading ? null : _signup,
                    isLoading: _isLoading,
                  ).animate().fadeIn(duration: 600.ms, delay: 1400.ms),
                  const SizedBox(height: 16),

                  // Login option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTextStyles.body,
                      ),
                      TextButton(
                        onPressed: _navigateToLogin,
                        child: Text(
                          'Login',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms, delay: 1500.ms),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

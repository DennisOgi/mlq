import 'package:flutter/material.dart';
import 'package:my_leadership_quest/models/main_goal_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:uuid/uuid.dart';

import '../../constants/app_constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'package:my_leadership_quest/main.dart';
import '../legal/legal_markdown_screen.dart';
import '../auth/login_screen.dart';
import '../../services/config_service.dart';
import '../../services/payment_service.dart';
import '../../services/subscription_service.dart';
import '../../services/push_notification_service.dart';
import 'pages/welcome_page.dart';
import 'pages/goal_intro_page.dart';
import 'pages/main_daily_goals_page.dart';
import 'pages/meet_questor_page.dart';
import 'pages/personal_info_page.dart';
import 'pages/interests_page.dart';
import 'pages/permissions_page.dart';
import 'pages/start_quest_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // Scroll controller for browsing subscription tiers horizontally via arrows
  final ScrollController _tierScrollController = ScrollController();
  final Uuid _uuid = Uuid();

  // User information to collect during onboarding
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(
      text:
          '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year - 10}');
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _useParentEmail = false;
  List<String> _selectedInterests = [];
  DateTime _selectedDate =
      DateTime.now().subtract(const Duration(days: 365 * 10));
  String? _selectedSchoolId; // optional school selection
  bool _isStartingQuest = false; // loading state for final CTA

  final List<String> _availableInterests = [
    'Creative writing',
    'Sports',
    'Science',
    'Art',
    'Singing',
    'Math whiz',
    'Writing',
    'Coding',
    'Public speaking',
    'History',
  ];

  // Add state for subscription selection
  int _selectedTierIndex = -1; // -1 means no selection
  String _selectedPlanPeriod = 'Monthly';
  bool _showingPaymentScreen = false;
  bool _processingPayment = false;
  bool _agreedToTerms = false;

  // Pricing and coin information
  final Map<String, Map<String, Map<String, dynamic>>> _tierInfo = {
    'Basic': {
      'Monthly': {'price': '₦2,500', 'coins': 1000},
      'Quarterly': {'price': '₦7,000', 'coins': 3000},
      'Yearly': {'price': '₦25,000', 'coins': 12000},
    },
    'Premium': {
      'Monthly': {'price': '₦5,000', 'coins': 2100},
      'Quarterly': {'price': '₦14,000', 'coins': 6300},
      'Yearly': {'price': '₦50,000', 'coins': 25200},
    },
  };

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _parentEmailController.dispose();
    _dobController.dispose();
    _tierScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load schools after first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<UserProvider>(context, listen: false).loadSchools();
      } catch (_) {}
    });
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage < 8) {
      // Updated to 8 pages (removed subscription)
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showPaymentSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment successful! Welcome to MLQ Premium!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPaymentError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    // Validate required fields
    if (_nameController.text.isEmpty) {
      _showErrorSnackBar('Please enter your name');
      return;
    }

    if (_emailController.text.isEmpty) {
      _showErrorSnackBar('Please enter your email');
      return;
    }

    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      _showErrorSnackBar('Please enter a valid email address');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar('Please enter a password');
      return;
    }

    // Match backend rules: at least 8 characters, includes letters and numbers
    final _pwd = _passwordController.text;
    final _hasMinLen = _pwd.length >= 8;
    final _hasLetter = RegExp(r'[A-Za-z]').hasMatch(_pwd);
    final _hasNumber = RegExp(r'[0-9]').hasMatch(_pwd);
    if (!(_hasMinLen && _hasLetter && _hasNumber)) {
      _showErrorSnackBar(
          'Password must be at least 8 characters and include letters and numbers');
      return;
    }

    // If parent email is enabled but empty, show error
    if (_useParentEmail && _parentEmailController.text.isEmpty) {
      _showErrorSnackBar('Please enter your parent\'s email');
      return;
    }

    // If parent email is provided, validate it
    if (_useParentEmail &&
        (!_parentEmailController.text.contains('@') ||
            !_parentEmailController.text.contains('.'))) {
      _showErrorSnackBar('Please enter a valid parent email address');
      return;
    }

    // Begin async submission
    if (mounted) setState(() => _isStartingQuest = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // Calculate age from date of birth
      final now = DateTime.now();
      final age = now.year -
          _selectedDate.year -
          (now.month > _selectedDate.month ||
                  (now.month == _selectedDate.month &&
                      now.day >= _selectedDate.day)
              ? 0
              : 1);

      // Register the user with Supabase
      final success = await userProvider.register(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        age: age,
        parentEmail: _useParentEmail ? _parentEmailController.text : null,
      );

      if (success) {
        // If a school was selected, update the user's school profile field
        if (_selectedSchoolId != null) {
          try {
            await userProvider.setUserSchool(_selectedSchoolId);
          } catch (e) {
            // Non-fatal: continue even if school update fails
            debugPrint('Failed to set user school during onboarding: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'We could not update your school right now. You can set it later in Profile.',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          }
        }

        // Assign trial plan to new users (if no school subscription)
        try {
          final subscriptionService = SubscriptionService();
          final userId = userProvider.user?.id;
          if (userId != null) {
            // Check if user already has a subscription (from school)
            final hasSubscription =
                await subscriptionService.hasActiveSubscription(userId);
            if (!hasSubscription) {
              // Assign 14-day trial plan
              await subscriptionService.assignTrialPlan(userId);
              debugPrint('Trial plan assigned to new user: $userId');
            }
          }
        } catch (e) {
          // Non-fatal: continue even if trial assignment fails
          debugPrint('Failed to assign trial plan during onboarding: $e');
        }
        // Registration successful
        // Navigate to the main navigation screen without re-instantiating MyApp/MaterialApp
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const MainNavigationScreen()),
            (route) => false,
          );
        }
      } else {
        final err = userProvider.lastErrorMessage;
        _showErrorSnackBar(
            err ?? 'Failed to create account. Please try again.');
      }
    } catch (e) {
      debugPrint('Onboarding completion error: $e');
      final errorMessage = e.toString();
      if (errorMessage.contains('Taking longer than usual')) {
        _showErrorSnackBar(
            'Network is slow. Please wait a moment and try again.');
      } else if (errorMessage.contains('offline') ||
          errorMessage.contains('internet')) {
        _showErrorSnackBar(
            'Please check your internet connection and try again.');
      } else {
        _showErrorSnackBar('Error creating account: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isStartingQuest = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // Payment screen widget
  Widget _buildPaymentScreen() {
    final tierNames = ['Basic', 'Premium'];
    final tierIndex =
        _selectedTierIndex - 1; // Convert to 0-based index for the arrays
    final tierName = tierNames[tierIndex];

    // Get price and coins based on selected tier and period
    final priceInfo = _tierInfo[tierName]![_selectedPlanPeriod]!;
    final price = priceInfo['price'];
    final coins = priceInfo['coins'];

    String periodSuffix = _selectedPlanPeriod == 'Monthly'
        ? '/month'
        : _selectedPlanPeriod == 'Quarterly'
            ? '/quarter'
            : '/year';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              setState(() {
                // Return to the subscription page
                _showingPaymentScreen = false;
                // Move back to subscription tier selection page (index 8 = subscription tiers)
                _currentPage = 8;
              });

              // Defer the jump until after the frame so the controller is attached
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(8);
                }
              });
            },
            child: Row(
              children: [
                const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                Container(width: 8),
                Text('Back to Plans', style: AppTextStyles.bodyBold),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  final target = (_tierScrollController.offset - 260).clamp(
                      0.0, _tierScrollController.position.maxScrollExtent);
                  _tierScrollController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () {
                  final target = (_tierScrollController.offset + 260).clamp(
                      0.0, _tierScrollController.position.maxScrollExtent);
                  _tierScrollController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ],
          ),

          // Arrow navigation for tiers (prevents conflicting horizontal swipes with outer PageView)
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: AppColors.primary, size: 28),
                onPressed: () {
                  final target = (_tierScrollController.offset - 260).clamp(
                      0.0, _tierScrollController.position.maxScrollExtent);
                  _tierScrollController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios,
                    color: AppColors.primary, size: 28),
                onPressed: () {
                  final target = (_tierScrollController.offset + 260).clamp(
                      0.0, _tierScrollController.position.maxScrollExtent);
                  _tierScrollController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ],
          ),
          Container(height: 24),

          // Payment header
          Text(
            'Complete Your Purchase',
            style: AppTextStyles.heading2,
          ),
          Container(height: 8),
          Text(
            'You\'re signing up for the ${tierNames[tierIndex]} plan with ${_selectedPlanPeriod.toLowerCase()} billing.',
            style: AppTextStyles.body,
          ),
          Container(height: 24),

          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order Summary', style: AppTextStyles.bodyBold),
                Container(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '${tierNames[tierIndex]} Plan (${_selectedPlanPeriod.toLowerCase()})',
                        style: AppTextStyles.body),
                    Text('$price$periodSuffix', style: AppTextStyles.bodyBold),
                  ],
                ),
                Container(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Coins', style: AppTextStyles.body),
                    Text('$coins coins', style: AppTextStyles.bodyBold),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: AppTextStyles.bodyBold),
                    Text('$price', style: AppTextStyles.heading3),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 24),

          // Payment form (mock)
          Text('Payment Details', style: AppTextStyles.bodyBold),
          Container(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Card number field
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Card Number',
                    hintText: '1234 5678 9012 3456',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Container(height: 16),

                // Expiry and CVV
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Expiry Date',
                          hintText: 'MM/YY',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Container(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'CVV',
                          hintText: '123',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),

          // Complete purchase button
          Center(
            child: QuestButton(
              text: 'Complete Purchase',
              type: QuestButtonType.primary,
              onPressed: () {
                // In a real app, this would process the payment
                // For now, just move to the final "Start Your Quest" screen
                setState(() {
                  _showingPaymentScreen = false;
                });

                // Use Future.delayed to ensure setState has completed
                Future.delayed(Duration.zero, () {
                  // Jump directly to the final page (Start Your Quest screen)
                  _pageController.animateToPage(
                    9, // Index of the final page
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If showing payment screen, render that instead of the normal flow
    if (_showingPaymentScreen) {
      return WillPopScope(
        onWillPop: () async {
          // Back button on payment screen returns to subscription page
          setState(() {
            _showingPaymentScreen = false;
          });
          return false; // Prevent app exit
        },
        child: Scaffold(
          body: SafeArea(
            child: _buildPaymentScreen(),
          ),
        ),
      );
    }

    // Otherwise show the normal onboarding flow
    return WillPopScope(
      onWillPop: () async {
        // If on first page (welcome), allow exit
        if (_currentPage == 0) {
          return true; // Allow pop (exit app)
        }

        // Otherwise, go to previous page
        _previousPage();
        return false; // Prevent pop (stay in app)
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Page content (full screen, no SafeArea)
            PageView(
              controller: _pageController,
              physics: _showingPaymentScreen
                  ? const NeverScrollableScrollPhysics()
                  : null,
              onPageChanged: (page) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _currentPage = page;
                });
                // Update the OnboardingProvider to track if we're on the subscription page
                Provider.of<OnboardingProvider>(context, listen: false)
                    .setCurrentPage(page);
              },
              children: [
                WelcomePage(onNext: _nextPage), // 0
                GoalIntroPage(onNext: _nextPage, onBack: _previousPage), // 1
                MainDailyGoalsPage(
                    onNext: _nextPage, onBack: _previousPage), // 2
                MeetQuestorPage(onNext: _nextPage, onBack: _previousPage), // 3
                PersonalInfoPage(
                  nameController: _nameController,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  confirmPasswordController: _confirmPasswordController,
                  parentEmailController: _parentEmailController,
                  dobController: _dobController,
                  obscurePassword: _obscurePassword,
                  obscureConfirmPassword: _obscureConfirmPassword,
                  useParentEmail: _useParentEmail,
                  agreedToTerms: _agreedToTerms,
                  selectedDate: _selectedDate,
                  onTogglePasswordVisibility: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  onToggleConfirmPasswordVisibility: () {
                    setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                  onToggleParentEmail: (value) {
                    setState(() => _useParentEmail = value);
                  },
                  onToggleTerms: (value) {
                    setState(() => _agreedToTerms = value);
                  },
                  onPickDate: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              onSurface: AppColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != _selectedDate) {
                      setState(() {
                        _selectedDate = picked;
                        _dobController.text =
                            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                      });
                    }
                  },
                  onNext: () {
                    if (_agreedToTerms) {
                      _nextPage();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please agree to the Terms & Conditions',
                            style: AppTextStyles.body
                                .copyWith(color: Colors.white),
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  onBack: _previousPage,
                ), // 4 (Profile)
                InterestsPage(
                  availableInterests: _availableInterests,
                  selectedInterests: _selectedInterests,
                  onToggleInterest: (interest) {
                    setState(() {
                      if (_selectedInterests.contains(interest)) {
                        _selectedInterests.remove(interest);
                      } else {
                        _selectedInterests.add(interest);
                      }
                    });
                  },
                  onNext: _nextPage,
                  onBack: _previousPage,
                ), // 5 (Interests)
                PermissionsPage(
                  onAllowNotifications: () async {
                    try {
                      await PushNotificationService.instance.initialize();
                    } catch (e) {
                      // best-effort; continue onboarding
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Notifications enabled!',
                          style:
                              AppTextStyles.body.copyWith(color: Colors.white),
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    _nextPage();
                  },
                  onSkip: _nextPage,
                  onBack: _previousPage,
                ), // 6
                StartQuestPage(
                  isStartingQuest: _isStartingQuest,
                  onStartQuest: _completeOnboarding,
                  onBack: _previousPage,
                ), // 7 (final)
              ],
            ),

            // Progress indicator overlay (only show when not on welcome page)
            if (_currentPage > 0)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: QuestProgressIndicator(
                    progress: (_currentPage + 1) / 9, // 9 total pages
                    color: AppColors.primary,
                    height: 8,
                  ),
                ),
              ),

            // Payment screen overlay
            if (_showingPaymentScreen) _buildPaymentScreen(),
          ],
        ),
      ),
    );
  }

  // Old page builder methods removed - now using separate page files
  // All _buildXxxPage() methods and helper widgets have been extracted to:
  // - pages/welcome_page.dart
  // - pages/goal_intro_page.dart
  // - pages/main_daily_goals_page.dart
  // - pages/meet_questor_page.dart
  // - pages/personal_info_page.dart
  // - pages/interests_page.dart
  // - pages/permissions_page.dart
  // - pages/start_quest_page.dart
  // - widgets/category_icon.dart
  // - widgets/category_explanation.dart
  // - widgets/daily_goal_example.dart
  // - widgets/sparkles_overlay.dart

  // Payment screen and subscription methods are defined earlier in the file (line 313)
}

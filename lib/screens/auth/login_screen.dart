import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:my_leadership_quest/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/user_provider.dart';
import '../../utils/error_handler.dart';
import '../../theme/app_colors.dart' as theme;
import '../../theme/app_text_styles.dart' as theme;
import '../../widgets/quest_button.dart';
import 'signup_screen.dart';
import '../legal/legal_markdown_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _rememberMe = false;
  bool _isAutoLogging = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    // Check if we should skip auto-login (e.g., after logout)
    _checkAndAttemptAutoLogin();
  }

  Future<void> _checkAndAttemptAutoLogin() async {
    // Check if user just logged out
    final prefs = await SharedPreferences.getInstance();
    final justLoggedOut = prefs.getBool('just_logged_out') ?? false;

    if (justLoggedOut) {
      // Clear the flag and skip auto-login
      await prefs.setBool('just_logged_out', false);
      debugPrint('Skipping auto-login after logout');
      return;
    }

    // Proceed with auto-login
    await _attemptAutoLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;
      if (rememberMe && mounted) {
        setState(() {
          _emailController.text = prefs.getString('remembered_email') ?? '';
          _passwordController.text =
              prefs.getString('remembered_password') ?? '';
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading remembered credentials: $e');
    }
  }

  Future<void> _attemptAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (rememberMe) {
        final email = prefs.getString('remembered_email') ?? '';
        final password = prefs.getString('remembered_password') ?? '';

        if (email.isNotEmpty && password.isNotEmpty && mounted) {
          setState(() {
            _isAutoLogging = true;
          });

          final userProvider =
              Provider.of<UserProvider>(context, listen: false);
          final success = await userProvider.login(
            email: email,
            password: password,
          );

          if (success && mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const MainNavigationScreen()),
              (route) => false,
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-login failed: $e');
      // Clear credentials if auto-login fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remembered_email');
      await prefs.remove('remembered_password');
      await prefs.setBool('remember_me', false);
    }

    if (mounted) {
      setState(() {
        _isAutoLogging = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final success = await userProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (success) {
        // Save credentials if remember me is checked
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString(
              'remembered_email', _emailController.text.trim());
          await prefs.setString(
              'remembered_password', _passwordController.text);
          await prefs.setBool('remember_me', true);
        } else {
          await prefs.remove('remembered_email');
          await prefs.remove('remembered_password');
          await prefs.setBool('remember_me', false);
        }

        if (!mounted) return;

        // Show success animation before navigating
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Welcome back, adventurer!',
              style: theme.AppTextStyles.body.copyWith(color: Colors.white),
            ),
            backgroundColor: theme.AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to home screen after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const MainNavigationScreen()),
            (route) => false,
          );
        });
      } else {
        final detailed = userProvider.lastErrorMessage;
        setState(() {
          _errorMessage = detailed ??
              'Oops! Your email or password doesn\'t match our records.';
          _isLoading = false;
        });
      }
    } catch (e) {
      final friendly = ErrorHandler.toMessage(e);
      setState(() {
        _errorMessage = friendly;
        _isLoading = false;
      });
    }
  }

  void _navigateToSignUp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SignupScreen()),
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
                  const SizedBox(height: 40),
                  // Logo and app name
                  Center(
                    child: Image.asset(
                      'assets/images/questor 6.png',
                      height: 120,
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.0, 1.0),
                        duration: 600.ms,
                      ),
                  const SizedBox(height: 24),
                  Text(
                    'My Leadership Quest',
                    style: theme.AppTextStyles.heading1.copyWith(
                      color: theme.AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back, young leader!',
                    style: theme.AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                  const SizedBox(height: 40),

                  // Error message if any
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: theme.AppTextStyles.body.copyWith(
                          color: theme.AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().shake(duration: 300.ms),
                  const SizedBox(height: 24),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email address',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.AppColors.secondary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.AppColors.tertiary,
                          width: 1.5,
                        ),
                      ),
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
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
                  const SizedBox(height: 16),

                  // Remember Me Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        activeColor: theme.AppColors.primary,
                      ),
                      Text(
                        'Remember me',
                        style: theme.AppTextStyles.body,
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms, delay: 900.ms),
                  const SizedBox(height: 24),

                  // Login button
                  QuestButton(
                    text: _isAutoLogging ? 'Auto-signing in...' : 'Login',
                    onPressed: (_isLoading || _isAutoLogging) ? null : _login,
                    isLoading: _isLoading || _isAutoLogging,
                  ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
                  const SizedBox(height: 16),

                  // Forgot password temporarily hidden until production-ready
                  const SizedBox.shrink(),
                  const SizedBox(height: 8),

                  // Sign up option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: theme.AppTextStyles.body,
                      ),
                      TextButton(
                        onPressed: _navigateToSignUp,
                        child: Text(
                          'Sign Up',
                          style: theme.AppTextStyles.bodyBold.copyWith(
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms, delay: 1200.ms),
                  const SizedBox(height: 16),

                  // Legal links footer
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TermsScreen()),
                          );
                        },
                        child: Text(
                          'Terms & Conditions',
                          style: theme.AppTextStyles.bodySmall.copyWith(
                              color: Colors.blue, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('•', style: theme.AppTextStyles.bodySmall),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen()),
                          );
                        },
                        child: Text(
                          'Privacy Policy',
                          style: theme.AppTextStyles.bodySmall.copyWith(
                              color: Colors.blue, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('•', style: theme.AppTextStyles.bodySmall),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RefundPolicyScreen()),
                          );
                        },
                        child: Text(
                          'Refund Policy',
                          style: theme.AppTextStyles.bodySmall.copyWith(
                              color: Colors.blue, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 1300.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

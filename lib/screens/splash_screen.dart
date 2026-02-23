import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

import '../constants/app_constants.dart';
import '../providers/user_provider.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Add a small delay for the animation to play
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Check if user is already authenticated
    final isAuthenticated = userProvider.isAuthenticated;
    
    if (!mounted) return;
    
    // Navigate to appropriate screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => isAuthenticated 
          ? const HomeScreen() 
          : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo with animation
            Image.asset(
              'assets/images/logo.png',
              height: 150,
              width: 150,
            )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 800.ms,
            ),
            
            const SizedBox(height: 24),
            
            // App name with animation
            Text(
              'My Leadership Quest',
              style: AppTextStyles.heading1.copyWith(
                color: AppColors.primary,
                fontSize: 28,
              ),
            )
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms),
            
            const SizedBox(height: 8),
            
            // Tagline with animation
            Text(
              'Your journey to becoming a leader starts here!',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            )
            .animate()
            .fadeIn(delay: 600.ms, duration: 600.ms),
            
            const SizedBox(height: 48),
            
            // Loading animation
            SizedBox(
              width: 100,
              height: 100,
              child: Lottie.asset(
                'assets/animations/loading_animation.json',
                fit: BoxFit.contain,
              ),
            )
            .animate()
            .fadeIn(delay: 900.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}

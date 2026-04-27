import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// A lightweight splash screen that shows a GIF for a fixed duration
/// and then navigates to the provided [nextScreen].
class GifSplashScreen extends StatefulWidget {
  const GifSplashScreen({
    super.key,
    required this.gifAssetPath,
    required this.nextScreen,
    this.minDisplayTime = const Duration(seconds: 5),
  });

  /// Path to the bundled GIF in assets.
  final String gifAssetPath;

  /// The widget to push-replace when the splash sequence completes.
  final Widget nextScreen;

  /// Minimum amount of time to keep the splash visible.
  final Duration minDisplayTime;

  @override
  State<GifSplashScreen> createState() => _GifSplashScreenState();
}

class _GifSplashScreenState extends State<GifSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  Timer? _timer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // Full-screen immersive mode.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Delay a bit, then fade-in.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeCtrl.forward();
    });

    // Start timer for navigation
    _timer = Timer(widget.minDisplayTime, _navigateNext);
  }

  void _navigateNext() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    
    if (kDebugMode) debugPrint('[SplashScreen] Navigating to next screen');
    
    // Use schedulerBinding to ensure navigation happens after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: Image.asset(
            widget.gifAssetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
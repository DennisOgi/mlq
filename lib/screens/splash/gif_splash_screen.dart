import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// A lightweight splash screen that shows a GIF for a fixed duration
/// and then either calls [onFinished] or navigates to [nextScreen].
class GifSplashScreen extends StatefulWidget {
  const GifSplashScreen({
    super.key,
    required this.gifAssetPath,
    this.nextScreen,
    this.onFinished,
    this.minDisplayTime = const Duration(seconds: 5),
    this.readyToNavigate = true,
  }) : assert(
          nextScreen != null || onFinished != null,
          'Provide nextScreen and/or onFinished',
        );

  /// Path to the bundled GIF in assets.
  final String gifAssetPath;

  /// The widget to push-replace when the splash sequence completes.
  /// Ignored when [onFinished] is set (preferred for root/home splash).
  final Widget? nextScreen;

  /// When set, called instead of Navigator.pushReplacement.
  /// Use this for MaterialApp `home` so Provider rebuilds cannot remount splash.
  final VoidCallback? onFinished;

  /// Minimum amount of time to keep the splash visible.
  final Duration minDisplayTime;

  /// When false, splash stays up after [minDisplayTime] until this becomes true.
  final bool readyToNavigate;

  @override
  State<GifSplashScreen> createState() => _GifSplashScreenState();
}

class _GifSplashScreenState extends State<GifSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  Timer? _timer;
  bool _hasNavigated = false;
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeCtrl.forward();
    });

    _timer = Timer(widget.minDisplayTime, () {
      _minTimeElapsed = true;
      _tryNavigate();
    });
  }

  @override
  void didUpdateWidget(covariant GifSplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.readyToNavigate && !oldWidget.readyToNavigate) {
      _tryNavigate();
    }
  }

  void _tryNavigate() {
    if (!mounted || _hasNavigated) return;
    if (!_minTimeElapsed || !widget.readyToNavigate) {
      if (kDebugMode) {
        debugPrint(
          '[SplashScreen] Waiting to navigate '
          '(minElapsed=$_minTimeElapsed, ready=${widget.readyToNavigate})',
        );
      }
      return;
    }
    _hasNavigated = true;

    if (kDebugMode) debugPrint('[SplashScreen] Completing splash');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Prefer in-place completion for root splash (avoids home remount loops).
      if (widget.onFinished != null) {
        widget.onFinished!();
        return;
      }

      final next = widget.nextScreen;
      if (next == null) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => next,
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

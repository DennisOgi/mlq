import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Animation quality levels
enum AnimationQuality {
  low,    // Minimal animations, reduced effects
  medium, // Balanced animations with some effects
  high    // Full animations with all effects
}

/// A utility class to optimize animations based on device performance
class AnimationOptimizer {
  static final AnimationOptimizer _instance = AnimationOptimizer._internal();
  
  factory AnimationOptimizer() => _instance;
  
  AnimationOptimizer._internal();
  
  AnimationQuality _quality = AnimationQuality.medium;
  bool _isInitialized = false;
  
  /// Initialize the animation optimizer
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final savedQuality = prefs.getString('animation_quality');
    
    // Set quality based on saved preference or auto-detect
    if (savedQuality != null) {
      _quality = AnimationQuality.values.firstWhere(
        (q) => q.toString() == savedQuality,
        orElse: () => AnimationQuality.medium,
      );
    } else {
      _autoDetectQuality();
    }
    
    // Apply global animation settings
    _applyGlobalSettings();
    
    _isInitialized = true;
  }
  
  /// Auto-detect appropriate animation quality based on device performance.
  ///
  /// We schedule two consecutive frame callbacks and measure the time between
  /// them to estimate the device's ability to render 60 FPS. This avoids using
  /// `currentFrameTimeStamp`, which asserts if accessed outside a frame.
  void _autoDetectQuality() {
    // Default to medium until we have a measurement.
    _quality = AnimationQuality.medium;

    SchedulerBinding.instance.scheduleFrameCallback((Duration frameStart) {
      SchedulerBinding.instance.scheduleFrameCallback((Duration frameEnd) {
        const double targetFrameMs = 1000 / 60; // ≈16.67 ms
        final double actualFrameMs = (frameEnd - frameStart).inMicroseconds / 1000.0;

        if (actualFrameMs > targetFrameMs * 1.5) {
          _quality = AnimationQuality.low;
        } else if (actualFrameMs > targetFrameMs * 1.2) {
          _quality = AnimationQuality.medium;
        } else {
          _quality = AnimationQuality.high;
        }

        // Re-apply globals with the detected quality.
        _applyGlobalSettings();
      });
    });
  }
  
  /// Apply global animation settings based on quality
  void _applyGlobalSettings() {
    switch (_quality) {
      case AnimationQuality.low:
        // Reduce global animation durations
        Animate.defaultDuration = const Duration(milliseconds: 200);
        // Disable some effects
        Animate.restartOnHotReload = false;
        break;
      
      case AnimationQuality.medium:
        // Standard animation durations
        Animate.defaultDuration = const Duration(milliseconds: 300);
        Animate.restartOnHotReload = true;
        break;
      
      case AnimationQuality.high:
        // Full animation experience
        Animate.defaultDuration = const Duration(milliseconds: 400);
        Animate.restartOnHotReload = true;
        break;
    }
  }
  
  /// Save the current animation quality preference
  Future<void> saveQualityPreference(AnimationQuality quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('animation_quality', quality.toString());
    _quality = quality;
    _applyGlobalSettings();
  }
  
  /// Get the current animation quality
  AnimationQuality get quality => _quality;
  
  /// Check if complex animations should be enabled
  bool get enableComplexAnimations => _quality != AnimationQuality.low;
  
  /// Get animation duration multiplier based on quality
  double get durationMultiplier {
    switch (_quality) {
      case AnimationQuality.low:
        return 0.7;
      case AnimationQuality.medium:
        return 1.0;
      case AnimationQuality.high:
        return 1.2;
    }
  }
  
  /// Optimize animation duration based on quality
  Duration optimizeDuration(Duration original) {
    return Duration(
      milliseconds: (original.inMilliseconds * durationMultiplier).round(),
    );
  }
  
  /// Convert milliseconds to Duration
  Duration ms(int milliseconds) {
    return Duration(milliseconds: milliseconds);
  }
  
  /// Create optimized animation effects for a widget
  List<Effect<dynamic>> getOptimizedEffects({
    required bool fadeIn,
    bool scale = true,
    bool slide = false,
    Offset? slideOffset,
    bool shimmer = false,
  }) {
    List<Effect<dynamic>> effects = [];
    
    // Always include fade for all quality levels
    if (fadeIn) {
      effects.add(FadeEffect(
        duration: optimizeDuration(ms(300)),
        curve: Curves.easeOut,
      ));
    }
    
    // Add scale effect for medium and high quality
    if (scale && _quality != AnimationQuality.low) {
      effects.add(ScaleEffect(
        duration: optimizeDuration(ms(350)),
        curve: Curves.easeOutBack,
        begin: const Offset(0.95, 0.95),
        end: const Offset(1.0, 1.0),
      ));
    }
    
    // Add slide effect for medium and high quality
    if (slide && _quality != AnimationQuality.low) {
      effects.add(SlideEffect(
        duration: optimizeDuration(ms(400)),
        curve: Curves.easeOutCubic,
        begin: slideOffset ?? const Offset(0, 0.1),
        end: Offset.zero,
      ));
    }
    
    // Add shimmer effect only for high quality
    if (shimmer && _quality == AnimationQuality.high) {
      effects.add(ShimmerEffect(
        duration: optimizeDuration(ms(1500)),
      ));
    }
    
    return effects;
  }
}

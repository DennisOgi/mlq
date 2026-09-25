import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

/// Tracks whether the user entered via the telco/SMS VAS portal (`/vas`).
class VasSession {
  VasSession._();

  static const _prefsKey = 'vas_portal_active';
  static const _demoPrefsKey = 'vas_demo_mode';

  static bool _active = false;
  static bool _demo = false;
  static bool _bootstrapped = false;

  static bool get isActive => _active;
  static bool get isDemo => _demo;

  /// True if the current browser/app URL is the VAS portal.
  static bool detectVasPath() {
    final samples = <String>[
      Uri.base.path,
      Uri.base.toString(),
      Uri.base.fragment,
      PlatformDispatcher.instance.defaultRouteName,
    ];
    for (final raw in samples) {
      final s = raw.toLowerCase().trim();
      if (s.isEmpty) continue;
      // Match /vas, /vas/, /vas?demo=1, #/vas, etc.
      if (s == '/vas' ||
          s == 'vas' ||
          s.startsWith('/vas?') ||
          s.startsWith('/vas/') ||
          s.startsWith('vas?') ||
          s.startsWith('vas/') ||
          s.contains('/vas?') ||
          s.contains('/vas/') ||
          s.endsWith('/vas') ||
          RegExp(r'(^|[#/])vas([/?#]|$)').hasMatch(s)) {
        return true;
      }
    }
    return false;
  }

  static bool detectDemoFlag() {
    final samples = <String>[
      Uri.base.toString(),
      Uri.base.query,
      Uri.base.fragment,
      PlatformDispatcher.instance.defaultRouteName,
    ];
    if (Uri.base.queryParameters['demo'] == '1' ||
        Uri.base.queryParameters['demo'] == 'true') {
      return true;
    }
    for (final raw in samples) {
      if (raw.contains('demo=1') || raw.contains('demo=true')) return true;
    }
    return false;
  }

  /// Call at app start and whenever routing is resolved.
  static Future<void> bootstrapFromUri({bool force = false}) async {
    if (_bootstrapped && !force) return;
    _bootstrapped = true;

    final isVasPath = detectVasPath();
    final demoParam = detectDemoFlag();
    final prefs = await SharedPreferences.getInstance();

    if (kDebugMode || kIsWeb) {
      debugPrint(
        '[VasSession] detect path=${Uri.base.path} '
        'uri=${Uri.base} route=${PlatformDispatcher.instance.defaultRouteName} '
        'isVas=$isVasPath demo=$demoParam',
      );
    }

    if (isVasPath) {
      _active = true;
      await prefs.setBool(_prefsKey, true);
      _demo = demoParam || (prefs.getBool(_demoPrefsKey) ?? false);
      if (demoParam) {
        await prefs.setBool(_demoPrefsKey, true);
      }
    } else {
      // Root / full app: leave VAS mode (do not sticky-trap from prefs).
      _active = false;
      _demo = false;
      await prefs.remove(_prefsKey);
      await prefs.remove(_demoPrefsKey);
    }
  }

  /// Sync flags from the live URL without awaiting prefs (for build()).
  static void syncFromUriSync() {
    if (detectVasPath()) {
      _active = true;
      if (detectDemoFlag()) _demo = true;
    }
  }

  static Future<void> enter({bool demo = false}) async {
    _active = true;
    _demo = demo || _demo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    await prefs.setBool(_demoPrefsKey, _demo);
  }

  static Future<void> clear() async {
    _active = false;
    _demo = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_demoPrefsKey);
  }

  /// Full MLQ (Monthly/Quarterly) unlocks gated features.
  /// Demo mode always shows gates so telcos can review the matrix.
  static bool hasFullAppAccess(UserModel? user) {
    if (_demo) return false;
    if (user == null) return false;
    if (user.isAdmin) return true;
    if (user.isTrial) return false;
    if (user.schoolId != null && user.schoolId!.trim().isNotEmpty) {
      return true;
    }
    return user.isPremium;
  }
}

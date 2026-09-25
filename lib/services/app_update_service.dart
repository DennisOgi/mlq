import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle automatic app updates from Play Store
/// Uses Google's In-App Updates API for seamless update experience
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  /// Startup Play Store update prompts (enabled for release builds).
  /// Override with `--dart-define=MLQ_ENABLE_STARTUP_UPDATE_CHECK=false` to disable.
  static const bool _startupUpdatePromptEnabled = bool.fromEnvironment(
    'MLQ_ENABLE_STARTUP_UPDATE_CHECK',
    defaultValue: true,
  );
  static const String _diagnosticLogKey = 'mlq_app_update_diagnostic_logs';

  bool _updateAvailable = false;
  AppUpdateInfo? _updateInfo;

  bool get updateAvailable => _updateAvailable;
  AppUpdateInfo? get updateInfo => _updateInfo;

  Future<void> _log(String message) async {
    final line = '${DateTime.now().toIso8601String()} $message';
    debugPrint('[AppUpdateService] $message');

    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_diagnosticLogKey) ?? const [];
      final next = [...existing, line];
      await prefs.setStringList(
        _diagnosticLogKey,
        next.length > 40 ? next.sublist(next.length - 40) : next,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Failed to persist diagnostic log: $e');
    }
  }

  /// Check for available updates from Play Store
  /// Returns true if an update is available
  Future<bool> checkForUpdate() async {
    // Only works on Android
    if (!Platform.isAndroid) {
      await _log('In-app updates only available on Android');
      return false;
    }

    try {
      await _log('Checking Play in-app update availability');
      _updateInfo = await InAppUpdate.checkForUpdate();
      _updateAvailable =
          _updateInfo?.updateAvailability == UpdateAvailability.updateAvailable;

      await _log(
        'Update check result: available=$_updateAvailable, '
        'availableVersionCode=${_updateInfo?.availableVersionCode}, '
        'priority=${_updateInfo?.updatePriority}, '
        'stalenessDays=${_updateInfo?.clientVersionStalenessDays}, '
        'flexibleAllowed=${_updateInfo?.flexibleUpdateAllowed}, '
        'immediateAllowed=${_updateInfo?.immediateUpdateAllowed}',
      );

      return _updateAvailable;
    } catch (e) {
      await _log('Error checking for update: $e');
      return false;
    }
  }

  /// Prefer immediate when allowed, otherwise flexible (and the reverse as fallback).
  Future<void> _startBestAvailableUpdate({
    required bool preferImmediate,
    VoidCallback? onFlexibleDownloadComplete,
  }) async {
    final immediateAllowed = _updateInfo?.immediateUpdateAllowed == true;
    final flexibleAllowed = _updateInfo?.flexibleUpdateAllowed == true;

    if (preferImmediate && immediateAllowed) {
      await startImmediateUpdate();
      return;
    }
    if (flexibleAllowed) {
      await startFlexibleUpdate(onDownloadComplete: onFlexibleDownloadComplete);
      return;
    }
    if (immediateAllowed) {
      await startImmediateUpdate();
      return;
    }
    await _log('No in-app update path allowed (immediate/flexible both blocked)');
  }

  /// Start a flexible update (downloads in background, user can continue using app)
  Future<void> startFlexibleUpdate({
    VoidCallback? onDownloadComplete,
  }) async {
    if (!Platform.isAndroid || !_updateAvailable) {
      await _log('Cannot start flexible update - not available');
      return;
    }

    try {
      if (_updateInfo?.flexibleUpdateAllowed != true) {
        await _log('Flexible update not allowed');
        return;
      }

      await _log('Starting flexible update download');
      final result = await InAppUpdate.startFlexibleUpdate();
      await _log('Flexible update finished with result=$result');
      if (result == AppUpdateResult.success) {
        onDownloadComplete?.call();
      }
    } catch (e) {
      await _log('Error starting flexible update: $e');
    }
  }

  /// Start an immediate update (blocks app until update is installed)
  Future<void> startImmediateUpdate() async {
    if (!Platform.isAndroid || !_updateAvailable) {
      await _log('Cannot start immediate update - not available');
      return;
    }

    try {
      if (_updateInfo?.immediateUpdateAllowed != true) {
        await _log('Immediate update not allowed');
        return;
      }

      await _log('Starting immediate update');
      await InAppUpdate.performImmediateUpdate();
      await _log('Immediate update completed');
    } catch (e) {
      await _log('Error starting immediate update: $e');
    }
  }

  /// Complete a flexible update that was downloaded in the background
  Future<void> completeFlexibleUpdate() async {
    if (!Platform.isAndroid) return;

    try {
      await _log('Completing downloaded flexible update by user request');
      await InAppUpdate.completeFlexibleUpdate();
      await _log('Flexible update installation triggered');
    } catch (e) {
      await _log('Error completing flexible update: $e');
    }
  }

  /// Show update dialog to user
  /// Returns true if user chose to update
  Future<bool> showUpdateDialog(BuildContext context, {bool isRequired = false}) async {
    if (!_updateAvailable) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isRequired,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Text('Update Available'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A new version of My Leadership Quest is available!',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              isRequired
                  ? 'This update is required to continue using the app.'
                  : 'Update now to get the latest features and improvements.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (_updateInfo?.clientVersionStalenessDays != null &&
                _updateInfo!.clientVersionStalenessDays! > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Your app is ${_updateInfo!.clientVersionStalenessDays} days out of date.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isRequired)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showRestartSnackBar(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Update downloaded! Restart to install.'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'RESTART',
          onPressed: () => completeFlexibleUpdate(),
        ),
      ),
    );
  }

  /// Check and prompt for update on app startup
  Future<void> checkAndPromptUpdate(BuildContext context) async {
    if (!_startupUpdatePromptEnabled) {
      await _log(
        'Startup update prompt disabled; Play Store will handle app updates',
      );
      return;
    }

    final hasUpdate = await checkForUpdate();
    if (!hasUpdate || !context.mounted) return;

    // Require update if the installed build has been stale for over a week.
    final isRequired = (_updateInfo?.clientVersionStalenessDays ?? 0) > 7;

    // Play Console in-app update priority: higher values prefer immediate path
    final priority = _updateInfo?.updatePriority ?? 0;
    final preferImmediate = priority >= 4 || isRequired;

    if (preferImmediate) {
      final shouldUpdate = await showUpdateDialog(context, isRequired: true);
      if (!shouldUpdate || !context.mounted) return;
      await _startBestAvailableUpdate(
        preferImmediate: true,
        onFlexibleDownloadComplete: () => _showRestartSnackBar(context),
      );
    } else {
      final shouldUpdate = await showUpdateDialog(context);
      if (!shouldUpdate || !context.mounted) return;
      await _startBestAvailableUpdate(
        preferImmediate: false,
        onFlexibleDownloadComplete: () => _showRestartSnackBar(context),
      );
    }
  }
}

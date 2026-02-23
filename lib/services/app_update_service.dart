import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service to handle automatic app updates from Play Store
/// Uses Google's In-App Updates API for seamless update experience
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  bool _updateAvailable = false;
  AppUpdateInfo? _updateInfo;

  bool get updateAvailable => _updateAvailable;
  AppUpdateInfo? get updateInfo => _updateInfo;

  /// Check for available updates from Play Store
  /// Returns true if an update is available
  Future<bool> checkForUpdate() async {
    // Only works on Android
    if (!Platform.isAndroid) {
      debugPrint('[AppUpdateService] In-app updates only available on Android');
      return false;
    }

    try {
      _updateInfo = await InAppUpdate.checkForUpdate();
      _updateAvailable = _updateInfo?.updateAvailability == 
          UpdateAvailability.updateAvailable;
      
      debugPrint('[AppUpdateService] Update check result:');
      debugPrint('  - Update available: $_updateAvailable');
      debugPrint('  - Available version code: ${_updateInfo?.availableVersionCode}');
      debugPrint('  - Update priority: ${_updateInfo?.updatePriority}');
      debugPrint('  - Staleness days: ${_updateInfo?.clientVersionStalenessDays}');
      
      return _updateAvailable;
    } catch (e) {
      debugPrint('[AppUpdateService] ❌ Error checking for update: $e');
      return false;
    }
  }

  /// Start a flexible update (downloads in background, user can continue using app)
  /// Shows a snackbar when download completes, user can choose when to install
  Future<void> startFlexibleUpdate({
    VoidCallback? onDownloadComplete,
  }) async {
    if (!Platform.isAndroid || !_updateAvailable) {
      debugPrint('[AppUpdateService] Cannot start flexible update - not available');
      return;
    }

    try {
      // Check if flexible update is allowed
      if (_updateInfo?.flexibleUpdateAllowed != true) {
        debugPrint('[AppUpdateService] Flexible update not allowed, trying immediate');
        await startImmediateUpdate();
        return;
      }

      debugPrint('[AppUpdateService] Starting flexible update...');
      
      // Start the flexible update
      await InAppUpdate.startFlexibleUpdate();
      
      debugPrint('[AppUpdateService] ✅ Flexible update started');
      
      // Listen for download completion
      InAppUpdate.completeFlexibleUpdate().then((_) {
        debugPrint('[AppUpdateService] ✅ Flexible update completed');
        onDownloadComplete?.call();
      }).catchError((e) {
        debugPrint('[AppUpdateService] Flexible update completion error: $e');
      });
    } catch (e) {
      debugPrint('[AppUpdateService] ❌ Error starting flexible update: $e');
    }
  }

  /// Start an immediate update (blocks app until update is installed)
  /// Use for critical updates that must be installed immediately
  Future<void> startImmediateUpdate() async {
    if (!Platform.isAndroid || !_updateAvailable) {
      debugPrint('[AppUpdateService] Cannot start immediate update - not available');
      return;
    }

    try {
      // Check if immediate update is allowed
      if (_updateInfo?.immediateUpdateAllowed != true) {
        debugPrint('[AppUpdateService] Immediate update not allowed');
        return;
      }

      debugPrint('[AppUpdateService] Starting immediate update...');
      
      // This will block the app and show Play Store update UI
      await InAppUpdate.performImmediateUpdate();
      
      debugPrint('[AppUpdateService] ✅ Immediate update completed');
    } catch (e) {
      debugPrint('[AppUpdateService] ❌ Error starting immediate update: $e');
    }
  }

  /// Complete a flexible update that was downloaded in the background
  /// Call this when user is ready to restart the app
  Future<void> completeFlexibleUpdate() async {
    if (!Platform.isAndroid) return;

    try {
      await InAppUpdate.completeFlexibleUpdate();
      debugPrint('[AppUpdateService] ✅ Flexible update installation triggered');
    } catch (e) {
      debugPrint('[AppUpdateService] ❌ Error completing flexible update: $e');
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

  /// Check and prompt for update on app startup
  /// This is the main method to call from your app initialization
  Future<void> checkAndPromptUpdate(BuildContext context) async {
    final hasUpdate = await checkForUpdate();
    if (!hasUpdate || !context.mounted) return;

    // Determine if update should be required based on staleness
    // If app is more than 14 days old, make it required
    final isRequired = (_updateInfo?.clientVersionStalenessDays ?? 0) > 14;
    
    // Determine update type based on priority
    // Priority 5 = critical (immediate), 0-4 = flexible
    final priority = _updateInfo?.updatePriority ?? 0;
    
    if (priority >= 5 || isRequired) {
      // Critical update - show dialog and do immediate update
      final shouldUpdate = await showUpdateDialog(context, isRequired: true);
      if (shouldUpdate) {
        await startImmediateUpdate();
      }
    } else {
      // Non-critical update - show dialog and do flexible update
      final shouldUpdate = await showUpdateDialog(context);
      if (shouldUpdate) {
        await startFlexibleUpdate(
          onDownloadComplete: () {
            // Show snackbar when download completes
            if (context.mounted) {
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
          },
        );
      }
    }
  }
}

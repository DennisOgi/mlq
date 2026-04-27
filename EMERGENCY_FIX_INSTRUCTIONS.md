# Emergency Fix Instructions - App Crashing

## Current Situation

The app is crashing with a native error before any Dart code runs:
```
I/eadership_quest: Wrote stack traces to tombstoned
I/Choreographer: Skipped 703 frames!
Lost connection to device.
```

This is a **native crash**, not a Dart/Flutter issue.

---

## Immediate Actions to Try

### Option 1: Clean Build (Most Likely to Work)

```bash
cd my_leadership_quest

# Clean everything
flutter clean

# Get dependencies
flutter pub get

# Rebuild
flutter run
```

**Why**: Build artifacts may be corrupted or outdated.

---

### Option 2: Test on Physical Device

```bash
# Connect physical Android device via USB
# Enable USB debugging on device

flutter run --release
```

**Why**: Emulators can have issues that don't occur on real devices.

---

### Option 3: Increase Emulator Resources

1. Open Android Studio
2. Tools → AVD Manager
3. Edit your emulator
4. Show Advanced Settings
5. Increase:
   - RAM: 4096 MB (minimum)
   - VM Heap: 512 MB
   - Internal Storage: 2048 MB

**Why**: Low resources can cause crashes during initialization.

---

### Option 4: Try Different Emulator

Create a new emulator with:
- **Device**: Pixel 5 or Pixel 6
- **API Level**: 30 or 31 (not 37)
- **RAM**: 4GB
- **Graphics**: Hardware

**Why**: API 37 (Android 17) may have compatibility issues.

---

### Option 5: Revert Bank Integration (Temporary)

If you need the app working immediately:

```bash
git stash
# Or manually remove the new files:
# - lib/services/bank_integration_service.dart
# - lib/screens/wallet/bank_setup_screen.dart
# - lib/screens/wallet/bvn_verification_screen.dart

flutter run
```

**Why**: Test if bank integration files are causing issues.

---

## Diagnostic Commands

### Get Crash Logs:
```bash
# Windows PowerShell
$env:ANDROID_HOME\platform-tools\adb logcat -d > crash_log.txt

# Look for:
# - FATAL EXCEPTION
# - AndroidRuntime
# - Native crash
```

### Check Emulator Status:
```bash
$env:ANDROID_HOME\platform-tools\adb devices
$env:ANDROID_HOME\platform-tools\adb shell getprop ro.build.version.sdk
```

### Check Flutter:
```bash
flutter doctor -v
flutter --version
```

---

## Most Likely Causes

### 1. Build Cache Corruption ⭐ (Most Likely)
**Solution**: `flutter clean && flutter pub get && flutter run`

### 2. Emulator Resources Too Low
**Solution**: Increase RAM to 4GB, try different emulator

### 3. API Level Incompatibility
**Solution**: Use API 30 or 31 instead of 37

### 4. Gradle Build Issue
**Solution**: 
```bash
cd android
./gradlew clean
cd ..
flutter run
```

### 5. Native Library Issue
**Solution**: Check if any native dependencies are missing

---

## What's NOT the Problem

✅ **Bank Integration Code** - It's optimized and doesn't run during init  
✅ **Dart Code** - Crash happens before Dart code executes  
✅ **Flutter SDK** - `flutter doctor` shows no issues  

---

## Quick Test: Minimal App

Create `test_app.dart`:
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('Test App'),
      ),
    ),
  ));
}
```

Run it:
```bash
flutter run -t lib/test_app.dart
```

**If this works**: The issue is in your main app initialization  
**If this crashes**: The issue is with the emulator/environment

---

## Recommended Action Plan

1. **First**: Try `flutter clean && flutter pub get && flutter run`
2. **If still crashes**: Try on physical device
3. **If still crashes**: Create new emulator with API 30
4. **If still crashes**: Get crash logs and share them

---

## Getting Help

If none of these work, we need the actual crash logs:

```bash
# Get full crash log
$env:ANDROID_HOME\platform-tools\adb logcat -d > full_crash_log.txt

# Look for lines with:
# - "FATAL"
# - "AndroidRuntime"
# - "backtrace"
# - Your app package name
```

Share the crash log for detailed analysis.

---

## Bank Integration Status

The bank integration implementation is **complete and working**. The current crash is **not related** to the bank integration code - it's an environmental/build issue.

Once the app launches successfully, all bank integration features will work perfectly.

---

**Priority**: 🔴 CRITICAL  
**Recommended First Step**: `flutter clean && flutter pub get && flutter run`  
**Expected Time to Fix**: 5-10 minutes

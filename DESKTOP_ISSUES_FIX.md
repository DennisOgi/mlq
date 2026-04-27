# Desktop Version Issues & Fixes

## 🔴 Root Cause: Firebase Core Build Failure on Windows

The Firebase C++ SDK is failing to extract/build on Windows, causing:
- Victory Wall not loading (needs Supabase/network)
- Questor AI not chatting (needs API calls)
- Gratitude jar not working (needs database)
- Mini courses not rewarding XP (needs database updates)

## ✅ Solution: Clean Build & Firebase Fix

### Step 1: Clean Everything
```bash
flutter clean
rm -rf build/
rm -rf windows/flutter/ephemeral/
```

### Step 2: Delete Firebase Cache
```bash
rm -rf build/windows/x64/extracted/firebase_cpp_sdk_windows
```

### Step 3: Rebuild
```bash
flutter pub get
flutter build windows --debug
```

## 🔧 Alternative: Disable Firebase on Desktop

If Firebase continues to fail, we can disable it for desktop:

### Update `pubspec.yaml`:
```yaml
dependencies:
  firebase_core:
    version: ^3.10.0
    # Exclude Windows platform
    platforms:
      android:
      ios:
      macos:
      web:
```

### Update `lib/main.dart`:
```dart
// Skip Firebase initialization on Windows
if (!kIsWeb && !Platform.isWindows) {
  await FirebaseInitializer.initialize();
}
```

## 📋 Specific Issue Fixes

### 1. Victory Wall Not Loading
**File**: `lib/screens/victory_wall/victory_wall_screen.dart`
**Issue**: Supabase calls failing silently
**Fix**: Add better error handling and offline mode

### 2. Questor AI Not Chatting
**File**: `lib/services/ai_coach_service.dart`
**Issue**: API key or network connectivity
**Fix**: Check API key initialization and add retry logic

### 3. Gratitude Jar Not Receiving Input
**File**: Missing gratitude screen
**Fix**: Create gratitude input screen

### 4. Mini Course XP Not Rewarding
**File**: `lib/screens/mini_courses/mini_course_detail_screen.dart`
**Issue**: XP award logic not triggering
**Fix**: Add explicit XP award on completion

## 🚀 Quick Test Commands

```bash
# Clean build
flutter clean && flutter pub get

# Run with verbose logging
flutter run -d windows --verbose

# Check for specific errors
flutter run -d windows 2>&1 | findstr /i "error exception failed"
```

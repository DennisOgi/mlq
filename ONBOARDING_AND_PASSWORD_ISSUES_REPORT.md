# 🔍 Onboarding Loop & Forgot Password Issues - Report & Fixes

**Date:** April 26, 2026  
**Issues Found:** 2 Critical Issues  
**Status:** ⚠️ **NEEDS FIXING**

---

## 📋 Issue Summary

### **Issue 1: Onboarding Always Shows on Chrome/Web** ⚠️ CRITICAL
**Symptom:** App always starts with onboarding flow when running on Chrome  
**Root Cause:** `SharedPreferences` doesn't persist on web during development  
**Impact:** Users can't get past onboarding on web platform

### **Issue 2: Forgot Password Feature Hidden** ⚠️ HIGH PRIORITY
**Symptom:** Forgot password link is hidden on login screen  
**Root Cause:** Intentionally commented out with `SizedBox.shrink()`  
**Impact:** Users cannot reset their passwords

---

## 🔍 Issue 1: Onboarding Loop on Web

### **Root Cause Analysis:**

**File:** `lib/providers/user_provider.dart` (Line 583)

```dart
Future<void> _initializeUser() async {
  try {
    // Check if first time user
    final prefs = await SharedPreferences.getInstance();
    _isFirstTimeUser = prefs.getBool('isFirstTimeUser') ?? true; // ⚠️ PROBLEM
    
    // ...rest of initialization
  }
}
```

**The Problem:**

1. **SharedPreferences on Web:**
   - Uses browser's `localStorage`
   - Gets cleared when you close DevTools or clear browser data
   - Not reliable during development

2. **Default Value:**
   - `prefs.getBool('isFirstTimeUser') ?? true`
   - If key doesn't exist, defaults to `true`
   - On web, this key is often missing

3. **Flow:**
   ```
   App starts
   ↓
   UserProvider.initialize()
   ↓
   _initializeUser()
   ↓
   _isFirstTimeUser = prefs.getBool('isFirstTimeUser') ?? true
   ↓
   Key not found on web → defaults to true
   ↓
   main.dart sees isFirstTime = true
   ↓
   Shows OnboardingScreen
   ```

### **Why It Happens on Chrome:**

- **Development Mode:** Hot reload clears SharedPreferences
- **Browser Storage:** localStorage can be cleared by browser
- **No Persistence:** Unlike mobile, web storage is more volatile

### **Current Logic in main.dart:**

**File:** `lib/main.dart` (Line 475-483)

```dart
Widget nextScreen;
if (isFirstTime) {
  nextScreen = const OnboardingScreen(); // ⚠️ Always true on web
} else if (!isAuthenticated) {
  nextScreen = const LoginScreen();
} else {
  nextScreen = const MainNavigationScreen();
}
```

---

## 🔍 Issue 2: Forgot Password Hidden

### **Root Cause Analysis:**

**File:** `lib/screens/auth/login_screen.dart` (Line 356-358)

```dart
// Forgot password temporarily hidden until production-ready
const SizedBox.shrink(), // ⚠️ HIDDEN!
const SizedBox(height: 8),
```

**The Problem:**

1. **Intentionally Hidden:**
   - Commented as "temporarily hidden until production-ready"
   - Replaced with `SizedBox.shrink()` (invisible widget)

2. **Feature Exists:**
   - `ForgotPasswordScreen` is fully implemented
   - `SupabaseService.resetPassword()` method exists
   - Localization strings are ready
   - Just needs to be unhidden!

3. **Implementation Status:**
   - ✅ Screen: `lib/screens/auth/forgot_password_screen.dart`
   - ✅ Service: `SupabaseService.resetPassword()`
   - ✅ Localization: `forgotPassword`, `resetPassword`, `resetPasswordSent`
   - ❌ UI: Hidden on login screen

---

## 🛠️ Solutions

### **Solution 1: Fix Onboarding Loop on Web**

#### **Option A: Check Authentication Instead (Recommended)**

**File:** `lib/providers/user_provider.dart`

```dart
Future<void> _initializeUser() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // IMPROVED: Check authentication status first
    if (_supabaseService.isAuthenticated) {
      // User is logged in → not first time
      _isFirstTimeUser = false;
      await prefs.setBool('isFirstTimeUser', false);
    } else {
      // Check SharedPreferences, but also check if user has ever registered
      final hasCompletedRegistration = prefs.getBool('hasCompletedRegistration') ?? false;
      _isFirstTimeUser = !hasCompletedRegistration;
    }
    
    // ...rest of initialization
  }
}
```

#### **Option B: Add Web-Specific Storage (Alternative)**

Use `localStorage` directly for web:

```dart
Future<void> _initializeUser() async {
  try {
    if (kIsWeb) {
      // Use localStorage directly on web
      final hasCompletedOnboarding = html.window.localStorage['hasCompletedOnboarding'];
      _isFirstTimeUser = hasCompletedOnboarding != 'true';
    } else {
      // Use SharedPreferences on mobile
      final prefs = await SharedPreferences.getInstance();
      _isFirstTimeUser = prefs.getBool('isFirstTimeUser') ?? true;
    }
    
    // ...rest of initialization
  }
}
```

#### **Option C: Add Debug Override (Quick Fix)**

Add a debug flag to skip onboarding:

```dart
// In lib/main.dart
Widget nextScreen;
if (kDebugMode && kIsWeb) {
  // Skip onboarding in web debug mode
  nextScreen = !isAuthenticated ? const LoginScreen() : const MainNavigationScreen();
} else if (isFirstTime) {
  nextScreen = const OnboardingScreen();
} else if (!isAuthenticated) {
  nextScreen = const LoginScreen();
} else {
  nextScreen = const MainNavigationScreen();
}
```

---

### **Solution 2: Unhide Forgot Password**

#### **Simple Fix:**

**File:** `lib/screens/auth/login_screen.dart` (Line 356-358)

**Replace:**
```dart
// Forgot password temporarily hidden until production-ready
const SizedBox.shrink(),
const SizedBox(height: 8),
```

**With:**
```dart
// Forgot password link
Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
        ),
      );
    },
    child: Text(
      'Forgot Password?',
      style: theme.AppTextStyles.caption.copyWith(
        color: theme.AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
),
const SizedBox(height: 8),
```

---

## 📝 Implementation Steps

### **Step 1: Fix Onboarding Loop (Option A - Recommended)**

1. Open `lib/providers/user_provider.dart`
2. Find the `_initializeUser()` method (around line 580)
3. Replace the first-time user check logic
4. Test on Chrome

### **Step 2: Unhide Forgot Password**

1. Open `lib/screens/auth/login_screen.dart`
2. Find line 356-358
3. Replace `SizedBox.shrink()` with the forgot password button
4. Test the flow

### **Step 3: Test Both Fixes**

1. **Test Onboarding:**
   - Clear browser data
   - Run app on Chrome
   - Should show onboarding ONCE
   - Complete registration
   - Refresh page → should show login, not onboarding

2. **Test Forgot Password:**
   - Go to login screen
   - Click "Forgot Password?"
   - Enter email
   - Should receive reset email
   - Check Supabase logs

---

## 🎯 Recommended Solution (Combined Fix)

I'll create the complete fix that addresses both issues:


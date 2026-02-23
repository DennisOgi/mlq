# Notification & Badge System Diagnostic Report

## 1. Mini-Course Reading After Completion ✅ FIXED

### Issue
Users couldn't re-read mini-course lessons after completing the quiz for the day.

### Fix Applied
- **File**: `lib/screens/mini_courses/mini_course_detail_screen.dart`
- **Changes**:
  - Lessons are now always accessible for reading (removed lock on lessons)
  - Quiz remains locked after completion for the day to prevent coin farming
  - Changed header badge from "Locked for today" to "Completed today" with green checkmark
  - Quiz shows clear message: "Completed today! Quiz locked until tomorrow."

### Result
- ✅ Users can re-read all lessons anytime
- ✅ Quiz is locked after completion (prevents coin exploits)
- ✅ Clear visual feedback with completion badge

---

## 2. Push Notification System 🔍 DIAGNOSIS

### Current Implementation
**File**: `lib/services/push_notification_service.dart`

The push notification system is implemented and initialized in `main.dart`:
```dart
await PushNotificationService.instance.initialize(
  onMessageOpenedApp: _handleNotificationTap,
);
```

### Components Present
1. ✅ Firebase Cloud Messaging (FCM) integration
2. ✅ Local notifications via `flutter_local_notifications`
3. ✅ FCM token sync to user profile (`profiles.fcm_token`)
4. ✅ Foreground message handling
5. ✅ Daily goal reminder scheduling
6. ✅ Test notification method available

### Why You're Not Seeing Notifications

#### Possible Causes:

**A. No Server-Side Notification Triggers**
- The app has the **client-side infrastructure** ready
- **Missing**: Server-side logic to actually **send** notifications
- The app can **receive** notifications but nothing is **sending** them

**B. Daily Goal Reminder Not Scheduled**
- Requires user to set a reminder time in settings
- Check if `scheduleDailyGoalReminder()` has been called

**C. Test Notifications Not Triggered**
- The `showTestNotification()` method exists but may not be exposed in UI

**D. Permission Issues**
- Android 13+ requires explicit notification permission
- Check device settings: Settings > Apps > My Leadership Quest > Notifications

### How to Test Notifications

#### Option 1: Test Local Notifications (Immediate)
Add this button to your profile or settings screen:

```dart
ElevatedButton(
  onPressed: () async {
    await PushNotificationService.instance.showTestNotification(
      title: 'Test Notification',
      body: 'This is a test notification from My Leadership Quest!',
    );
  },
  child: Text('Test Notification'),
)
```

#### Option 2: Schedule Daily Reminder
In parent settings or profile settings:

```dart
await PushNotificationService.instance.scheduleDailyGoalReminder(
  time: TimeOfDay(hour: 9, minute: 0), // 9:00 AM
  title: 'Set Your Daily Goals',
  body: 'Hey! Don\'t forget to set your goals for today! 🎯',
);
```

#### Option 3: Server-Side Push (Requires Backend)
You need to implement a Cloud Function or backend service that:
1. Fetches user FCM tokens from `profiles.fcm_token`
2. Sends FCM messages via Firebase Admin SDK
3. Triggers on events like:
   - New challenge created
   - Friend completed a goal
   - Weekly progress report
   - Streak reminder

### Recommended Fixes

**Immediate (Client-Side)**:
1. Add test notification button to settings
2. Add daily reminder scheduler UI
3. Verify notification permissions on app start

**Long-Term (Server-Side)**:
1. Create Firebase Cloud Function to send notifications
2. Trigger notifications on key events:
   - Challenge creation/updates
   - Goal completion milestones
   - Streak warnings
   - Weekly summaries
3. Implement notification preferences in user settings

---

## 3. Badge System 🐛 ISSUES FOUND

### Issue Description
- User earned a badge but it disappeared
- Badge counter shows 0 despite earning badges
- Badges not persisting between sessions

### Root Cause Analysis

#### Problem 1: Badge Loading Logic
**File**: `lib/providers/user_provider.dart` (lines 1091-1161)

The `loadUserBadges()` method:
1. ✅ Queries `user_badges` table correctly
2. ✅ Joins with `badges` table for definitions
3. ✅ Maps badge names to `BadgeType` enum
4. ⚠️ **Issue**: May fail silently if badge name doesn't match any case

**Potential Issue**:
```dart
// If badge name doesn't match any case, badgeType remains null
if (badgeType != null) {
    _badges.add(BadgeModel(...));
}
// Badge is silently skipped if name doesn't match!
```

#### Problem 2: Badge Service Save Logic
**File**: `lib/services/badge_service.dart` (lines 112-203)

The `saveBadgeToDatabase()` method:
1. ✅ Checks if badge already exists
2. ✅ Inserts into `user_badges` table
3. ✅ Awards XP and coins
4. ⚠️ **Issue**: Returns `false` if badge already exists (expected)
5. ⚠️ **Issue**: If DB insert fails, badge is added to provider but not persisted

**Critical Flow**:
```dart
for (final b in legacyNew) {
  final saved = await saveBadgeToDatabase(b);
  if (saved) {
    userProvider!.addBadge(b);  // Only adds if DB save succeeds
  } else {
    debugPrint('⚠️ Skipping addBadge for ${b.name} because DB save failed');
  }
}
```

#### Problem 3: Badge Name Mismatch
**Possible Scenario**:
1. Badge earned with name "Goal Ninja"
2. Saved to database as "Goal Ninja"
3. On load, `loadUserBadges()` checks for exact match: `norm == 'goal ninja'`
4. ✅ Match found, badge loaded

**But if**:
- Database has "Goal Ninja " (extra space)
- Or "goal_ninja" (underscore)
- Or any variation
- Badge won't load!

### Diagnostic Steps

#### Step 1: Check Database
Run this query in Supabase SQL Editor:

```sql
-- Check user's badges
SELECT 
  ub.id,
  ub.user_id,
  ub.earned_at,
  b.name,
  b.description,
  b.xp_reward,
  b.coin_reward
FROM user_badges ub
JOIN badges b ON ub.badge_id = b.id
WHERE ub.user_id = 'YOUR_USER_ID'
ORDER BY ub.earned_at DESC;
```

#### Step 2: Check Badge Definitions
```sql
-- Check all badge definitions
SELECT id, name, description, category, xp_reward, coin_reward
FROM badges
ORDER BY name;
```

#### Step 3: Add Debug Logging
Temporarily add this to `loadUserBadges()`:

```dart
debugPrint('🏆 Loading badges for user: ${_user!.id}');
debugPrint('🏆 Raw response: $response');

for (var item in response as List) {
  final badgeData = item['badges'] as Map<String, dynamic>;
  final dbName = (badgeData['name'] as String?)?.trim() ?? '';
  debugPrint('🏆 Processing badge: "$dbName"');
  
  // ... rest of logic
  
  if (badgeType != null) {
    debugPrint('✅ Badge matched: $dbName -> $badgeType');
    _badges.add(...);
  } else {
    debugPrint('❌ Badge NOT matched: "$dbName"');
  }
}

debugPrint('🏆 Total badges loaded: ${_badges.length}');
```

### Recommended Fixes

#### Fix 1: Improve Badge Name Matching (Robust)
**File**: `lib/providers/user_provider.dart`

```dart
// Add fallback for unmatched badges
if (badgeType != null) {
  _badges.add(BadgeModel(...));
} else {
  // Fallback: use a default type for unrecognized badges
  debugPrint('⚠️ Unrecognized badge name: "$dbName", using default type');
  _badges.add(BadgeModel(
    id: item['id'],
    userId: item['user_id'],
    type: BadgeType.goalNinja, // Default fallback
    earnedDate: DateTime.parse(item['earned_at']),
    description: badgeData['description'],
  ));
}
```

#### Fix 2: Add Badge Count Property
**File**: `lib/models/user_model.dart`

Ensure `badgeCount` is properly synced:

```dart
// In UserProvider after loading badges:
if (_user != null) {
  _user = _user!.copyWith(badgeCount: _badges.length);
  notifyListeners();
}
```

#### Fix 3: Force Badge Reload
Add a manual refresh button in badges screen:

```dart
FloatingActionButton(
  onPressed: () async {
    await Provider.of<UserProvider>(context, listen: false).loadUserBadges();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Badges refreshed!')),
    );
  },
  child: Icon(Icons.refresh),
)
```

#### Fix 4: Verify Badge Definitions in Database
Ensure all badge names in the `badges` table exactly match the names used in `BadgeService`:

```sql
-- Update badge names to match code (if needed)
UPDATE badges SET name = 'Goal Ninja' WHERE name ILIKE 'goal%ninja%';
UPDATE badges SET name = 'Challenge Champion' WHERE name ILIKE 'challenge%champion%';
-- etc.
```

### Testing Checklist

- [ ] Check Supabase `user_badges` table for your user ID
- [ ] Verify badge names match exactly (case-insensitive, trimmed)
- [ ] Add debug logging to `loadUserBadges()`
- [ ] Test badge earning flow end-to-end
- [ ] Verify badge count updates in profile
- [ ] Test app restart (badges should persist)
- [ ] Check for any error logs in console

---

## Summary of Actions

### ✅ Completed
1. Mini-course reading unlocked after completion
2. Quiz properly locked to prevent coin farming
3. Diagnostic report created for notifications and badges

### 🔧 Requires Action

#### Notifications:
1. Add test notification button to settings
2. Implement server-side notification triggers (Cloud Functions)
3. Add notification preferences UI

#### Badges:
1. Run database queries to check badge data
2. Add debug logging to badge loading
3. Implement fallback for unmatched badge names
4. Add manual badge refresh button
5. Verify badge name consistency in database

### 📝 Next Steps
1. **Test notifications**: Add test button and verify local notifications work
2. **Debug badges**: Check database and add logging to identify the issue
3. **Server notifications**: Plan Cloud Function implementation for push notifications

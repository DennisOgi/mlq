# 6 Critical Fixes Needed

## 1. Remove Hint from Mini Courses ✅
**Location**: `lib/screens/home/home_screen.dart` lines 909-936
**Issue**: Shows "3 lessons • Quiz" hint below course title
**Fix**: Remove the Row widget with lesson count and quiz indicators

## 2. Leaderboard User Limit ✅
**Location**: `lib/providers/user_provider.dart` - `getLeaderboardUsers()` method
**Issue**: Need to confirm if it shows top 20 users
**Current**: Shows all users, needs `.take(20)` limit
**Fix**: Add `.take(20).toList()` to limit display

## 3. Long Username Overflow ✅
**Location**: `lib/screens/leaderboard/leaderboard_screen.dart` - `_buildLeaderboardItem()` method
**Issue**: Long usernames cause overflow
**Fix**: Wrap username Text widget with Flexible/Expanded and add `overflow: TextOverflow.ellipsis`

## 4. Premium Checkmarks for Pearls Garden High ✅
**Location**: Multiple files need updates
**Issue**: Users from "Pearls Garden High" school should have premium checkmarks
**Files to Update**:
- `lib/widgets/username_with_checkmark.dart` - Add school check logic
- `lib/models/user_model.dart` - May need to add `isPremium` getter based on school

## 5. Mini Course Challenge Progress Not Tracked ❌ CRITICAL
**Location**: `lib/services/challenge_evaluator.dart` - `evaluateMiniCourseChallenges()` method
**Issue**: Completing mini-course doesn't update challenge progress (stays 0/1)
**Root Cause**: Challenge evaluator not properly counting completed courses
**Fix Required**:
1. Check if `evaluateMiniCourseChallenges()` queries completed courses correctly
2. Verify it updates `user_challenges` table with progress
3. Ensure it checks against challenge criteria

## 6. Mini Course Completion Flow ❌ MISSING
**Location**: Multiple screens need updates
**Issue**: No clear completion flow when user finishes a course
**Current Behavior**: Quiz shows results, then "Back to Course" or "Home" buttons
**Expected Behavior**:
1. Mark course as completed in database (`user_course_progress` table)
2. Show completion dialog/screen with:
   - Congratulations message
   - XP/coins earned
   - Course completion badge/certificate
   - "Next Course" or "Back to Home" options
3. Update challenge progress if applicable
4. Award badges if criteria met

**Files Involved**:
- `lib/screens/mini_courses/mini_course_quiz_screen.dart` - Add completion logic after quiz
- `lib/providers/mini_course_provider.dart` - Add `completeCourse()` method
- `lib/services/global_daily_courses_service.dart` - Use `markCompleted()` method
- Create new completion dialog widget

---

## Implementation Priority:
1. **CRITICAL**: Fix #5 (Challenge progress tracking)
2. **CRITICAL**: Fix #6 (Course completion flow)
3. **HIGH**: Fix #4 (Premium checkmarks)
4. **MEDIUM**: Fix #3 (Username overflow)
5. **LOW**: Fix #2 (Leaderboard limit)
6. **LOW**: Fix #1 (Remove hint)

## Notes:
- Issues #5 and #6 are related - course completion should trigger challenge evaluation
- The quiz completion code at line 81 calls `evaluateMiniCourseChallenges()` but it's not working
- Need to verify database schema for `user_course_progress` table exists and has proper columns

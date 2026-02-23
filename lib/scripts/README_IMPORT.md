# Wellspring College Student Import Guide

## 📋 Overview

This guide will help you bulk import 183 Wellspring College students from CSV files into the My Leadership Quest app.

## 📊 Data Summary

- **JSS1.csv**: 113 students (JSS1 class)
- **student_credentials_clean.csv**: 70 students (class not specified)
- **Total**: 183 students
- **Existing**: daniel.adeniji@wellspring.org (preserved)

## ⚠️ Important Notes

### Email Typo Detected
In `student_credentials_clean.csv`, line 3:
- Current: `oyewoloetomiwa@wellspringcollege.org` (typo: "oyewoloe")
- Should be: `oyewoletomiwa@wellspringcollege.org`

**Action**: Fix this typo in the CSV before importing.

## 🚀 Import Process

### Step 1: Prerequisites

1. **Add CSV package to pubspec.yaml**:
```yaml
dependencies:
  csv: ^6.0.0
```

2. **Update Supabase credentials** in the import scripts:
   - Replace `YOUR_SUPABASE_URL` with your actual Supabase URL
   - Replace `YOUR_SUPABASE_ANON_KEY` with your actual anon key

3. **Fix CSV typo** mentioned above

### Step 2: Test Import (5 Students)

Run the test script first to validate the process:

```bash
dart run lib/scripts/test_import_5_students.dart
```

**Expected Output**:
```
🧪 WELLSPRING COLLEGE - TEST IMPORT (5 Students)
============================================================
📝 Creating: oluwafikayomiadewoye@wellspringcollege.org
   Name: OLUWAFIKAYOMI ADEWOYE
   School: Wellspring College
   Grade: JSS1
   ✅ SUCCESS - User ID: [uuid]
...
📊 TEST IMPORT RESULTS
✅ Successful: 5
❌ Failed: 0
📝 Total: 5
```

### Step 3: Verify Test Results

1. **Check Supabase Dashboard**:
   - Go to Authentication → Users
   - Verify 5 new users created
   - Check profiles table for corresponding records

2. **Test Login**:
   - Try logging in with one of the test accounts
   - Email: `oluwafikayomiadewoye@wellspringcollege.org`
   - Password: `password`

### Step 4: Full Import (All 183 Students)

If test is successful, run the full import:

```bash
dart run lib/scripts/import_wellspring_students.dart
```

**Expected Duration**: ~2-3 minutes (with rate limiting delays)

**Expected Output**:
```
🚀 Wellspring College Student Import Script
============================================================
📚 Importing JSS1 students from: lib/JSS1.csv
Creating: oluwafikayomiadewoye@wellspringcollege.org (OLUWAFIKAYOMI ADEWOYE)
  ✅ Success
...
✅ JSS1 import completed

📚 Importing students from: lib/student_credentials_clean.csv
...
✅ Clean credentials import completed

📊 IMPORT STATISTICS
============================================================
✅ Successful imports: 183
❌ Failed imports: 0
📝 Total processed: 183
```

## 🔍 Troubleshooting

### Common Issues

1. **"Email already exists"**
   - Student already has an account
   - Check if they're in the database already
   - Skip or update their profile

2. **"Rate limit exceeded"**
   - Supabase has rate limits on auth signups
   - Script includes 500ms delays between users
   - If needed, increase delay in `_createStudent()` method

3. **"Invalid email format"**
   - Check CSV for malformed emails
   - Ensure no extra spaces or special characters

4. **"School not found"**
   - Script will auto-create "Wellspring College" school
   - Check schools table if issues persist

### Verification Queries

After import, verify in Supabase SQL Editor:

```sql
-- Count Wellspring students
SELECT COUNT(*) FROM auth.users 
WHERE email LIKE '%wellspringcollege.org';

-- Check profiles created
SELECT COUNT(*) FROM profiles 
WHERE school_name = 'Wellspring College';

-- List all Wellspring students
SELECT u.email, p.name, p.school_name, p.xp, p.coins
FROM auth.users u
JOIN profiles p ON p.id = u.id
WHERE u.email LIKE '%wellspringcollege.org'
ORDER BY u.email
LIMIT 10;
```

## 📝 Post-Import Tasks

### 1. Send Welcome Emails

Create a welcome message for students with:
- Login credentials
- App download link
- Getting started guide

### 2. Verify Data Integrity

```sql
-- Check for missing profiles
SELECT u.id, u.email 
FROM auth.users u
LEFT JOIN profiles p ON p.id = u.id
WHERE u.email LIKE '%wellspringcollege.org'
  AND p.id IS NULL;

-- Should return 0 rows
```

### 3. Update Class Information

If you need to add class/grade info to the 70 students from clean CSV:

```sql
-- Example: Set grade for specific students
UPDATE profiles
SET school_name = 'Wellspring College'
WHERE id IN (
  SELECT id FROM auth.users 
  WHERE email IN ('email1@wellspringcollege.org', 'email2@wellspringcollege.org')
);
```

## 🎯 Success Criteria

- ✅ 183 new auth users created
- ✅ 183 new profiles created
- ✅ All profiles linked to Wellspring College
- ✅ daniel.adeniji@wellspring.org preserved
- ✅ All students can log in with "password"
- ✅ Starting balance: 100 coins per student

## 🔐 Security Notes

1. **Change Default Passwords**: Students should change their passwords on first login
2. **Email Verification**: Consider enabling email verification in Supabase Auth settings
3. **Rate Limiting**: Monitor Supabase usage to avoid hitting rate limits
4. **Backup**: Take a database backup before running full import

## 📞 Support

If you encounter issues:
1. Check the error logs in the script output
2. Verify Supabase credentials are correct
3. Check Supabase dashboard for auth errors
4. Review RLS policies on profiles table

## 🎓 Next Steps After Import

1. **Onboarding**: Create a school-specific onboarding flow
2. **Class Structure**: Organize students into classes/grades
3. **Challenges**: Create school-wide challenges
4. **Leaderboards**: Set up school leaderboards
5. **Parent Communication**: Send parent information emails

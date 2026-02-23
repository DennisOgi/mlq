# Edge Function Overview - Global Daily Mini-Courses Generator

## 📋 Executive Summary

**Function Name**: `generate_global_daily_courses`  
**Purpose**: Generate 3 shared mini-courses daily for all users (newspaper-style)  
**Status**: Deployed but failing with 500 errors  
**Current Issue**: Function returns 500 error; likely environment variable configuration issue

---

## 🎯 Objective

Replace per-user course generation (expensive, 1000+ API calls/day) with a single daily generation that all users share, reducing costs by 99.9% (from $300/month to $0.30/month).

---

## 🏗️ Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Daily at Midnight UTC                     │
│                                                               │
│  pg_cron (Postgres) → Triggers Edge Function via HTTP POST   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│           Edge Function: generate_global_daily_courses       │
│                                                               │
│  1. Check if courses exist for today                         │
│  2. Mark status as "generating"                              │
│  3. Call Gemini 1.5 Flash API with prompt                    │
│  4. Parse JSON response (3 courses)                          │
│  5. Save to global_daily_courses table                       │
│  6. Mark status as "ready"                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Database: global_daily_courses                  │
│                                                               │
│  - date (unique): 2025-10-09                                 │
│  - status: ready/generating/failed                           │
│  - courses: JSONB array (3 courses)                          │
│  - topics: text[] (3 topics)                                 │
│  - generated_at: timestamp                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (All Users)                   │
│                                                               │
│  - Fetches today's 3 courses                                 │
│  - Caches locally                                            │
│  - Displays in "Today's Mini-Courses" section                │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Technical Implementation

### 1. Edge Function Code

**File**: `index.ts` (Deno/TypeScript)  
**Runtime**: Deno on Supabase Edge Functions  
**Version**: 11 (latest)

**Key Components**:

```typescript
// Environment Variables Required
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");           // Auto-set by Supabase
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"); // Auto-set by Supabase
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");       // MUST BE SET MANUALLY

// Gemini API Call
fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`, {
  method: "POST",
  body: JSON.stringify({
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: { temperature: 0.8, maxOutputTokens: 4000 }
  })
})
```

**Function Logic**:
1. Validates environment variables
2. Checks if courses already exist for today (idempotency)
3. Marks status as "generating" in database
4. Sends prompt to Gemini API requesting 3 courses
5. Parses JSON response (handles markdown code blocks)
6. Validates 3 courses returned
7. Saves to `global_daily_courses` table
8. Returns success or error response

---

### 2. Database Schema

**Table**: `global_daily_courses`

```sql
CREATE TABLE global_daily_courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  courses JSONB DEFAULT '[]'::jsonb,
  topics TEXT[] DEFAULT ARRAY[]::text[],
  generated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS Policies
ALTER TABLE global_daily_courses ENABLE ROW LEVEL SECURITY;

-- Public read access (all users can read)
CREATE POLICY "Allow public read access" 
  ON global_daily_courses FOR SELECT 
  USING (true);

-- Service role write access (only Edge Function can write)
CREATE POLICY "Allow service role write" 
  ON global_daily_courses FOR ALL 
  USING (auth.role() = 'service_role');
```

**Status Values**:
- `pending`: No generation attempted yet
- `generating`: Currently generating courses
- `ready`: Courses successfully generated
- `failed`: Generation failed

---

### 3. Cron Schedule

**Scheduler**: `pg_cron` (Postgres extension)  
**Schedule ID**: 8  
**Cron Expression**: `0 0 * * *` (midnight UTC daily)

**SQL Setup**:

```sql
-- Store credentials in Vault
SELECT vault.create_secret('https://hcvyumbkonrisrxbjnst.supabase.co', 'project_url');
SELECT vault.create_secret('eyJhbGci...', 'anon_key');

-- Create cron job
SELECT cron.schedule(
  'generate-daily-mini-courses',
  '0 0 * * *',
  $$
  SELECT net.http_post(
    url:= (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url') 
          || '/functions/v1/generate_global_daily_courses',
    headers:= jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'anon_key')
    ),
    body:= concat('{"time": "', now(), '"}')::jsonb
  ) as request_id;
  $$
);
```

**Status**: ✅ Successfully configured and active

---

### 4. Environment Variables

**Required Variables** (Set in Supabase Dashboard → Edge Functions → Settings):

| Variable | Value | Status |
|----------|-------|--------|
| `SUPABASE_URL` | `https://hcvyumbkonrisrxbjnst.supabase.co` | ✅ Auto-set |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGci...` (service role JWT) | ✅ Auto-set |
| `GEMINI_API_KEY` | `AIzaSyCQEaFf5DAKyLZJ5HlMx5a_C_UYcbazxlo` | ⚠️ **VERIFY** |

**Critical**: The `GEMINI_API_KEY` must be manually set in the Supabase Dashboard. This is the most likely cause of the current 500 errors.

---

### 5. Gemini API Integration

**Model**: `gemini-1.5-flash`  
**Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent`

**Prompt Structure**:
```
Generate exactly 3 mini-courses in JSON. Each course must have:
- title
- topic
- exactly 3 lessons (title, content)
- quiz with exactly 5 questions (question text, 4 options, correctAnswerIndex 0-3)

Return only JSON like:
{
  "courses": [
    {
      "title": "...",
      "topic": "...",
      "lessons": [...],
      "quiz": { "questions": [...] }
    }
  ]
}
```

**API Configuration**:
- Temperature: 0.8
- Max Output Tokens: 4000
- Response Format: JSON (with markdown cleanup)

**Verified**: The API key works in the Flutter app's AI chat feature.

---

## 🐛 Current Issue

### Problem

Edge Function returns **500 Internal Server Error** on every invocation.

### Symptoms

1. Function deploys successfully (version 11)
2. HTTP POST returns 500 status code
3. Database shows `status: 'failed'` with 0 courses
4. Edge Function logs show 500 error but no detailed error message
5. Console.log statements don't appear in logs (suggests early failure)

### Attempted Solutions

1. ✅ Redeployed function multiple times (versions 5-11)
2. ✅ Added extensive error logging and debugging
3. ✅ Verified cron schedule is active
4. ✅ Confirmed database table exists with correct schema
5. ✅ Tested Gemini API key in Flutter app (works)
6. ✅ Checked Postgres logs (no database errors)
7. ⚠️ **Cannot verify** GEMINI_API_KEY in Supabase Dashboard via MCP

### Most Likely Cause

**GEMINI_API_KEY environment variable is not set or not accessible to the Edge Function.**

**Evidence**:
- Function fails immediately (no console.log output)
- Code checks for missing env vars and returns 500 if missing
- Same API key works in Flutter app
- SUPABASE_URL and SERVICE_KEY are auto-set by Supabase

---

## 🔍 Debugging Steps Taken

### 1. Manual Invocation

```sql
SELECT net.http_post(
  url:= 'https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/generate_global_daily_courses',
  headers:= jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer <anon_key>'
  ),
  body:= '{"trigger": "manual"}'::jsonb
) as request_id;
```

**Result**: 500 error

### 2. Enhanced Logging (Version 11)

Added console.log statements:
- Environment variable check
- Database query results
- Gemini API call status
- JSON parsing steps
- Success/failure messages

**Result**: No logs appear (function fails before logging)

### 3. Database Verification

```sql
SELECT date, status, topics, jsonb_array_length(courses) as course_count, generated_at
FROM global_daily_courses
WHERE date = CURRENT_DATE;
```

**Result**: `status: 'failed'`, `course_count: 0`

---

## ✅ What's Working

1. **Cron Schedule**: Active and will trigger daily at midnight UTC
2. **Database Schema**: Correct structure with RLS policies
3. **Function Deployment**: Successfully deploys to Supabase
4. **Flutter Integration**: App code ready to fetch and display courses
5. **API Key**: Verified working in Flutter app's AI chat
6. **Vault Secrets**: Project URL and anon key stored securely

---

## ❌ What's Not Working

1. **Edge Function Execution**: Returns 500 error
2. **Course Generation**: No courses generated
3. **Error Visibility**: Detailed error messages not appearing in logs

---

## 🎯 Recommended Next Steps

### Immediate Actions

1. **Verify Environment Variable** (Critical):
   - Go to Supabase Dashboard
   - Navigate to Edge Functions → Settings
   - Check if `GEMINI_API_KEY` exists
   - Value should be: `AIzaSyCQEaFf5DAKyLZJ5HlMx5a_C_UYcbazxlo`
   - If missing or incorrect, add/update it
   - Wait 2-3 minutes for changes to propagate
   - Redeploy function if necessary

2. **Test After Update**:
   ```sql
   -- Clear failed record
   DELETE FROM global_daily_courses WHERE date = CURRENT_DATE;
   
   -- Invoke function
   SELECT net.http_post(
     url:= 'https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/generate_global_daily_courses',
     headers:= jsonb_build_object(
       'Content-Type', 'application/json',
       'Authorization', 'Bearer eyJhbGci...'
     ),
     body:= '{"trigger": "test"}'::jsonb
   );
   
   -- Check result after 5 seconds
   SELECT * FROM global_daily_courses WHERE date = CURRENT_DATE;
   ```

3. **Check Detailed Logs**:
   - Supabase Dashboard → Edge Functions → Logs
   - Look for console.log output
   - Check for specific error messages

### Alternative Solutions

1. **Temporary Workaround**:
   - Generate courses from Flutter app (admin function)
   - Manually populate database for testing
   - Test full user flow while debugging Edge Function

2. **Different Approach**:
   - Try calling Edge Function without JWT verification
   - Use service role key instead of anon key
   - Deploy as a different function for testing

---

## 📊 Cost Analysis

### Before (Per-User Generation)
- 1,000 users × 1 course/day = **1,000 API calls/day**
- ~$0.01 per call = **$10/day** = **$300/month**

### After (Global Generation)
- 1 generation × 3 courses/day = **1 API call/day**
- ~$0.01 per call = **$0.01/day** = **$0.30/month**

### Savings
**99.9%** cost reduction (from $300/mo to $0.30/mo)

---

## 📝 Code References

### Edge Function
- **Location**: Deployed to Supabase (version 11)
- **Source**: Available via `mcp2_get_edge_function('generate_global_daily_courses')`

### Flutter Integration
- **Service**: `lib/services/global_daily_courses_service.dart`
- **Provider**: `lib/providers/mini_course_provider.dart`
- **UI**: `lib/screens/home/home_screen.dart` (Today's Mini-Courses section)

### Database
- **Table**: `global_daily_courses`
- **Completion Tracking**: `user_course_progress` with `(user_id, course_date, course_index)` marker

---

## 🔐 Security

### RLS Policies
- **Read**: Public (all authenticated users)
- **Write**: Service role only (Edge Function)

### Authentication
- Edge Function uses service role key (full access)
- Cron job uses anon key (read-only, triggers function)
- Flutter app uses anon key (read-only)

### API Key Storage
- **Flutter**: Stored in `FlutterSecureStorage` (encrypted)
- **Edge Function**: Environment variable (Supabase managed)
- **Not in source code**: Keys loaded at runtime

---

## 📞 Support Information

**Project**: My Leadership Quest  
**Supabase Project ID**: hcvyumbkonrisrxbjnst  
**Function Name**: generate_global_daily_courses  
**Current Version**: 11  
**Deployment Date**: 2025-10-09  

**Contact for Questions**:
- Review the Supabase Dashboard Edge Functions settings
- Check environment variables configuration
- Verify GEMINI_API_KEY is set correctly

---

## 🎯 Success Criteria

Function is working correctly when:

1. ✅ Manual invocation returns 200 status
2. ✅ Database shows `status: 'ready'` with `course_count: 3`
3. ✅ Console logs appear in Edge Function logs
4. ✅ Flutter app fetches and displays 3 courses
5. ✅ Cron runs successfully at midnight UTC
6. ✅ New courses generated daily

**Current Status**: 0/6 criteria met (blocked by environment variable issue)

---

**Last Updated**: 2025-10-09 16:38 UTC  
**Document Version**: 1.0

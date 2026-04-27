# Mini Courses Generation Guide

## Current Status

### Issue Identified
- **Today (April 23, 2026)**: Only 1 course instead of 3 courses
- **Tomorrow (April 24, 2026)**: No courses generated yet
- **Root Cause**: The old data from April 21st only had 1 course in the array

### What Should Happen
The `generate_global_daily_courses` edge function is designed to generate **exactly 3 mini-courses per day**, each covering a different leadership topic.

## How to Generate Courses

### Method 1: Using Supabase Dashboard (Recommended)

1. **Go to Supabase Dashboard**
   - Navigate to: https://supabase.com/dashboard
   - Select your "My Leadership Quest" project

2. **Open Edge Functions**
   - Go to Edge Functions section
   - Find `generate_global_daily_courses`

3. **Invoke the Function**
   - Click "Invoke" or "Test"
   - The function will automatically:
     - Check if courses exist for today
     - Generate 3 new courses if needed
     - Store them in the `global_daily_courses` table

4. **Verify Generation**
   - Go to Table Editor → `global_daily_courses`
   - Check that today's date has 3 courses in the `courses` JSON array

### Method 2: Using SQL (Already Done for Today)

I've already deleted today's incomplete data. Now you need to trigger the edge function to regenerate.

### Method 3: Using HTTP Request

You can call the edge function directly using curl or Postman:

```bash
curl -X POST \
  https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/generate_global_daily_courses \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

Replace `YOUR_ANON_KEY` with your Supabase anon key from the dashboard.

## Course Generation Details

### What Gets Generated

Each day, the function generates **3 mini-courses** with:

1. **Course Structure**:
   - Title (catchy, teen-friendly)
   - Topic (from leadership topics list)
   - 3 Lessons (each with title and content)
   - Quiz (5 questions with 4 options each)

2. **Topics Pool**:
   - Leadership
   - Personal Growth
   - Confidence
   - Communication
   - Motivation
   - Emotional Intelligence
   - Self-Discipline
   - Mindset
   - Productivity
   - Creativity
   - Goal Setting
   - Decision Making
   - Resilience
   - Problem Solving
   - Influence
   - Time Management
   - Conflict Resolution
   - Teamwork & Collaboration

3. **Seasonal Topics** (Dec 1 - Jan 14):
   - New Year, New Goals
   - Reflect and Reset
   - Time Management for a Fresh Start
   - Building Resilience for the Year Ahead
   - Leadership and Vision for the New Year
   - Back to School Prep
   - Holiday Productivity Hacks
   - Goal-Oriented Holiday Planning
   - Managing Holiday Stress
   - Creating a Holiday Routine

### Generation Process

The edge function uses a **model cascade** for reliability:
1. `gemini-2.0-flash` (Primary)
2. `gemini-2.0-flash-lite` (Fallback 1)
3. `gemini-1.5-flash` (Fallback 2)
4. `gemini-1.5-pro` (Fallback 3)
5. `gemini-2.5-flash` (Fallback 4)

If one model fails or is rate-limited, it automatically tries the next one.

## Automated Generation

### Setting Up Daily Generation

To ensure courses are generated automatically every day, you can:

1. **Use Supabase Cron Jobs** (Recommended):
   - Go to Database → Cron Jobs
   - Create a new cron job:
     ```sql
     SELECT net.http_post(
       url := 'https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/generate_global_daily_courses',
       headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY", "Content-Type": "application/json"}'::jsonb
     );
     ```
   - Schedule: `0 0 * * *` (runs at midnight UTC daily)

2. **Use External Cron Service**:
   - Services like cron-job.org or EasyCron
   - Set up to call the edge function daily

3. **Use GitHub Actions**:
   - Create a workflow that runs daily
   - Calls the edge function via HTTP

## Troubleshooting

### Issue: Function Returns "Courses already ready"
**Solution**: The function won't regenerate if courses already exist for that date. Delete the entry first:
```sql
DELETE FROM global_daily_courses WHERE date = CURRENT_DATE;
```

### Issue: Function Returns Error
**Possible Causes**:
1. **Missing Environment Variables**:
   - `GEMINI_API_KEY` - Google Gemini API key
   - `SUPABASE_URL` - Auto-set by Supabase
   - `SUPABASE_SERVICE_ROLE_KEY` - Auto-set by Supabase

2. **API Rate Limits**:
   - Gemini API might be rate-limited
   - Function will automatically retry with different models

3. **Invalid JSON Response**:
   - Function has recovery mechanisms for partial responses
   - Check `last_error` field in the database

### Issue: Only 1 Course Generated Instead of 3
**Solution**: This was the old behavior. The current edge function (version 48) is designed to generate exactly 3 courses. If you see only 1 course, delete and regenerate.

## Verification

After generation, verify the courses:

```sql
SELECT 
  date,
  status,
  jsonb_array_length(courses) as course_count,
  topics,
  generated_at
FROM global_daily_courses
WHERE date >= CURRENT_DATE
ORDER BY date;
```

Expected output:
- `course_count`: 3
- `status`: 'ready'
- `topics`: Array of 3 topic names

## Next Steps

1. **Immediate**: Invoke the edge function to generate today's 3 courses
2. **Tomorrow**: Invoke again for tomorrow's courses
3. **Long-term**: Set up automated daily generation using cron jobs

## Database Schema

```sql
CREATE TABLE global_daily_courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE UNIQUE NOT NULL,
  courses JSONB NOT NULL,  -- Array of 3 course objects
  topics TEXT[],            -- Array of 3 topic names
  generated_at TIMESTAMPTZ DEFAULT now(),
  status TEXT DEFAULT 'ready' CHECK (status IN ('generating', 'ready', 'failed')),
  updated_at TIMESTAMPTZ DEFAULT now(),
  last_error TEXT
);
```

## Support

If you encounter issues:
1. Check the edge function logs in Supabase Dashboard
2. Verify environment variables are set
3. Check the `last_error` field in the database
4. Review the Gemini API quota and limits

---

**Last Updated**: April 23, 2026
**Edge Function Version**: 48
**Status**: Courses for today need to be regenerated (old data deleted)

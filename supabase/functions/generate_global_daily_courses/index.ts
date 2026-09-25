// Use direct URL imports for reliability in Deno environments
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

console.log("Function 'generate_global_daily_courses' loaded.");

// Define standard CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

// Leadership + health topics for kids & teens (ages 8-16).
// Keep in sync with mini_course_topic_pool.json
const LEADERSHIP_TOPICS = [
  'Leadership',
  'Personal Growth',
  'Confidence',
  'Communication',
  'Motivation',
  'Emotional Intelligence',
  'Self-Discipline',
  'Mindset',
  'Productivity',
  'Creativity',
  'Goal Setting',
  'Decision Making',
  'Resilience',
  'Problem Solving',
  'Influence',
  'Time Management',
  'Conflict Resolution',
  'Teamwork & Collaboration'
];

const HEALTH_TOPICS = [
  'Water First',
  'How Much Water Do I Need?',
  "Signs You're Thirsty",
  'Water vs Soda and Juice',
  'Eat the Rainbow',
  'Protein Power',
  'Smart Snacks',
  'Breakfast Wins',
  'Sugar Check',
  'Move Every Day',
  'Posture Power',
  'Screen Breaks',
  'Sleep Equals Strength',
  'Handwashing Like a Pro',
  'Teeth and Smile Care',
  'Rest and Reset',
  'Breathe to Calm',
  'Gratitude Journal',
  'Faith and Health'
];

const MINI_COURSE_TOPIC_POOL = [...LEADERSHIP_TOPICS, ...HEALTH_TOPICS];

// Randomly select 3 unique topics from the combined pool
function selectRandomTopics() {
  const shuffled = [...MINI_COURSE_TOPIC_POOL].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, 3);
}

function isHealthTopic(topic: string) {
  return HEALTH_TOPICS.includes(topic);
}

// Helper function to sanitize JSON string from AI response
function sanitizeJsonString(rawContent: string): string {
  // Remove markdown code blocks if present
  let cleaned = rawContent.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replace(/^```json\n?|^```\n?/g, '').replace(/```$/g, '').trim();
  }
  
  // Try to parse as-is first
  try {
    JSON.parse(cleaned);
    return cleaned; // If it parses, return as-is
  } catch (e) {
    console.log('Initial parse failed, attempting to fix common JSON issues...');
  }
  
  // Fix common JSON issues:
  // 1. Replace unescaped newlines within strings
  cleaned = cleaned.replace(/([^\\])\n/g, '$1\\n');
  
  // 2. Fix unescaped quotes within string values (but not property names)
  // This is tricky - we'll try a more conservative approach
  // Look for patterns like: "content": "text with "quotes" inside"
  cleaned = cleaned.replace(/: "([^"]*?)"([^,\}\]]*?)"([^:]*?)"/g, (match, p1, p2, p3) => {
    // If p2 contains quotes, it's likely an unescaped quote
    if (p2.includes('"')) {
      return `: "${p1}\\"${p2}\\"${p3}"`;
    }
    return match;
  });
  
  return cleaned;
}

// Main function logic
async function generateCourses() {
  // 1. Get and validate environment variables
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

  if (!SUPABASE_URL || !SERVICE_KEY || !GEMINI_API_KEY) {
    throw new Error("Missing required environment variables (URL, Service Key, or Gemini API Key).");
  }

  // 2. Initialize Supabase admin client
  const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_KEY);
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD format

  // 3. Check for existing courses for today (Idempotency)
  console.log(`Checking for existing courses for date: ${today}`);
  const { data: existingEntry, error: checkError } = await supabaseAdmin
    .from('global_daily_courses')
    .select('id, status')
    .eq('date', today)
    .single();

  if (checkError && checkError.code !== 'PGRST116') {
    throw new Error(`Database error checking for courses: ${checkError.message}`);
  }

  if (existingEntry?.status === 'ready' || existingEntry?.status === 'generating') {
    console.log(`Courses for ${today} are already '${existingEntry.status}'. Exiting.`);
    return {
      success: true,
      message: `Courses already ${existingEntry.status}.`
    };
  }

  // 4. Mark status as 'generating' or create a new entry
  console.log(`Marking status as 'generating' for ${today}.`);
  const { error: upsertError } = await supabaseAdmin
    .from('global_daily_courses')
    .upsert({
      date: today,
      status: 'generating',
      courses: [],
      topics: [],
      updated_at: new Date().toISOString()
    }, { onConflict: 'date' });

  if (upsertError) {
    throw new Error(`Failed to set status to 'generating': ${upsertError.message}`);
  }

  try {
    // 5. Select 3 random topics from the combined leadership + health pool
    const selectedTopics = selectRandomTopics();
    console.log(`Selected topics for today: ${selectedTopics.join(', ')}`);

    const topicHints = selectedTopics.map((topic) => {
      if (isHealthTopic(topic)) {
        return `"${topic}" (health: simple language, no medical jargon, 1 fun fact, 1 action step)`;
      }
      return `"${topic}" (leadership: friendly teacher tone, school/friends/family examples)`;
    }).join(', ');

    // 6. Call Gemini API with kid-friendly prompt
    const prompt = `Generate exactly 3 mini-courses for kids and young teens (ages 8-16) in a valid JSON format. Each course MUST use one of these topics IN ORDER: ${topicHints}.

CRITICAL JSON REQUIREMENTS:
- Return ONLY valid, parseable JSON with NO markdown formatting
- Escape all quotes within string values using backslash (\\")
- Do NOT use single quotes or unescaped double quotes in content
- Avoid special characters that break JSON parsing
- Keep all text on single lines (no literal newlines in strings)

CONTENT REQUIREMENTS:
- Audience: kids and young teens (ages 10-15). Friendly teacher tone, NOT a business book.
- Each lesson "content" must be SHORT: 60-90 words maximum (2-3 simple paragraphs).
- Use school, friends, sports, homework, and family examples only.
- NO adult business references (no CEOs, researchers, negotiation, networking jargon).
- NO dating, violence, politics, or scary content.
- Simple words, short sentences, encouraging tone.
- Include 2-3 short keyTakeaways per lesson (under 8 words each).

Each course must have:
- "title": A fun, kid-friendly title (not corporate)
- "topic": MUST be exactly one of these: "${selectedTopics[0]}", "${selectedTopics[1]}", or "${selectedTopics[2]}"
- "description": One short sentence under 20 words
- "estimatedMinutes": 5
- "lessons": An array of exactly 3 objects, each with:
  - "title": Short lesson title
  - "content": 60-90 words, age-appropriate
  - "keyTakeaways": Array of 2-3 short strings
- "quiz": An object with a "questions" array of exactly 5 objects, each with:
  - "question": A clear, simple question
  - "options": Array of exactly 4 answer choices
  - "correctAnswerIndex": Number (0-3) indicating the correct answer
- QUIZ RULE: Vary correctAnswerIndex across questions—use at least 3 different positions (0,1,2,3) per quiz; never put all correct answers on the same option.

Return ONLY valid JSON in this exact format:
{
  "courses": [
    {
      "title": "Course Title Here",
      "topic": "${selectedTopics[0]}",
      "lessons": [...],
      "quiz": {...}
    },
    {
      "title": "Course Title Here",
      "topic": "${selectedTopics[1]}",
      "lessons": [...],
      "quiz": {...}
    },
    {
      "title": "Course Title Here",
      "topic": "${selectedTopics[2]}",
      "lessons": [...],
      "quiz": {...}
    }
  ]
}`;

    // gemini-2.5-flash-lite is blocked for new API keys; use current Flash-Lite.
    const geminiModel = "gemini-3.1-flash-lite";
    console.log(`Sending request to Gemini API (using ${geminiModel})...`);
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: prompt
                }
              ]
            }
          ],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 8000
            // REMOVED: responseMimeType - not supported by this API version
          }
        })
      }
    );

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      throw new Error(`Gemini API request failed with status ${geminiResponse.status}: ${errorBody}`);
    }

    console.log("Gemini API response received successfully");
    const responseData = await geminiResponse.json();

    // Defensive checks for Gemini response structure
    const candidates = responseData?.candidates;
    if (!Array.isArray(candidates) || candidates.length === 0) {
      console.error("Gemini response has no candidates:", JSON.stringify(responseData).substring(0, 500));
      throw new Error("Gemini API returned no candidates");
    }

    const content = candidates[0]?.content;
    const parts = content?.parts;
    let rawContent = (Array.isArray(parts) && parts.length > 0 && typeof parts[0]?.text === 'string')
      ? parts[0].text
      : undefined;

    // Some responses may use 'text' at a different nesting; attempt a fallback extraction
    if (!rawContent) {
      const firstText = candidates[0]?.content?.parts?.find((p: any) => typeof p?.text === 'string')?.text
        ?? candidates[0]?.content?.text
        ?? responseData?.text;
      if (typeof firstText === 'string') {
        rawContent = firstText;
      }
    }

    if (!rawContent || typeof rawContent !== 'string') {
      console.error("Gemini response missing text field:", JSON.stringify(responseData).substring(0, 800));
      throw new Error("Gemini API response missing text content");
    }

    console.log("Raw content length:", rawContent.length);
    console.log("First 200 chars:", rawContent.substring(0, 200));
    
    // Sanitize and clean the JSON string
    const sanitizedContent = sanitizeJsonString(rawContent);
    
    console.log("Parsing JSON response...");
    let coursesData;
    try {
      coursesData = JSON.parse(sanitizedContent);
    } catch (parseError) {
      console.error("JSON Parse Error:", parseError.message);
      console.error("Problematic content (first 500 chars):", sanitizedContent.substring(0, 500));
      console.error("Problematic content (around error position):", sanitizedContent.substring(Math.max(0, 15591 - 100), 15591 + 100));
      throw new Error(`Failed to parse Gemini response as JSON: ${parseError.message}`);
    }

    if (!coursesData || !Array.isArray(coursesData.courses)) {
      console.error("Parsed object missing courses array:", JSON.stringify(coursesData).substring(0, 500));
      throw new Error("Gemini API did not return a 'courses' array in the expected format.");
    }
    if (coursesData.courses.length !== 3) {
      console.error("Unexpected number of courses:", coursesData.courses.length);
      throw new Error("Gemini API did not return exactly 3 courses in the expected format.");
    }

    console.log("Successfully received and parsed 3 courses from Gemini.");

    // 7. Extract topics from generated courses
    const topics = coursesData.courses.map((c: any) => c.topic);
    console.log(`Generated courses with topics: ${topics.join(', ')}`);

    // 8. Save courses to the database and mark as 'ready'
    const { error: finalUpdateError } = await supabaseAdmin
      .from('global_daily_courses')
      .update({
        status: 'ready',
        courses: coursesData.courses,
        topics: topics,
        generated_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('date', today);

    if (finalUpdateError) {
      throw new Error(`Failed to save generated courses to DB: ${finalUpdateError.message}`);
    }

    console.log(`Successfully generated and stored courses for ${today}.`);

    return {
      success: true,
      message: 'Courses generated successfully.',
      date: today,
      topics
    };

  } catch (generationError) {
    // If any error occurs during generation, mark the entry as 'failed'
    console.error("An error occurred during course generation:", generationError.message);
    const errMsg = String(generationError?.message ?? generationError).slice(0, 1000);
    await supabaseAdmin
      .from('global_daily_courses')
      .update({
        status: 'failed',
        last_error: errMsg,
        updated_at: new Date().toISOString()
      })
      .eq('date', today);

    // Re-throw the error to ensure the function returns a 500 status
    throw generationError;
  }
}

// Use the modern Deno.serve to handle HTTP requests
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const result = await generateCourses();
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  } catch (error) {
    console.error("Handler error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

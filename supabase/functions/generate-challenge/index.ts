// AI Challenge Generator Edge Function
// Generates challenges using Gemini API with server-side API key

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Supported rule types (whitelist)
const SUPPORTED_RULE_TYPES = [
  'gratitude_streak_days',
  'gratitude_count_in_window',
  'daily_goal_streak_days',
  'daily_goal_count_in_window',
  'main_goals_completed',
  'main_goal_count_in_window',
  'any_goals_completed',
  'mini_courses_completed',
]

const SUPPORTED_WINDOW_TYPES = [
  'fixed_window',
  'rolling_days',
  'per_user_enrollment',
]

interface GenerateRequest {
  theme: string
  difficulty: 'easy' | 'medium' | 'hard'
  targetAudience: string
  durationDays: number
  additionalContext?: string
}

interface ChallengeRule {
  ruleType: string
  targetValue: number
  windowType: string
  windowValueDays?: number
  consecutiveRequired?: boolean
  maxGapDays?: number
  groupId?: string
  groupOperator?: string
}

interface GeneratedChallenge {
  title: string
  description: string
  coinReward: number
  durationDays: number
  criteria: string[]
  rules: ChallengeRule[]
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get Gemini API key from secrets
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      throw new Error('GEMINI_API_KEY not configured in Supabase secrets')
    }

    // Parse request
    const { theme, difficulty, targetAudience, durationDays, additionalContext } = await req.json() as GenerateRequest

    // Validate input
    if (!theme || !difficulty || !targetAudience || !durationDays) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (durationDays < 1 || durationDays > 90) {
      return new Response(
        JSON.stringify({ error: 'Duration must be 1-90 days' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Build prompt
    const prompt = buildPrompt(theme, difficulty, targetAudience, durationDays, additionalContext)

    // Call Gemini API
    const challenge = await generateWithGemini(geminiApiKey, prompt)

    if (!challenge) {
      return new Response(
        JSON.stringify({ error: 'Failed to generate challenge' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate generated challenge
    const validation = validateChallenge(challenge)
    if (!validation.isValid) {
      console.error('Validation failed:', validation.errors)
      return new Response(
        JSON.stringify({ error: 'Generated challenge failed validation', details: validation.errors }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Calculate quality score
    const qualityScore = calculateQualityScore(challenge)

    // Return generated challenge
    return new Response(
      JSON.stringify({
        success: true,
        challenge: {
          ...challenge,
          qualityScore,
        },
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error generating challenge:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

function buildPrompt(
  theme: string,
  difficulty: string,
  targetAudience: string,
  durationDays: number,
  additionalContext?: string
): string {
  return `You are an expert challenge designer for "My Leadership Quest", an educational app for young leaders.

Generate a SINGLE basic challenge that can be automatically tracked and validated by the app.

CRITICAL CONSTRAINTS:
You MUST ONLY use these rule types (no exceptions):
- gratitude_streak_days: Consecutive days with gratitude journal entries
- gratitude_count_in_window: Total gratitude entries in a time window
- daily_goal_streak_days: Consecutive days with completed daily goals
- daily_goal_count_in_window: Total daily goals completed in window
- main_goals_completed: Number of main goals completed
- main_goal_count_in_window: Same as main_goals_completed
- any_goals_completed: Combined daily + main goals completed
- mini_courses_completed: Mini courses completed with 70%+ score

WINDOW TYPES (choose one):
- fixed_window: Challenge start to end date
- rolling_days: Last N days (specify windowValueDays)
- per_user_enrollment: Since user joined challenge

REQUIREMENTS:
- Theme: ${theme}
- Difficulty: ${difficulty} (easy: 1-2 rules, medium: 2-3 rules, hard: 3+ rules or high targets)
- Target Audience: ${targetAudience}
- Duration: ${durationDays} days
${additionalContext ? `- Additional Context: ${additionalContext}` : ''}

RULES:
1. Title: Catchy, motivational, max 50 characters
2. Description: Clear, specific, encouraging, max 200 characters
3. Coin Reward: 
   - Easy: 50-100 coins
   - Medium: 100-200 coins
   - Hard: 200-300 coins
4. Target Values: Realistic for the duration and difficulty
5. Rules: 1-3 rules maximum
6. Criteria: 3-5 bullet points explaining what to do
7. NO physical activities, NO external validation, NO subjective tasks

OUTPUT FORMAT (JSON only, no markdown):
{
  "title": "Challenge Title",
  "description": "Clear description of what to do",
  "coinReward": 100,
  "durationDays": ${durationDays},
  "criteria": [
    "First criterion",
    "Second criterion",
    "Third criterion"
  ],
  "rules": [
    {
      "ruleType": "daily_goal_streak_days",
      "targetValue": 7,
      "windowType": "per_user_enrollment",
      "windowValueDays": null,
      "consecutiveRequired": true,
      "maxGapDays": 0,
      "groupId": "main",
      "groupOperator": "all"
    }
  ]
}

Generate the challenge now. Return ONLY valid JSON, no explanations.`
}

async function generateWithGemini(apiKey: string, prompt: string): Promise<GeneratedChallenge | null> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=${apiKey}`

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        },
      }),
    })

    if (!response.ok) {
      console.error('Gemini API error:', response.status, await response.text())
      return null
    }

    const data = await response.json()
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text

    if (!text) {
      console.error('No text in Gemini response')
      return null
    }

    // Parse JSON from response (handle markdown code blocks)
    let jsonStr = text.trim()
    if (jsonStr.startsWith('```json')) {
      jsonStr = jsonStr.substring(7)
    }
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.substring(3)
    }
    if (jsonStr.endsWith('```')) {
      jsonStr = jsonStr.substring(0, jsonStr.length - 3)
    }
    jsonStr = jsonStr.trim()

    return JSON.parse(jsonStr)
  } catch (error) {
    console.error('Error calling Gemini API:', error)
    return null
  }
}

function validateChallenge(challenge: GeneratedChallenge): { isValid: boolean; errors: string[] } {
  const errors: string[] = []

  // Validate title
  if (!challenge.title || challenge.title.length > 50) {
    errors.push('Title must be 1-50 characters')
  }

  // Validate description
  if (!challenge.description || challenge.description.length > 200) {
    errors.push('Description must be 1-200 characters')
  }

  // Validate coin reward
  if (challenge.coinReward < 50 || challenge.coinReward > 300) {
    errors.push('Coin reward must be 50-300')
  }

  // Validate rules
  if (!challenge.rules || challenge.rules.length === 0 || challenge.rules.length > 3) {
    errors.push('Must have 1-3 rules')
  }

  for (const rule of challenge.rules || []) {
    // Validate rule type
    if (!SUPPORTED_RULE_TYPES.includes(rule.ruleType)) {
      errors.push(`Invalid rule type: ${rule.ruleType}`)
    }

    // Validate window type
    if (!SUPPORTED_WINDOW_TYPES.includes(rule.windowType)) {
      errors.push(`Invalid window type: ${rule.windowType}`)
    }

    // Validate target value
    if (rule.targetValue <= 0) {
      errors.push('Target value must be positive')
    }

    // Validate window_value_days for rolling_days
    if (rule.windowType === 'rolling_days' && (!rule.windowValueDays || rule.windowValueDays <= 0)) {
      errors.push('rolling_days requires positive windowValueDays')
    }
  }

  // Validate criteria
  if (!challenge.criteria || challenge.criteria.length === 0 || challenge.criteria.length > 5) {
    errors.push('Must have 1-5 criteria')
  }

  return {
    isValid: errors.length === 0,
    errors,
  }
}

function calculateQualityScore(challenge: GeneratedChallenge): number {
  let score = 10.0

  // Title quality
  if (challenge.title.length < 10) score -= 1.0
  if (challenge.title.length > 45) score -= 0.5
  if (!hasMotivationalWords(challenge.title)) score -= 0.5

  // Description quality
  if (challenge.description.length < 50) score -= 1.0
  if (challenge.description.length > 180) score -= 0.5
  if (!hasMotivationalWords(challenge.description)) score -= 0.5

  // Coin reward appropriateness
  const expectedReward = calculateExpectedReward(challenge)
  const rewardDiff = Math.abs(challenge.coinReward - expectedReward)
  if (rewardDiff > 50) score -= 1.0

  // Rule complexity
  if (challenge.rules.length === 1 && challenge.rules[0].targetValue < 3) {
    score -= 1.0 // Too easy
  }

  // Criteria quality
  if (challenge.criteria.length < 3) score -= 0.5

  return Math.max(0, Math.min(10, score))
}

function hasMotivationalWords(text: string): boolean {
  const motivationalWords = [
    'achieve', 'master', 'champion', 'warrior', 'hero', 'quest', 'journey',
    'build', 'grow', 'develop', 'improve', 'excel', 'succeed', 'conquer',
    'challenge', 'streak', 'consistency', 'dedication', 'commitment',
  ]
  const lowerText = text.toLowerCase()
  return motivationalWords.some(word => lowerText.includes(word))
}

function calculateExpectedReward(challenge: GeneratedChallenge): number {
  let baseReward = 50

  // Add reward for each rule
  baseReward += challenge.rules.length * 30

  // Add reward for target values
  for (const rule of challenge.rules) {
    if (rule.targetValue >= 10) baseReward += 30
    else if (rule.targetValue >= 5) baseReward += 20
    else baseReward += 10
  }

  // Add reward for duration
  if (challenge.durationDays >= 30) baseReward += 50
  else if (challenge.durationDays >= 14) baseReward += 30
  else if (challenge.durationDays >= 7) baseReward += 20

  return Math.max(50, Math.min(300, baseReward))
}

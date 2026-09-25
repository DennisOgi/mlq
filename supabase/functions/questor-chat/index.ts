// Questor chat proxy — keeps GEMINI_API_KEY server-side

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

const MODEL = 'gemini-3.1-flash-lite'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY not configured in Supabase secrets' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const body = await req.json()
    const contents = body?.contents
    if (!Array.isArray(contents) || contents.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing contents' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const generationConfig = body?.generationConfig ?? {
      temperature: 0.8,
      topK: 40,
      topP: 0.95,
      maxOutputTokens: 300,
    }

    const safetySettings = body?.safetySettings ?? [
      { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
      { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
    ]

    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${geminiApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents, generationConfig, safetySettings }),
      },
    )

    const responseText = await geminiResponse.text()
    if (!geminiResponse.ok) {
      console.error('Gemini error:', geminiResponse.status, responseText.slice(0, 500))
      return new Response(
        JSON.stringify({
          error: `Gemini API request failed with status ${geminiResponse.status}`,
          details: responseText.slice(0, 1000),
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const data = JSON.parse(responseText)
    const text =
      data?.candidates?.[0]?.content?.parts?.[0]?.text?.toString?.() ?? null

    if (!text) {
      return new Response(
        JSON.stringify({ error: 'No text in Gemini response', details: data }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    return new Response(
      JSON.stringify({ success: true, text, model: MODEL }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error('questor-chat handler error:', message)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})

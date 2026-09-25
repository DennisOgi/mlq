import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-admin-secret',
}

function generatePassword(seed: string): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let suffix = ''
  for (let i = 0; i < 6; i++) {
    suffix += chars[(seed.charCodeAt(i % seed.length) + i * 7) % chars.length]
  }
  return `Jnissi@MLQ${suffix}`
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const adminSecret = Deno.env.get('SCHOOL_PASSWORD_RESET_SECRET')
    const provided = req.headers.get('x-admin-secret')
    if (!adminSecret || provided !== adminSecret) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const db = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const body = await req.json().catch(() => ({}))
    const schoolPattern = (body?.schoolPattern as string) ?? 'jnissi'

    const { data: profiles, error: pErr } = await db
      .from('profiles')
      .select('id, name, school_name')
      .ilike('school_name', `%${schoolPattern}%`)
    if (pErr) throw pErr

    const results: Array<{ email: string; name: string; school: string; password: string }> = []
    const failures: Array<{ id: string; name: string; error: string }> = []

    for (const profile of profiles ?? []) {
      try {
        const { data: userData, error: uErr } = await db.auth.admin.getUserById(profile.id)
        if (uErr || !userData.user?.email) {
          failures.push({ id: profile.id, name: profile.name, error: uErr?.message ?? 'No email' })
          continue
        }

        const password = generatePassword(profile.id)
        const { error: updErr } = await db.auth.admin.updateUserById(profile.id, { password })
        if (updErr) {
          failures.push({ id: profile.id, name: profile.name, error: updErr.message })
          continue
        }

        results.push({
          email: userData.user.email,
          name: profile.name,
          school: profile.school_name,
          password,
        })
      } catch (e) {
        failures.push({ id: profile.id, name: profile.name, error: (e as Error).message })
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        resetCount: results.length,
        failureCount: failures.length,
        users: results,
        failures,
        note: 'Passwords do not expire automatically. Ask students to change them in Profile settings.',
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: (e as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

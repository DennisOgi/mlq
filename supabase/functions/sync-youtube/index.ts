import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SKIP_SYNC_HOURS = 23
const MAX_PLAYLISTS_PER_CHANNEL = 25
const MAX_VIDEOS_PER_PLAYLIST = 50

const KURZGESAGT_CHANNEL_ID = 'UCsXVk37bltHxD1rDPwtNM8Q'
const BLOCKED_KURZGESAGT_PLAYLIST_IDS = new Set(['PLFs4vir_WsTxmlWOMqFdKRwwErRbnep0d'])
const ALLOWED_EXTRA_PLAYLIST_IDS = new Set([
  'PLJicmE8fK0EiTqtnTb9Mjb4UUyMt39YVQ', // Humans vs. Viruses
  'PLhz12vamHOnagseIgy26MoPI79NXiFBwN', // Space Science: The Sun and Its Influence on Earth
  'PLJicmE8fK0EiFngx7wBddZDzxogj-shyW', // Think Like a Coder
])

interface YtChannel {
  id: string
  name: string
  subject: string
  synced_at: string | null
}

function parseIso8601Duration(iso: string): number {
  if (!iso || !iso.startsWith('PT')) return 0
  const m = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
  if (!m) return 0
  const h = parseInt(m[1] ?? '0', 10)
  const min = parseInt(m[2] ?? '0', 10)
  const s = parseInt(m[3] ?? '0', 10)
  return h * 3600 + min * 60 + s
}

function isForeignLanguageContent(title: string, description?: string | null): boolean {
  const text = `${title} ${description ?? ''}`
  const lower = text.toLowerCase()
  if (
    lower.includes('literature') &&
    !/\b(lesson|learn|speak|language course)\b/.test(lower)
  ) {
    return false
  }
  if (/[\u0400-\u04FF\u4E00-\u9FFF\u0600-\u06FF\u0900-\u097F\u0590-\u05FF]/.test(text)) return true
  const patterns = [
    /\b(espa[nñ]ol|spanish lesson|learn spanish|curso de espa[nñ]ol|speak spanish)\b/,
    /\b(fran[cç]ais|french lesson|learn french|speak french|le fran[cç]ais)\b/,
    /\b(deutsch|german lesson|learn german|speak german)\b/,
    /\b(portugu[eê]s|portuguese lesson|learn portuguese|speak portuguese)\b/,
    /\b(italiano|italian lesson|learn italian|speak italian)\b/,
    /\b(mandarin|cantonese|chinese lesson|learn chinese|speak chinese)\b/,
    /\b(japanese lesson|learn japanese|speak japanese|nihongo)\b/,
    /\b(korean lesson|learn korean|speak korean|hangul)\b/,
    /\b(hindi lesson|learn hindi|speak hindi|urdu lesson|bengali lesson)\b/,
    /\b(arabic lesson|learn arabic|speak arabic)\b/,
    /\b(welsh lesson|learn welsh|cymraeg|speak welsh)\b/,
    /\b(gaelic|irish lesson|learn irish|speak irish)\b/,
    /\b(russian lesson|learn russian|speak russian)\b/,
    /\b(learn [a-z]+ language|language lesson|foreign language)\b/,
    /\b(duolingo|babel|rosetta stone)\b/,
  ]
  return patterns.some((re) => re.test(lower))
}

function inferSubject(title: string, channelSubject: string): string {
  const t = title.toLowerCase
    ? title.toLowerCase()
    : ''
  if (isForeignLanguageContent(title)) return 'foreign_language'
  if (/biology|cell|dna|genetic|anatomy|ecosystem|evolution/.test(t)) return 'biology'
  if (/chemistry|atom|molecule|periodic|reaction|acid|base/.test(t)) return 'chemistry'
  if (/physics|force|energy|motion|electric|quantum|wave|newton/.test(t)) return 'physics'
  if (/math|algebra|geometry|calculus|trigonometry|statistics|arithmetic/.test(t)) return 'mathematics'
  if (/english|literature|writing|grammar|poem|shakespeare|essay/.test(t)) return 'english'
  if (/health|wellness|sleep|stress|nutrition|mental|body|exercise|mind/.test(t)) return 'health_wellness'
  return channelSubject
}

function isBlockedContent(title: string, description?: string | null): boolean {
  const text = `${title} ${description ?? ''}`.toLowerCase()
  const blocked = [
    /\bsex ed\b/,
    /\bsex education\b/,
    /\bsexual intercourse\b/,
    /\bsexuality\b/,
    /\bmasturbat/,
    /\bporn\b/,
    /\bpornography\b/,
    /\bcontracept/,
    /\bcondom\b/,
    /\bbirth control\b/,
    /\bstd\b/,
    /\bsti\b/,
    /\bsexually transmitted\b/,
    /\babortion\b/,
    /\bpuberty\b/,
    /\breproductive system\b/,
    /\bintercourse\b/,
    /\borgasm\b/,
    /\bvirginity\b/,
    /\berectile\b/,
    /\bpenis\b/,
    /\bvagina\b/,
    /\bsexual health\b/,
    /\bsexual reproduction\b/,
    /\bcivil rights\b/,
    /\bcivil liberties\b/,
    /\bselma\b/,
    /\brosa parks\b/,
    /\bjim crow\b/,
    /\bap us government\b/,
  ]
  return blocked.some((re) => re.test(text))
}

function isBlockedKurzgesagtSensitive(title: string, description?: string | null): boolean {
  const text = `${title} ${description ?? ''}`.toLowerCase()
  const blocked = [
    /\bdrug\b/,
    /\bdrugs\b/,
    /\bmarijuana\b/,
    /\bweed\b/,
    /\bcannabis\b/,
    /\bcocaine\b/,
    /\bheroin\b/,
    /\bfentanyl\b/,
    /\blsd\b/,
    /\bpsychedelic\b/,
    /\bopioid\b/,
    /\bvaping\b/,
    /\bozempic\b/,
    /\balcohol\b/,
    /\bwar on drugs\b/,
    /\breligion\b/,
    /\bnihilism\b/,
    /\batheis/,
    /\bgod\b/,
    /\bgods\b/,
    /\bchrist\b/,
    /\bislam\b/,
    /\bbuddh/,
    /\bafterlife\b/,
    /\bsoul\b/,
    /\bpray\b/,
    /\bchurch\b/,
    /\bmosque\b/,
    /\bbible\b/,
    /\bquran\b/,
    /\bhindu\b/,
    /\bjewish\b/,
    /\bsex ed\b/,
    /\bsex education\b/,
    /\bsexual intercourse\b/,
    /\bsexuality\b/,
    /\bmasturbat/,
    /\bporn\b/,
    /\bpornography\b/,
    /\bintercourse\b/,
    /\borgasm\b/,
  ]
  return blocked.some((re) => re.test(text))
}

function isAllowedPlaylist(playlistId: string, channelId: string, title: string): boolean {
  if (ALLOWED_EXTRA_PLAYLIST_IDS.has(playlistId)) return true
  if (BLOCKED_KURZGESAGT_PLAYLIST_IDS.has(playlistId)) return false
  if (title.toLowerCase().trim() === 'drugs') return false
  if (channelId === KURZGESAGT_CHANNEL_ID) return true
  return false
}

function isBlockedForSubject(subject: string, title: string, description?: string | null): boolean {
  if (isBlockedContent(title, description)) return true
  const text = `${title} ${description ?? ''}`.toLowerCase()
  if (subject === 'foreign_language') {
    return false
  }
  if (subject === 'english') {
    if (isForeignLanguageContent(title, description)) return true
    if (/\b(breadboard computer|digital electronics|networking tutorial|error detection)\b/.test(text)) return true
  }
  if (subject === 'chemistry') {
    if (/\b(personal finance|stocks and bonds|stock market|invest|excel tutorial|fraction|percentage|linear equation|number system|electronic circuit|breadboard|6502|networking tutorial|study tips|channel growth|interesting questions)\b/.test(text)) return true
  }
  return false
}

function inferDifficulty(title: string): string | null {
  const t = title.toLowerCase()
  if (/intro|beginner|basics|101|for kids|elementary|grade [1-8]/.test(t)) return 'beginner'
  if (/advanced|ap |a-level|university|deep dive|master/.test(t)) return 'advanced'
  if (/intermediate|part 2|continued/.test(t)) return 'intermediate'
  return null
}

async function ytFetch(path: string, apiKey: string, params: Record<string, string>) {
  const url = new URL(`https://www.googleapis.com/youtube/v3/${path}`)
  url.searchParams.set('key', apiKey)
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v)
  const res = await fetch(url.toString())
  if (!res.ok) {
    const body = await res.text()
    throw new Error(`YouTube API ${path} failed: ${res.status} ${body}`)
  }
  return res.json()
}

async function resolveYoutubeApiKey(db: ReturnType<typeof createClient>): Promise<string> {
  const fromEnv = Deno.env.get('YOUTUBE_API_KEY')
  if (fromEnv) return fromEnv

  const { data, error } = await db
    .from('internal_secrets')
    .select('value')
    .eq('key', 'YOUTUBE_API_KEY')
    .maybeSingle()
  if (error) throw error
  if (data?.value) return data.value as string

  throw new Error('YOUTUBE_API_KEY is not configured (env or internal_secrets)')
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const db = createClient(supabaseUrl, serviceKey)

    const apiKey = await resolveYoutubeApiKey(db)

    const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {}
    const force = body?.force === true
    const channelFilter = body?.channelId as string | undefined

    const { data: channels, error: chErr } = await db
      .from('yt_channels')
      .select('id, name, subject, synced_at')
    if (chErr) throw chErr

    let playlistCount = 0
    let videoCount = 0
    const errors: string[] = []
    const now = Date.now()

    for (const channel of (channels as YtChannel[]) ?? []) {
      if (channelFilter && channel.id !== channelFilter) continue

      if (!force && channel.synced_at) {
        const syncedMs = new Date(channel.synced_at).getTime()
        if (now - syncedMs < SKIP_SYNC_HOURS * 3600 * 1000) {
          continue
        }
      }

      try {
        let pageToken: string | undefined
        let fetchedPlaylists = 0
        const seenPlaylistIds = new Set<string>()

        do {
          const plData = await ytFetch('playlists', apiKey, {
            part: 'snippet,contentDetails',
            channelId: channel.id,
            maxResults: '50',
            ...(pageToken ? { pageToken } : {}),
          })

          for (const item of plData.items ?? []) {
            if (fetchedPlaylists >= MAX_PLAYLISTS_PER_CHANNEL) break
            const pid = item.id as string
            seenPlaylistIds.add(pid)
            const thumbs = item.snippet?.thumbnails
            const thumb =
              thumbs?.maxres?.url ?? thumbs?.high?.url ?? thumbs?.medium?.url ?? thumbs?.default?.url
            const plDesc = item.snippet?.description ?? null
            const title = item.snippet?.title ?? 'Untitled'
            const subject = inferSubject(title, channel.subject)
            const plAvailable = isAllowedPlaylist(pid, channel.id, title) &&
              !isBlockedForSubject(subject, title, plDesc) &&
              subject !== 'history' &&
              !/\bap\/college us history\b/i.test(title)

            const { error: upErr } = await db.from('yt_playlists').upsert(
              {
                id: pid,
                channel_id: channel.id,
                title,
                description: plDesc,
                thumbnail_url: thumb,
                video_count: item.contentDetails?.itemCount ?? 0,
                subject,
                difficulty: inferDifficulty(title),
                is_available: plAvailable,
                synced_at: new Date().toISOString(),
              },
              { onConflict: 'id' },
            )
            if (upErr) throw upErr
            playlistCount++
            fetchedPlaylists++

            // Fetch playlist videos
            let vidPage: string | undefined
            const videoIdsInPlaylist: string[] = []
            const positions = new Map<string, number>()

            do {
              const piData = await ytFetch('playlistItems', apiKey, {
                part: 'snippet',
                playlistId: pid,
                maxResults: '50',
                ...(vidPage ? { pageToken: vidPage } : {}),
              })

              for (const pi of piData.items ?? []) {
                const vid = pi.snippet?.resourceId?.videoId
                if (!vid) continue
                if (videoIdsInPlaylist.length >= MAX_VIDEOS_PER_PLAYLIST) break
                videoIdsInPlaylist.push(vid)
                positions.set(vid, pi.snippet?.position ?? videoIdsInPlaylist.length - 1)
              }
              vidPage = piData.nextPageToken
            } while (vidPage && videoIdsInPlaylist.length < MAX_VIDEOS_PER_PLAYLIST)

            // Batch video details (50 at a time)
            for (let i = 0; i < videoIdsInPlaylist.length; i += 50) {
              const batch = videoIdsInPlaylist.slice(i, i + 50)
              const vData = await ytFetch('videos', apiKey, {
                part: 'snippet,contentDetails',
                id: batch.join(','),
              })

              for (const v of vData.items ?? []) {
                const vid = v.id as string
                const vThumbs = v.snippet?.thumbnails
                const vThumb =
                  vThumbs?.maxres?.url ??
                  vThumbs?.high?.url ??
                  vThumbs?.medium?.url ??
                  vThumbs?.default?.url

                const vTitle = v.snippet?.title ?? 'Untitled'
                const vDesc = v.snippet?.description ?? null

                const { error: vErr } = await db.from('yt_videos').upsert(
                  {
                    id: vid,
                    playlist_id: pid,
                    channel_id: channel.id,
                    title: vTitle,
                    description: vDesc,
                    thumbnail_url: vThumb,
                    duration_iso: v.contentDetails?.duration ?? null,
                    duration_seconds: parseIso8601Duration(v.contentDetails?.duration ?? ''),
                    position: positions.get(vid) ?? 0,
                    published_at: v.snippet?.publishedAt ?? null,
                    is_available: plAvailable &&
                      !(channel.id === KURZGESAGT_CHANNEL_ID &&
                        isBlockedKurzgesagtSensitive(vTitle, vDesc)) &&
                      !isBlockedForSubject(subject, vTitle, vDesc),
                  },
                  { onConflict: 'id' },
                )
                if (vErr) throw vErr
                videoCount++
              }
            }
          }

          pageToken = plData.nextPageToken
        } while (pageToken && fetchedPlaylists < MAX_PLAYLISTS_PER_CHANNEL)

        await db.from('yt_channels').update({ synced_at: new Date().toISOString() }).eq('id', channel.id)
      } catch (e) {
        errors.push(`${channel.name}: ${(e as Error).message}`)
      }
    }

    // Mark featured playlists (top by video count per subject)
    const { data: topPl } = await db
      .from('yt_playlists')
      .select('id, subject, video_count, channel_id, title')
      .eq('is_available', true)
      .order('video_count', { ascending: false })

    if (topPl && topPl.length > 0) {
      await db.from('yt_playlists').update({ is_featured: false }).neq('id', '')
      const featuredBySubject = new Map<string, string>()
      for (const pl of topPl) {
        const sub = pl.subject ?? 'general'
        if (sub === 'history') continue
        if (!isAllowedPlaylist(
          pl.id as string,
          (pl.channel_id as string) ?? '',
          (pl.title as string) ?? '',
        )) continue
        if (!featuredBySubject.has(sub) && (pl.video_count ?? 0) >= 3) {
          featuredBySubject.set(sub, pl.id as string)
        }
      }
      for (const id of featuredBySubject.values()) {
        await db.from('yt_playlists').update({ is_featured: true }).eq('id', id)
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        channels: channels?.length ?? 0,
        playlists: playlistCount,
        videos: videoCount,
        errors,
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

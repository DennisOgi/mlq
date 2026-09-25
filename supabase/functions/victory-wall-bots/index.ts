import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("VICTORY_WALL_BOT_CRON_SECRET") ?? "";

type Slot = "morning" | "afternoon" | "evening" | "auto" | "manual";
type Persona = "ada" | "tunde" | "mira";

interface BotDef {
  id: string;
  name: string;
  email: string;
  age: number;
  persona: Persona;
}

/** Daily poster rotation — 3 slots × 16 names ≈ 5-day cycle before repeats. */
const ROTATION_ORDER = [
  "Orel", "Zara", "Aiden", "Mira", "Vikky", "Kian", "Ari", "Nia",
  "Elias", "Hope", "Leo", "Sol", "Tunde", "Kemi", "Ada", "Femz",
] as const;

const BOTS: BotDef[] = [
  { id: "a1000001-0001-4001-8001-000000000001", name: "Ada", email: "mlq-victory-ada@bots.myleadershipquest.internal", age: 14, persona: "ada" },
  { id: "a1000001-0001-4001-8001-000000000002", name: "Tunde", email: "mlq-victory-tunde@bots.myleadershipquest.internal", age: 16, persona: "tunde" },
  { id: "a1000001-0001-4001-8001-000000000003", name: "Mira", email: "mlq-victory-mira@bots.myleadershipquest.internal", age: 13, persona: "mira" },
  { id: "a1000001-0001-4001-8001-000000000004", name: "Leo", email: "mlq-victory-leo@bots.myleadershipquest.internal", age: 15, persona: "tunde" },
  { id: "a1000001-0001-4001-8001-000000000005", name: "Nia", email: "mlq-victory-nia@bots.myleadershipquest.internal", age: 14, persona: "mira" },
  { id: "a1000001-0001-4001-8001-000000000006", name: "Hope", email: "mlq-victory-hope@bots.myleadershipquest.internal", age: 13, persona: "ada" },
  { id: "a1000001-0001-4001-8001-000000000007", name: "Kemi", email: "mlq-victory-kemi@bots.myleadershipquest.internal", age: 15, persona: "ada" },
  { id: "a1000001-0001-4001-8001-000000000008", name: "Elias", email: "mlq-victory-elias@bots.myleadershipquest.internal", age: 16, persona: "tunde" },
  { id: "a1000001-0001-4001-8001-000000000009", name: "Sol", email: "mlq-victory-sol@bots.myleadershipquest.internal", age: 14, persona: "tunde" },
  { id: "a1000001-0001-4001-8001-00000000000a", name: "Zara", email: "mlq-victory-zara@bots.myleadershipquest.internal", age: 15, persona: "mira" },
  { id: "a1000001-0001-4001-8001-00000000000b", name: "Ari", email: "mlq-victory-ari@bots.myleadershipquest.internal", age: 13, persona: "mira" },
  { id: "a1000001-0001-4001-8001-00000000000c", name: "Orel", email: "mlq-victory-orel@bots.myleadershipquest.internal", age: 15, persona: "ada" },
  { id: "a1000001-0001-4001-8001-00000000000d", name: "Aiden", email: "mlq-victory-aiden@bots.myleadershipquest.internal", age: 15, persona: "mira" },
  { id: "a1000001-0001-4001-8001-00000000000e", name: "Vikky", email: "mlq-victory-vikky@bots.myleadershipquest.internal", age: 14, persona: "ada" },
  { id: "a1000001-0001-4001-8001-00000000000f", name: "Kian", email: "mlq-victory-kian@bots.myleadershipquest.internal", age: 16, persona: "tunde" },
  { id: "a1000001-0001-4001-8001-000000000010", name: "Femz", email: "mlq-victory-femz@bots.myleadershipquest.internal", age: 15, persona: "ada" },
];

const LIKE_TARGET_MIN = 6;
const LIKE_TARGET_MAX = 7;

/** Real users whose Victory Wall posts get bot-liker boosts (comma-separated UUIDs in env). */
const BOOSTED_USER_IDS = (
  Deno.env.get("VICTORY_WALL_BOOSTED_USER_IDS") ??
  "a3ba4932-db8f-40d1-9cb8-c09d77aece02"
)
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const BOT_USER_IDS = new Set(BOTS.map((b) => b.id));

/** Base lines — Nigerian school/home context, standard English (no pidgin). */
const CONTENT: Record<Persona, string[]> = {
  ada: [
    "Woke up for morning devotion, prayed briefly, and wrote my 3 tasks before getting ready for school. Small win but I feel set for today.",
    "Took the bin out and swept the compound without being asked. Mum noticed and that felt good.",
    "Finished today’s morning routine mini-course. Planning three tasks before assembly really helps.",
    "Wrote one thing I am grateful for before sleeping last night. Trying to keep it up this week.",
    "Helped my younger cousin with homework after school. It feels nice to show up for family.",
    "Packed my bag and ironed my uniform the night before. Morning was less rushed for everyone.",
    "Thanked my mum properly after breakfast instead of rushing off. Small habit, better mood.",
    "Drank water first thing, then opened my planner. My morning routine is finally taking shape.",
    "Completed all three tasks on my list before night prep. That does not happen often for me.",
    "Washed plates after dinner without waiting to be called. Responsibility starts at home.",
    "Read a few pages before bed instead of scrolling. I slept with a clearer head.",
    "Wrote a thank-you note in my head for my class teacher today. She puts in a lot.",
    "Laid out my sandals and school bag by the door. Less shouting in the morning.",
    "Checked My Leadership Quest before WhatsApp. Priorities first, for once.",
    "Said sorry quickly after raising my voice at my sibling. Fixing things matters too.",
    "Made my bed before leaving the room. My mum walked in and smiled.",
    "Did one minute of stretches after brushing my teeth. Simple start, steady day.",
    "Told a friend about my 3-task planner. She wants to try it this week too.",
    "Named one win out loud before sleeping. Today was not perfect but it counted.",
    "Fetched water when the tap was running low at home. Little duties, big difference.",
  ],
  tunde: [
    "Did ten extra minutes on maths even though I wanted to close my notebook. One more round is real.",
    "Failed a test last term. This term I am treating each mistake as something to learn from.",
    "Remembering this today: you do not have to feel fully ready before you begin.",
    "Sat with a difficult subject for ten minutes after school. Not perfect, but I showed up.",
    "The resilience mini-course really spoke to me — giving up easily can become a habit too.",
    "Missed my study target yesterday. I started again this morning without making excuses.",
    "Read in a quiet corner during prep while my phone stayed in my bag.",
    "Worked through two questions I failed last week. Errors can teach you if you revisit them.",
    "Wrote a simple plan on paper: one action, one person to ask, one start date.",
    "Waited after class to ask my teacher about a topic I did not understand. Pride can wait.",
    "Timed myself on one practice set. Slow progress is still progress.",
    "Told myself one more time before shutting my book. It actually helped.",
    "Compared myself to yesterday, not to the whole class. That is a fairer measure.",
    "Slept earlier so I could study in the morning before traffic. Energy matters.",
    "Used the PAUSE tip when group work got tense. I did not let it turn into quarrel.",
    "Noted what distracted me today and removed one thing for tomorrow.",
    "Summarised a chapter in my own words. Things started to click.",
    "Admitted I was stuck and asked a friend to explain. My ego relaxed, my understanding grew.",
    "Marked six days on my study calendar. I want to keep the streak going.",
    "Closed today knowing I did not abandon the hard part. That is the win.",
  ],
  mira: [
    "Who else tried the ten-minute no-phone challenge during prep? It was hard but I managed.",
    "Shared my notes with a classmate who missed school yesterday. Kindness is part of leadership.",
    "Asked one question in class today. My heart was pounding but I am glad I spoke.",
    "Focus muscle day was tough. I still count it because I started.",
    "If you had five hundred naira, would you save or spend? That lesson is still on my mind.",
    "Walked up to someone sitting alone during break and said hello. Small step, real courage.",
    "Planned next term on one page instead of worrying in my head. I feel less scattered.",
    "Asked a quiet classmate to join our group task. Awkward for a moment, worth it.",
    "Complimented a friend after her presentation in class. Her smile made my day too.",
    "Practised my introduction in front of the mirror before oral English. Less stumbling.",
    "Left my phone in the sitting room while doing homework. Focus felt possible.",
    "Spoke up in a group project instead of staying silent. We got more done.",
    "Broke a big assignment into daily pieces on my planner. Less last-minute panic.",
    "Thanked the school cleaner this morning. People notice when you show respect.",
    "Recorded a short future-me speech for the mini-course. I cringed watching it but I tried.",
    "Kept part of my pocket money instead of spending everything on snacks after school.",
    "Wrote one lesson from a past mistake at the front of my notebook.",
    "Explained a topic to a classmate without making her feel foolish. Kindness counts.",
    "Stayed out of gossip on the class WhatsApp group. I felt lighter afterwards.",
    "Ended the day wondering who else is building better habits this term. We can do this.",
  ],
};

const MINI_COURSE_HOOKS: string[] = [
  "Today’s morning routine lesson helped — wake up, pray, plan three tasks.",
  "The focus muscle mini-course is serious work. Phone away for ten minutes.",
  "Kindness is leadership — I tried one small include-someone moment today.",
  "The money and choices lesson made me think before buying puff-puff after school.",
  "Practised my future-me speech tonight. Nervous, but I am glad I tried.",
  "One more time on my difficult subject — the mini-course was right.",
  "Did my leader-of-the-house task before school. Responsibility builds trust at home.",
  "The speak-up lesson pushed me to ask one question in class. Glad I did.",
];

function contentKey(line: string): string {
  return line.trim().toLowerCase().slice(0, 96);
}

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function shuffle<T>(arr: T[]): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function randomInt(min: number, max: number): number {
  return min + Math.floor(Math.random() * (max - min + 1));
}

function resolveSlot(raw: Slot): Exclude<Slot, "auto" | "manual"> {
  if (raw !== "auto" && raw !== "manual") return raw;
  const hour = new Date().getUTCHours();
  if (hour < 10) return "morning";
  if (hour < 15) return "afternoon";
  return "evening";
}

function lagosDayNumber(date = new Date()): number {
  const lagos = new Date(date.toLocaleString("en-US", { timeZone: "Africa/Lagos" }));
  return Math.floor(Date.UTC(lagos.getFullYear(), lagos.getMonth(), lagos.getDate()) / 86_400_000);
}

function posterForSlot(slot: Exclude<Slot, "auto" | "manual">, date = new Date()): BotDef {
  const slotOffset = slot === "morning" ? 0 : slot === "afternoon" ? 1 : 2;
  const index = (lagosDayNumber(date) * 3 + slotOffset) % ROTATION_ORDER.length;
  const name = ROTATION_ORDER[index];
  const bot = BOTS.find((b) => b.name === name);
  if (!bot) throw new Error(`Poster not configured: ${name}`);
  return bot;
}

function naturalLikeTarget(postId: string): number {
  // Stable 6 or 7 per post so boost passes do not keep adding likes.
  let hash = 0;
  for (let i = 0; i < postId.length; i++) hash = (hash * 31 + postId.charCodeAt(i)) >>> 0;
  return LIKE_TARGET_MIN + (hash % (LIKE_TARGET_MAX - LIKE_TARGET_MIN + 1));
}

function staggeredLikeTimes(postCreatedAt: string, count: number): string[] {
  const base = new Date(postCreatedAt).getTime();
  const times: number[] = [];
  let cursor = base + randomInt(4, 11) * 60_000;
  for (let i = 0; i < count; i++) {
    times.push(cursor);
    cursor += randomInt(5, 18) * 60_000;
  }
  return times.map((t) => new Date(t).toISOString());
}

function isAuthorized(req: Request): boolean {
  const auth = req.headers.get("authorization") ?? "";
  if (auth === `Bearer ${SERVICE_KEY}`) return true;
  const cronHeader = req.headers.get("x-cron-secret") ?? "";
  if (CRON_SECRET && cronHeader === CRON_SECRET) return true;
  return false;
}

async function loadUsedKeys(
  db: ReturnType<typeof createClient>,
  userId: string,
): Promise<Set<string>> {
  const used = new Set<string>();

  const { data: logs } = await db
    .from("victory_wall_bot_log")
    .select("content_key, content")
    .eq("bot_user_id", userId)
    .order("created_at", { ascending: false })
    .limit(200);

  for (const row of logs ?? []) {
    if (row.content_key) used.add(row.content_key as string);
    if (row.content) used.add(contentKey(row.content as string));
  }

  const { data: posts } = await db
    .from("posts")
    .select("content")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(100);

  for (const row of posts ?? []) {
    if (row.content) used.add(contentKey(row.content as string));
  }

  return used;
}

async function pickFreshContent(
  db: ReturnType<typeof createClient>,
  persona: Persona,
  userId: string,
): Promise<{ text: string; key: string }> {
  const pool = CONTENT[persona];
  const used = await loadUsedKeys(db, userId);

  let candidates = pool.filter((line) => !used.has(contentKey(line)));

  // Pool exhausted for this persona — allow reuse of the oldest-posted line only
  if (candidates.length === 0) {
    const { data: oldest } = await db
      .from("victory_wall_bot_log")
      .select("content_key")
      .eq("bot_user_id", userId)
      .not("content_key", "is", null)
      .order("created_at", { ascending: true })
      .limit(1);

    const oldestKey = oldest?.[0]?.content_key as string | undefined;
    candidates = pool.filter((line) => contentKey(line) !== oldestKey);
    if (candidates.length === 0) candidates = [...pool];
  }

  const base = pick(shuffle(candidates));
  const key = contentKey(base);

  const unusedHooks = MINI_COURSE_HOOKS.filter((h) => !used.has(contentKey(h)));
  const hookPool = unusedHooks.length > 0 ? unusedHooks : MINI_COURSE_HOOKS;

  const text = Math.random() < 0.3
    ? `${base} ${pick(hookPool)}`
    : base;

  return { text, key };
}

async function ensureBots(db: ReturnType<typeof createClient>) {
  const results: string[] = [];
  for (const bot of BOTS) {
    const { data: existing, error: getErr } = await db.auth.admin.getUserById(bot.id);
    if (getErr && !String(getErr.message).toLowerCase().includes("not found")) throw getErr;

    if (!existing?.user) {
      const { error: createErr } = await db.auth.admin.createUser({
        id: bot.id,
        email: bot.email,
        password: crypto.randomUUID() + "Aa1!",
        email_confirm: true,
        user_metadata: { name: bot.name, is_victory_bot: true },
      });
      if (createErr) throw createErr;
      results.push(`created auth:${bot.name}`);
    }

    const { error: profileErr } = await db.from("profiles").upsert({
      id: bot.id,
      name: bot.name,
      age: bot.age,
      xp: 180 + randomInt(0, 420),
      monthly_xp: randomInt(20, 120),
      coins: randomInt(5, 40),
      badges: [],
      interests: ["Leadership", "Goals"],
      is_premium: false,
      is_bot: true,
      weekly_reports_enabled: false,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });
    if (profileErr) throw profileErr;
    results.push(`profile:${bot.name}`);
  }
  return results;
}

async function applyBotLikes(
  db: ReturnType<typeof createClient>,
  postId: string,
  excludeUserId: string,
  postCreatedAt: string,
  batchSize?: number,
): Promise<number> {
  const { data: existingLikes } = await db
    .from("post_likes")
    .select("user_id")
    .eq("post_id", postId)
    .in("user_id", [...BOT_USER_IDS]);

  const existingBotLikers = new Set((existingLikes ?? []).map((l) => l.user_id as string));
  const target = naturalLikeTarget(postId);
  const needed = Math.max(0, target - existingBotLikers.size);
  if (needed === 0) return 0;

  const toAddNow = batchSize == null ? needed : Math.min(needed, batchSize);
  const likers = shuffle(
    BOTS.filter((b) => b.id !== excludeUserId && !existingBotLikers.has(b.id)),
  ).slice(0, toAddNow);

  const likeTimes = staggeredLikeTimes(postCreatedAt, likers.length);
  let added = 0;
  for (let i = 0; i < likers.length; i++) {
    const { error: likeErr } = await db.from("post_likes").insert({
      post_id: postId,
      user_id: likers[i].id,
      created_at: likeTimes[i],
    });
    if (!likeErr) added++;
    else if (!likeErr.message.includes("duplicate")) {
      console.warn("like failed", likers[i].name, likeErr.message);
    }
  }
  return added;
}

async function boostUserPosts(
  db: ReturnType<typeof createClient>,
  userId: string,
): Promise<Array<{ postId: string; added: number; totalBotLikes: number }>> {
  const since = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();
  const { data: posts, error } = await db
    .from("posts")
    .select("id, user_id, created_at")
    .eq("user_id", userId)
    .gte("created_at", since)
    .order("created_at", { ascending: false })
    .limit(25);

  if (error) throw error;

  const results: Array<{ postId: string; added: number; totalBotLikes: number }> = [];
  for (const post of posts ?? []) {
    // Drip 1–2 likes per boost pass so marketer posts fill in gradually.
    const added = await applyBotLikes(
      db,
      post.id as string,
      userId,
      post.created_at as string,
      randomInt(1, 2),
    );
    if (added === 0) continue;

    const { count } = await db
      .from("post_likes")
      .select("id", { count: "exact", head: true })
      .eq("post_id", post.id)
      .in("user_id", [...BOT_USER_IDS]);

    results.push({
      postId: post.id as string,
      added,
      totalBotLikes: count ?? added,
    });
  }
  return results;
}

async function dripRecentBotPostLikes(db: ReturnType<typeof createClient>) {
  const since = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();
  const { data: logs } = await db
    .from("victory_wall_bot_log")
    .select("post_id, bot_user_id, created_at")
    .gte("created_at", since)
    .not("post_id", "is", null)
    .order("created_at", { ascending: false })
    .limit(6);

  const touched: string[] = [];
  for (const log of logs ?? []) {
    if (!log.post_id) continue;
    const added = await applyBotLikes(
      db,
      log.post_id as string,
      log.bot_user_id as string,
      log.created_at as string,
      randomInt(1, 2),
    );
    if (added > 0) touched.push(log.post_id as string);
  }
  return touched;
}

async function boostAllConfiguredUsers(db: ReturnType<typeof createClient>) {
  const summary: Record<string, unknown> = {};
  for (const userId of BOOSTED_USER_IDS) {
    const { data: profile } = await db.from("profiles").select("name").eq("id", userId).maybeSingle();
    summary[userId] = {
      name: profile?.name ?? userId,
      posts: await boostUserPosts(db, userId),
    };
  }
  return summary;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
      },
    });
  }

  if (!isAuthorized(req)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

  try {
    const body = await req.json().catch(() => ({}));
    const action = (body.action as string) ?? "run";

    if (action === "setup") {
      const setup = await ensureBots(db);
      return new Response(JSON.stringify({ ok: true, setup }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    if (action === "boost") {
      const dripped = await dripRecentBotPostLikes(db);
      const boosted = await boostAllConfiguredUsers(db);
      return new Response(JSON.stringify({ ok: true, dripped, boosted }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    await ensureBots(db);

    const slot = resolveSlot((body.slot as Slot) ?? "auto");
    const poster = posterForSlot(slot);

    const { data: slotFilled } = await db.rpc("victory_wall_bot_slot_filled_today", {
      p_slot: slot,
    });

    if (slotFilled && body.force !== true) {
      return new Response(JSON.stringify({
        ok: true, skipped: true, reason: "slot_filled_today", slot, poster: poster.name,
      }), { headers: { "Content-Type": "application/json" } });
    }

    const { text: content, key: content_key } = await pickFreshContent(
      db,
      poster.persona,
      poster.id,
    );

    const postId = crypto.randomUUID();
    const createdAt = new Date(Date.now() - randomInt(2, 38) * 60 * 1000).toISOString();

    const { error: postErr } = await db.from("posts").insert({
      id: postId,
      user_id: poster.id,
      content,
      created_at: createdAt,
      post_type: "user",
    });
    if (postErr) throw postErr;

    const likes = await applyBotLikes(db, postId, poster.id, createdAt, randomInt(2, 3));

    await db.from("victory_wall_bot_log").insert({
      bot_user_id: poster.id,
      post_id: postId,
      slot,
      content,
      content_key,
      content_preview: content.slice(0, 120),
      like_count: likes,
    });

    const boosted = await boostAllConfiguredUsers(db);

    return new Response(JSON.stringify({
      ok: true, slot, poster: poster.name, postId, content, content_key, likes, boosted,
    }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    console.error("victory-wall-bots error", e);
    return new Response(JSON.stringify({ ok: false, error: (e as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

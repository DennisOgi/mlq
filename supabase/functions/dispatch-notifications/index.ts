import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT_B64 = Deno.env.get("FCM_SERVICE_ACCOUNT_B64");

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const MAX_PUSH_PER_DAY = 2;
const MIN_GAP_MINUTES = 240;
const QUIET_START = 21;
const QUIET_END = 8;

const FCM_PROJECT_ID = "mylearning-83b49";
const FCM_ENDPOINT = `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;

async function getAccessToken(): Promise<string> {
  if (!FCM_SERVICE_ACCOUNT_B64) {
    throw new Error("FCM_SERVICE_ACCOUNT_B64 not configured");
  }

  const decoded = atob(FCM_SERVICE_ACCOUNT_B64);
  const serviceAccount = JSON.parse(decoded);

  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signatureInput = `${encodedHeader}.${encodedPayload}`;

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(signatureInput),
  );

  const jwt = `${signatureInput}.${base64UrlEncode(signature)}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const error = await tokenResponse.text();
    throw new Error(`OAuth2 token error: ${error}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function base64UrlEncode(data: string | ArrayBuffer): string {
  let base64: string;
  if (typeof data === "string") {
    base64 = btoa(data);
  } else {
    const bytes = new Uint8Array(data);
    base64 = btoa(String.fromCharCode(...bytes));
  }
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function inQuietHours(tz: string | null, nowUtc: Date): Promise<boolean> {
  try {
    if (!tz) return false;
    const fmt = new Intl.DateTimeFormat("en-GB", {
      hour: "2-digit",
      hour12: false,
      timeZone: tz,
    });
    const parts = fmt.formatToParts(nowUtc);
    const hourStr = parts.find((p) => p.type === "hour")?.value ?? "0";
    const hour = parseInt(hourStr, 10);
    if (Number.isNaN(hour)) return false;
    return hour >= QUIET_START || hour < QUIET_END;
  } catch {
    return false;
  }
}

async function lastSentAt(userId: string): Promise<Date | null> {
  const { data, error } = await supabase
    .from("notification_logs")
    .select("created_at")
    .eq("user_id", userId)
    .eq("response_code", 200)
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) throw error;
  if (!data || data.length === 0) return null;
  return new Date(data[0].created_at);
}

async function pushesTodayCount(userId: string): Promise<number> {
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error } = await supabase
    .from("notification_logs")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("response_code", 200)
    .gte("created_at", since);

  if (error) throw error;
  return count ?? 0;
}

async function clearStaleToken(userId: string): Promise<void> {
  try {
    await supabase
      .from("profiles")
      .update({ fcm_token: null, updated_at: new Date().toISOString() })
      .eq("id", userId);
    console.log(`[dispatch-notifications] Cleared stale FCM token for user ${userId}`);
  } catch (e) {
    console.error(`[dispatch-notifications] Failed to clear stale token: ${e}`);
  }
}

async function sendFcmV1(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
): Promise<{ success: boolean; responseId?: string; errorCode?: string }> {
  const message = {
    message: {
      token,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: {
          channel_id: "mlq_high_importance",
          sound: "default",
        },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default" } },
      },
    },
  };

  const response = await fetch(FCM_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(message),
  });

  const responseText = await response.text();

  if (!response.ok) {
    try {
      const errorData = JSON.parse(responseText);
      const errorCode = errorData?.error?.details?.[0]?.errorCode;
      return { success: false, errorCode: errorCode || "UNKNOWN" };
    } catch {
      return { success: false, errorCode: "PARSE_ERROR" };
    }
  }

  const result = JSON.parse(responseText);
  return { success: true, responseId: result.name || "sent" };
}

function buildTitle(type: string, payload: Record<string, unknown>): string {
  switch (type) {
    case "system":
      return (payload?.title as string) || "📬 My Leadership Quest";
    case "achievement":
      return "🏆 Achievement Unlocked!";
    case "badge_earned":
      return "🎖️ New Badge Earned!";
    case "challenge":
      return payload?.title ? `⚡ ${payload.title}` : "⚡ Challenge Update";
    case "goal_reminder":
      return "📝 Daily Goal Reminder";
    case "streak_warning":
      return "🔥 Don't Break Your Streak!";
    case "leaderboard":
      return (payload?.title as string) || "🏅 Leaderboard Update";
    case "wallet_reward":
      return (payload?.title as string) || "LeadWallet Reward Credited!";
    case "reengagement":
      return "👋 We Miss You!";
    case "progress_win":
      return "🎉 Progress Milestone!";
    case "coach_tip":
      return "💡 Tip from Questor";
    default:
      return (payload?.title as string) || "📬 My Leadership Quest";
  }
}

function buildBody(type: string, payload: Record<string, unknown>): string {
  switch (type) {
    case "system":
    case "leaderboard":
    case "wallet_reward":
      return (payload?.message as string) || "Tap to open the app";
    case "achievement":
      return payload?.goal_title
        ? `Great job completing: ${payload.goal_title}! +${payload.xp_earned || 10} XP`
        : "Great job on your achievement!";
    case "badge_earned":
      return payload?.badge_name
        ? `You earned: ${payload.badge_name}!`
        : "Great job on your achievement!";
    case "challenge":
      return (payload?.message as string) || "Check out the latest challenge!";
    case "goal_reminder":
      return "Don't forget to set and complete your daily goals!";
    case "streak_warning":
      return "Complete a goal today to keep your streak alive!";
    case "reengagement":
      return "Come back and continue your leadership journey!";
    case "progress_win":
      return (payload?.message as string) || "You're making amazing progress!";
    case "coach_tip":
      return (payload?.message as string) || "Tap to see your personalized tip";
    default:
      return (payload?.message as string) || "Tap to open the app";
  }
}

Deno.serve(async (_req) => {
  try {
    console.log("[dispatch-notifications] Starting batch processing...");

    const accessToken = await getAccessToken();

    const nowIso = new Date().toISOString();

    // Priority wallet rewards first so they are not stuck behind the backlog.
    const { data: priorityRows, error: priorityError } = await supabase
      .from("notification_queue")
      .select("*")
      .eq("status", "pending")
      .eq("type", "wallet_reward")
      .lte("scheduled_for", nowIso)
      .order("scheduled_for", { ascending: true })
      .limit(50);

    if (priorityError) throw priorityError;

    let rows = priorityRows ?? [];
    if (rows.length < 50) {
      const { data: normalRows, error } = await supabase
        .from("notification_queue")
        .select("*")
        .eq("status", "pending")
        .neq("type", "wallet_reward")
        .lte("scheduled_for", nowIso)
        .order("scheduled_for", { ascending: true })
        .limit(50 - rows.length);

      if (error) throw error;
      rows = [...rows, ...(normalRows ?? [])];
    }

    console.log(`[dispatch-notifications] Found ${rows?.length || 0} pending notifications`);

    const results: Record<string, unknown>[] = [];
    let sentCount = 0;
    let skippedCount = 0;
    let failedCount = 0;
    let clearedTokens = 0;

    for (const row of rows ?? []) {
      try {
        const userId = row.user_id;
        const payload = (row.payload ?? {}) as Record<string, unknown>;
        const isPriority =
          row.type === "wallet_reward" || payload.priority === true;

        const { data: profiles, error: pErr } = await supabase
          .from("profiles")
          .select("id, fcm_token, timezone")
          .eq("id", userId)
          .limit(1);

        if (pErr) throw pErr;

        const profile = profiles?.[0];
        if (!profile?.fcm_token) {
          await supabase
            .from("notification_queue")
            .update({
              status: "skipped",
              attempts: row.attempts + 1,
              updated_at: new Date().toISOString(),
            })
            .eq("id", row.id);
          results.push({ id: row.id, status: "skipped", reason: "no_fcm_token" });
          skippedCount++;
          continue;
        }

        // Reward credits always deliver; skip quiet hours / daily caps / gaps.
        if (!isPriority) {
          const inQuiet = await inQuietHours(profile.timezone ?? null, new Date());
          if (inQuiet) {
            const postpone = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
            await supabase
              .from("notification_queue")
              .update({ scheduled_for: postpone })
              .eq("id", row.id);
            results.push({ id: row.id, status: "postponed_quiet_hours" });
            continue;
          }

          const sentToday = await pushesTodayCount(userId);
          if (sentToday >= MAX_PUSH_PER_DAY) {
            const tomorrow = new Date();
            tomorrow.setUTCHours(24, 0, 0, 0);
            await supabase
              .from("notification_queue")
              .update({ scheduled_for: tomorrow.toISOString() })
              .eq("id", row.id);
            results.push({ id: row.id, status: "postponed_daily_cap" });
            continue;
          }

          const last = await lastSentAt(userId);
          if (last) {
            const minutesSince = (Date.now() - last.getTime()) / 60000;
            if (minutesSince < MIN_GAP_MINUTES) {
              const postpone = new Date(
                last.getTime() + MIN_GAP_MINUTES * 60000 + 1000,
              ).toISOString();
              await supabase
                .from("notification_queue")
                .update({ scheduled_for: postpone })
                .eq("id", row.id);
              results.push({ id: row.id, status: "postponed_gap" });
              continue;
            }
          }
        }

        const title = buildTitle(row.type, payload);
        const body = buildBody(row.type, payload);
        const dataPayload = {
          type: row.type,
          related_id: String(payload?.related_id ?? ""),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        };

        const fcmResult = await sendFcmV1(
          profile.fcm_token,
          title,
          body,
          dataPayload,
          accessToken,
        );

        if (fcmResult.success) {
          await supabase
            .from("notification_queue")
            .update({
              status: "sent",
              attempts: row.attempts + 1,
              updated_at: new Date().toISOString(),
            })
            .eq("id", row.id);

          await supabase.from("notification_logs").insert({
            queue_id: row.id,
            user_id: userId,
            provider: "fcm_v1",
            response_code: 200,
            response_id: fcmResult.responseId,
          });

          // Skip duplicate in-app row when admin RPC already inserted notifications
          if (payload.in_app_created !== true) {
            await supabase.from("notifications").insert({
              user_id: userId,
              title,
              message: body,
              type: row.type === "wallet_reward" ? "system" : row.type,
              related_id: payload?.related_id || null,
              is_read: false,
            });
          }

          results.push({ id: row.id, status: "sent" });
          sentCount++;
        } else {
          const errorCode = fcmResult.errorCode;

          if (errorCode === "UNREGISTERED" || errorCode === "INVALID_ARGUMENT") {
            await clearStaleToken(userId);
            clearedTokens++;
          }

          await supabase
            .from("notification_queue")
            .update({
              status: "failed",
              attempts: (row.attempts ?? 0) + 1,
              updated_at: new Date().toISOString(),
            })
            .eq("id", row.id);

          await supabase.from("notification_logs").insert({
            queue_id: row.id,
            user_id: userId,
            provider: "fcm_v1",
            response_code: 500,
            error: `FCM error: ${errorCode}`,
          });

          results.push({ id: row.id, status: "failed", error: errorCode });
          failedCount++;
        }
      } catch (inner) {
        console.error(`[dispatch-notifications] Error processing ${row.id}:`, inner);
        await supabase
          .from("notification_queue")
          .update({
            status: "failed",
            attempts: (row.attempts ?? 0) + 1,
            updated_at: new Date().toISOString(),
          })
          .eq("id", row.id);

        await supabase.from("notification_logs").insert({
          queue_id: row.id,
          user_id: row.user_id,
          provider: "fcm_v1",
          response_code: 500,
          error: String(inner),
        });

        results.push({ id: row.id, status: "failed", error: String(inner) });
        failedCount++;
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        processed: results.length,
        sent: sentCount,
        skipped: skippedCount,
        failed: failedCount,
        cleared_tokens: clearedTokens,
        results,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("[dispatch-notifications] Fatal error:", e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

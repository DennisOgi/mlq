// Reconcile stuck subscription/coin payment_attempts against Flutterwave.
// Finds successful charges by tx_ref and fulfills them.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const FLW_SECRET_KEY = Deno.env.get("FLW_SECRET_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

async function requireAdminOrService(req: Request): Promise<boolean> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return false;
  const token = auth.slice(7);
  if (token === SUPABASE_SERVICE_ROLE_KEY) return true;

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userData } = await userClient.auth.getUser();
  if (!userData.user) return false;

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: isAdmin } = await admin
    .from("admin_users")
    .select("user_id")
    .eq("user_id", userData.user.id)
    .maybeSingle();
  return !!isAdmin;
}

async function verifyByTxRef(txRef: string) {
  const res = await fetch(
    `https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=${
      encodeURIComponent(txRef)
    }`,
    {
      method: "GET",
      headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` },
    },
  );
  const body = await res.json();
  return { ok: res.ok, body };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!FLW_SECRET_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error("missing_env");
    }
    if (!(await requireAdminOrService(req))) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const days = Math.min(Number(payload.days ?? 90), 180);
    const limit = Math.min(Number(payload.limit ?? 50), 100);
    const onlyTxRef = payload.tx_ref ? String(payload.tx_ref) : null;

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    let q = admin
      .from("payment_attempts")
      .select("*")
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(limit);

    if (onlyTxRef) {
      q = admin.from("payment_attempts").select("*").eq("tx_ref", onlyTxRef)
        .limit(1);
    } else {
      const since = new Date(Date.now() - days * 86400000).toISOString();
      q = q.gte("created_at", since);
    }

    const { data: attempts, error } = await q;
    if (error) throw error;

    const results: Array<Record<string, unknown>> = [];

    for (const attempt of attempts ?? []) {
      const txRef = String(attempt.tx_ref);
      const { ok, body } = await verifyByTxRef(txRef);
      const flwStatus = String(body?.data?.status ?? "").toLowerCase();
      const flwId = body?.data?.id != null ? String(body.data.id) : null;
      const flwAmount = Number(body?.data?.amount ?? 0);

      if (!ok || flwStatus !== "successful" || !flwId) {
        results.push({
          tx_ref: txRef,
          action: "skip",
          reason: !ok
            ? (body?.message ?? "flw_lookup_failed")
            : `status=${flwStatus || "unknown"}`,
        });
        continue;
      }

      if (Math.abs(flwAmount - Number(attempt.amount)) > 0.01) {
        results.push({
          tx_ref: txRef,
          action: "skip",
          reason: `amount_mismatch expected=${attempt.amount} got=${flwAmount}`,
        });
        continue;
      }

      const meta = (attempt.metadata ?? {}) as Record<string, unknown>;
      const isSubscription = meta.subscription === true || !!meta.plan_id;

      if (isSubscription) {
        const { data: fulfillResult, error: fulfillError } = await admin.rpc(
          "fulfill_subscription_from_attempt",
          { p_tx_ref: txRef, p_transaction_id: flwId },
        );
        results.push({
          tx_ref: txRef,
          action: fulfillError ? "error" : "fulfilled_subscription",
          flw_id: flwId,
          error: fulfillError?.message,
          result: fulfillResult,
        });
        continue;
      }

      const coins = Number(attempt.coins) || 0;
      if (coins > 0) {
        const { error: coinsError } = await admin.rpc("add_coins", {
          p_user_id: attempt.user_id,
          p_amount: coins,
          p_description: "Coin purchase",
          p_transaction_type: "purchase",
          p_reference_type: "payment",
          p_reference_id: txRef,
        });
        if (!coinsError) {
          await admin.rpc("update_payment_attempt_status", {
            p_tx_ref: txRef,
            p_status: "completed",
            p_transaction_id: flwId,
            p_event_data: { coins_credited: coins, source: "reconcile" },
          });
        }
        results.push({
          tx_ref: txRef,
          action: coinsError ? "error" : "fulfilled_coins",
          flw_id: flwId,
          error: coinsError?.message,
        });
        continue;
      }

      results.push({ tx_ref: txRef, action: "skip", reason: "unknown_type" });
    }

    const fulfilled = results.filter((r) =>
      String(r.action).startsWith("fulfilled")
    ).length;

    return new Response(
      JSON.stringify({
        success: true,
        scanned: attempts?.length ?? 0,
        fulfilled,
        results,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ success: false, error: String(e) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

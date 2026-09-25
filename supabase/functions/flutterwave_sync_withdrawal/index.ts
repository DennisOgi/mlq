// ============================================================================
// Flutterwave Sync Withdrawal Edge Function
// ============================================================================
// Polls Flutterwave transfer status for a stuck `processing` withdrawal and
// finalizes it (paid + ledger debit, or failed). Admin-only.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function isFlutterwaveSandbox(secretKey: string): boolean {
  return secretKey.includes("TEST") || secretKey.includes("test");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const FLW_SECRET_KEY = Deno.env.get("FLW_SECRET_KEY");
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

    if (!FLW_SECRET_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
      throw new Error("Required environment variables not configured");
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: adminRow } = await userClient
      .from("admin_users")
      .select("user_id")
      .eq("user_id", userData.user.id)
      .maybeSingle();
    if (!adminRow) {
      return new Response(JSON.stringify({ success: false, error: "Admin access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const withdrawalId = body.withdrawal_id as string | undefined;
    if (!withdrawalId) throw new Error("withdrawal_id is required");

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: withdrawal, error: fetchError } = await supabase
      .from("withdrawal_requests")
      .select("*")
      .eq("id", withdrawalId)
      .maybeSingle();

    if (fetchError || !withdrawal) {
      throw new Error("Withdrawal not found");
    }

    if (withdrawal.status === "paid" || withdrawal.status === "failed") {
      return new Response(
        JSON.stringify({
          success: true,
          already_final: true,
          status: withdrawal.status,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
      );
    }

    if (withdrawal.status !== "processing" && withdrawal.status !== "approved") {
      throw new Error(`Cannot sync withdrawal in status: ${withdrawal.status}`);
    }

    const transferId = withdrawal.flutterwave_transfer_id;
    if (!transferId) {
      throw new Error("No Flutterwave transfer id on this withdrawal yet");
    }

    // Simulated sandbox transfers never hit Flutterwave — treat as paid.
    if (String(transferId).startsWith("SIM-")) {
      await finalizePaid(supabase, withdrawal, transferId, {
        synced: true,
        simulated: true,
        synced_by: userData.user.id,
      });
      return new Response(
        JSON.stringify({ success: true, status: "paid", transfer_id: transferId, simulated: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
      );
    }

    console.log(
      `🔄 [Flutterwave] Syncing transfer ${transferId} for withdrawal ${withdrawalId} (sandbox=${isFlutterwaveSandbox(FLW_SECRET_KEY)})`,
    );

    const transferResponse = await fetch(
      `https://api.flutterwave.com/v3/transfers/${transferId}`,
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${FLW_SECRET_KEY}`,
          "Content-Type": "application/json",
        },
      },
    );
    const transferData = await transferResponse.json();

    if (transferResponse.status !== 200 || transferData.status !== "success") {
      throw new Error(transferData.message || "Failed to fetch transfer status from Flutterwave");
    }

    const flwStatus = String(transferData.data?.status ?? "").toUpperCase();
    const completeMessage = transferData.data?.complete_message
      ? String(transferData.data.complete_message)
      : undefined;

    if (flwStatus === "SUCCESSFUL") {
      await finalizePaid(supabase, withdrawal, String(transferId), {
        synced: true,
        synced_by: userData.user.id,
        transfer_status: transferData.data,
      });
      return new Response(
        JSON.stringify({ success: true, status: "paid", transfer_id: transferId, flutterwave_status: flwStatus }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
      );
    }

    if (flwStatus === "FAILED") {
      await finalizeFailed(
        supabase,
        withdrawal,
        completeMessage || "Transfer failed (synced from Flutterwave)",
        {
          synced: true,
          synced_by: userData.user.id,
          transfer_status: transferData.data,
        },
      );
      return new Response(
        JSON.stringify({
          success: true,
          status: "failed",
          transfer_id: transferId,
          flutterwave_status: flwStatus,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
      );
    }

    // NEW / PENDING / etc. — still in flight
    await supabase
      .from("withdrawal_requests")
      .update({
        metadata: {
          ...(withdrawal.metadata as Record<string, unknown> | null) ?? {},
          last_sync_at: new Date().toISOString(),
          last_sync_status: flwStatus,
          last_sync_by: userData.user.id,
          transfer_status: transferData.data,
        },
        updated_at: new Date().toISOString(),
      })
      .eq("id", withdrawalId);

    return new Response(
      JSON.stringify({
        success: true,
        status: "processing",
        transfer_id: transferId,
        flutterwave_status: flwStatus,
        message: `Flutterwave still reports ${flwStatus}. Try again later, or Mark Failed if this is a stale sandbox transfer.`,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
    );
  } catch (error) {
    console.error("❌ [Flutterwave] Sync error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "Sync failed",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});

async function finalizePaid(
  supabase: ReturnType<typeof createClient>,
  withdrawal: Record<string, unknown>,
  transferId: string,
  meta: Record<string, unknown>,
) {
  const amountNaira = (withdrawal.amount_kobo as number) / 100;
  const { data: existingTx } = await supabase
    .from("wallet_transactions")
    .select("id")
    .eq("reference_type", "withdrawal")
    .eq("reference_id", withdrawal.id)
    .eq("type", "payout")
    .maybeSingle();

  if (!existingTx) {
    const { error: debitError } = await supabase.rpc("debit_wallet", {
      p_user_id: withdrawal.student_id,
      p_amount: amountNaira,
      p_description: `Withdrawal completed: ${withdrawal.flutterwave_reference}`,
      p_type: "payout",
      p_reference_type: "withdrawal",
      p_reference_id: withdrawal.id,
    });
    if (debitError) {
      throw new Error(`Wallet debit failed: ${debitError.message}`);
    }
  }

  const { error: updateError } = await supabase
    .from("withdrawal_requests")
    .update({
      status: "paid",
      failure_reason: null,
      flutterwave_transfer_id: transferId,
      metadata: {
        ...(withdrawal.metadata as Record<string, unknown> | null) ?? {},
        ...meta,
        completed_at: new Date().toISOString(),
      },
      updated_at: new Date().toISOString(),
    })
    .eq("id", withdrawal.id);

  if (updateError) {
    throw new Error(`Failed to mark paid: ${updateError.message}`);
  }
}

async function finalizeFailed(
  supabase: ReturnType<typeof createClient>,
  withdrawal: Record<string, unknown>,
  reason: string,
  meta: Record<string, unknown>,
) {
  const { error: updateError } = await supabase
    .from("withdrawal_requests")
    .update({
      status: "failed",
      failure_reason: reason,
      metadata: {
        ...(withdrawal.metadata as Record<string, unknown> | null) ?? {},
        ...meta,
        failed_at: new Date().toISOString(),
      },
      updated_at: new Date().toISOString(),
    })
    .eq("id", withdrawal.id);

  if (updateError) {
    throw new Error(`Failed to mark failed: ${updateError.message}`);
  }
}

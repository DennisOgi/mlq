// ============================================================================
// Flutterwave Webhook Edge Function
// ============================================================================
// Handles:
// 1) Transfer status updates (LeadWallet withdrawals)
// 2) Successful charge events (subscription / coin payment backup fulfillment)
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type TransferPayload = {
  id: string | number;
  reference: string;
  status: string;
  amount: number;
  currency?: string;
  complete_message?: string;
};

type ChargePayload = {
  id: string | number;
  tx_ref: string;
  status: string;
  amount: number;
  currency?: string;
};

function parseTransferWebhook(
  payload: Record<string, unknown>,
): TransferPayload | null {
  const v3EventType = payload["event.type"] ?? payload["event_type"];
  if (
    v3EventType === "Transfer" && payload.transfer &&
    typeof payload.transfer === "object"
  ) {
    const transfer = payload.transfer as Record<string, unknown>;
    return {
      id: transfer.id as string | number,
      reference: String(transfer.reference ?? ""),
      status: String(transfer.status ?? ""),
      amount: Number(transfer.amount ?? 0),
      currency: transfer.currency ? String(transfer.currency) : undefined,
      complete_message: transfer.complete_message
        ? String(transfer.complete_message)
        : undefined,
    };
  }

  const legacyEvent = payload.event;
  if (
    (legacyEvent === "transfer.completed" ||
      (typeof legacyEvent === "string" &&
        legacyEvent.toLowerCase().includes("transfer"))) &&
    payload.data &&
    typeof payload.data === "object"
  ) {
    const data = payload.data as Record<string, unknown>;
    return {
      id: data.id as string | number,
      reference: String(data.reference ?? ""),
      status: String(data.status ?? ""),
      amount: Number(data.amount ?? 0),
      currency: data.currency ? String(data.currency) : undefined,
      complete_message: data.complete_message
        ? String(data.complete_message)
        : undefined,
    };
  }

  return null;
}

type RefundPayload = {
  id: string | number;
  tx_ref: string;
  status: string;
  amount: number;
};

function parseRefundWebhook(
  payload: Record<string, unknown>,
): RefundPayload | null {
  const event = String(
    payload.event ?? payload["event.type"] ?? payload["event_type"] ?? "",
  ).toLowerCase();

  const looksLikeRefund = event.includes("refund") ||
    event.includes("chargeback") ||
    event.includes("dispute");

  if (!looksLikeRefund) return null;

  const data = (payload.data && typeof payload.data === "object")
    ? payload.data as Record<string, unknown>
    : null;

  if (!data) return null;

  const status = String(data.status ?? "").toLowerCase();
  const id = data.id as string | number;
  const txRef = String(
    data.tx_ref ?? data.txRef ?? data.flw_ref ?? data.flwRef ?? "",
  );
  const nestedId = data.transaction_id ?? data.tx_id;
  const transactionId = nestedId != null ? nestedId : id;

  return {
    id: transactionId as string | number,
    tx_ref: txRef,
    status,
    amount: Number(data.amount ?? 0),
  };
}

function parseChargeWebhook(
  payload: Record<string, unknown>,
): ChargePayload | null {
  const event = String(
    payload.event ?? payload["event.type"] ?? payload["event_type"] ?? "",
  ).toLowerCase();

  if (
    event.includes("refund") || event.includes("chargeback") ||
    event.includes("dispute") || event.includes("transfer")
  ) {
    return null;
  }

  const looksLikeCharge = event.includes("charge") ||
    event === "card.successful" ||
    event.includes("payment") ||
    event.includes("card") ||
    event.includes("bank") ||
    // Some Flutterwave dashboards send empty/legacy event labels.
    event === "" ||
    event === "unknown";

  const data = (payload.data && typeof payload.data === "object")
    ? payload.data as Record<string, unknown>
    : null;

  if (!data) return null;

  const txRef = String(data.tx_ref ?? data.txRef ?? "");
  const status = String(data.status ?? "").toLowerCase();
  const id = (data.id ?? data.transaction_id ?? data.flw_ref) as
    | string
    | number;

  if (!txRef || id == null || String(id).length === 0) return null;

  // Only act on successful charges; ignore failures/pending here.
  if (!looksLikeCharge && status !== "successful" && status !== "success") {
    return null;
  }
  if (status && status !== "successful" && status !== "success") return null;

  return {
    id,
    tx_ref: txRef,
    status: status || "successful",
    amount: Number(data.amount ?? 0),
    currency: data.currency ? String(data.currency) : undefined,
  };
}

serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, verif-hash",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const FLW_SECRET_HASH = (Deno.env.get("FLW_SECRET_HASH") ?? "").trim();
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const FLW_SECRET_KEY = Deno.env.get("FLW_SECRET_KEY");

    if (!FLW_SECRET_HASH || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error("Required environment variables not configured");
    }

    const signature = (req.headers.get("verif-hash") ?? "").trim();
    if (!signature || signature !== FLW_SECRET_HASH) {
      console.error("❌ [Webhook] Invalid signature");
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = await req.json();
    console.log("📨 [Webhook] Received:", JSON.stringify(payload, null, 2));

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Refund / chargeback → revoke subscription entitlement ────────────
    const refund = parseRefundWebhook(payload);
    if (refund) {
      console.log(
        `↩️ [Webhook] Refund/chargeback ${refund.id} tx_ref=${refund.tx_ref}`,
      );
      const { data: revokeResult, error: revokeError } = await supabase.rpc(
        "revoke_subscription_from_payment",
        {
          p_transaction_id: String(refund.id),
          p_tx_ref: refund.tx_ref || null,
          p_reason: "refund_or_chargeback",
        },
      );
      if (revokeError) {
        console.error("❌ [Webhook] Refund revoke failed:", revokeError);
        return new Response("Revoke failed", { status: 500 });
      }
      console.log("✅ [Webhook] Subscription revoke result", revokeResult);
      return new Response(
        JSON.stringify({ success: true, type: "refund_revoke", revokeResult }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ── Charge / subscription backup fulfillment ─────────────────────────
    const charge = parseChargeWebhook(payload);
    if (charge) {
      console.log(`💳 [Webhook] Charge ${charge.id}: ${charge.tx_ref}`);

      const { data: attempt } = await supabase
        .from("payment_attempts")
        .select("*")
        .eq("tx_ref", charge.tx_ref)
        .maybeSingle();

      if (!attempt) {
        console.log("ℹ️ [Webhook] No payment_attempt for tx_ref; ignoring charge");
        return new Response("OK", { status: 200, headers: corsHeaders });
      }

      if (attempt.status === "completed") {
        return new Response("OK (already completed)", {
          status: 200,
          headers: corsHeaders,
        });
      }

      // Re-verify with Flutterwave before fulfilling
      if (FLW_SECRET_KEY) {
        const verifyRes = await fetch(
          `https://api.flutterwave.com/v3/transactions/${charge.id}/verify`,
          {
            method: "GET",
            headers: { Authorization: `Bearer ${FLW_SECRET_KEY}` },
          },
        );
        if (!verifyRes.ok) {
          console.error("❌ [Webhook] Flutterwave verify failed", verifyRes.status);
          return new Response("Verify failed", { status: 400 });
        }
        const verifyJson = await verifyRes.json();
        const txStatus = String(verifyJson?.data?.status ?? "").toLowerCase();
        if (txStatus !== "successful") {
          console.log(`ℹ️ [Webhook] Charge not successful yet: ${txStatus}`);
          return new Response("OK", { status: 200, headers: corsHeaders });
        }
        const verifiedAmount = Number(verifyJson?.data?.amount ?? 0);
        if (Math.abs(verifiedAmount - Number(attempt.amount)) > 0.01) {
          console.error("❌ [Webhook] Charge amount mismatch");
          return new Response("Amount mismatch", { status: 400 });
        }
      }

      const meta = (attempt.metadata ?? {}) as Record<string, unknown>;
      const isSubscription = meta.subscription === true || !!meta.plan_id;

      if (isSubscription) {
        const { data: fulfillResult, error: fulfillError } = await supabase.rpc(
          "fulfill_subscription_from_attempt",
          {
            p_tx_ref: charge.tx_ref,
            p_transaction_id: String(charge.id),
          },
        );
        if (fulfillError) {
          console.error("❌ [Webhook] Subscription fulfill failed:", fulfillError);
          return new Response("Fulfill failed", { status: 500 });
        }
        console.log("✅ [Webhook] Subscription fulfilled via webhook", fulfillResult);
        return new Response(
          JSON.stringify({ success: true, type: "subscription", fulfillResult }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      // Coin purchases
      const coins = Number(attempt.coins) || 0;
      if (coins > 0) {
        const { error: coinsError } = await supabase.rpc("add_coins", {
          p_user_id: attempt.user_id,
          p_amount: coins,
          p_description: "Coin purchase",
          p_transaction_type: "purchase",
          p_reference_type: "payment",
          p_reference_id: charge.tx_ref,
        });
        if (coinsError) {
          console.error("❌ [Webhook] Coin credit failed:", coinsError);
          return new Response("Coin credit failed", { status: 500 });
        }
        await supabase.rpc("update_payment_attempt_status", {
          p_tx_ref: charge.tx_ref,
          p_status: "completed",
          p_transaction_id: String(charge.id),
          p_event_data: { coins_credited: coins, source: "webhook" },
        });
        console.log(`✅ [Webhook] Coins credited: ${coins}`);
        return new Response(
          JSON.stringify({ success: true, type: "coins", coins }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      return new Response("OK", { status: 200, headers: corsHeaders });
    }

    // ── Transfer / withdrawal path ───────────────────────────────────────
    const transfer = parseTransferWebhook(payload);
    if (!transfer || !transfer.reference) {
      const eventLabel = payload["event.type"] ?? payload.event ??
        payload["event_type"] ?? "unknown";
      console.log(`ℹ️ [Webhook] Ignoring unrecognized event: ${eventLabel}`);
      return new Response("OK", { status: 200, headers: corsHeaders });
    }

    const transferId = transfer.id;
    const transferReference = transfer.reference;
    const transferStatus = transfer.status.toUpperCase();
    const amount = transfer.amount;

    console.log(`💸 [Webhook] Transfer ${transferId}: ${transferStatus}`);

    let withdrawal: Record<string, unknown> | null = null;
    const { data: byRef } = await supabase
      .from("withdrawal_requests")
      .select("*")
      .eq("flutterwave_reference", transferReference)
      .maybeSingle();
    withdrawal = byRef;

    if (!withdrawal && transferId != null) {
      const { data: byId } = await supabase
        .from("withdrawal_requests")
        .select("*")
        .eq("flutterwave_transfer_id", String(transferId))
        .maybeSingle();
      withdrawal = byId;
    }

    if (!withdrawal) {
      console.error(
        "❌ [Webhook] Withdrawal not found for reference:",
        transferReference,
        "transfer_id:",
        transferId,
      );
      return new Response("Withdrawal not found", { status: 404 });
    }

    const expectedAmount = Number(withdrawal.amount_kobo) / 100;
    if (amount > 0 && Math.abs(amount - expectedAmount) > 0.01) {
      console.error(
        `❌ [Webhook] Amount mismatch. Expected: ${expectedAmount}, Got: ${amount}`,
      );
      return new Response("Amount mismatch", { status: 400 });
    }

    let newStatus: string;
    let failureReason: string | null = null;

    if (transferStatus === "SUCCESSFUL") {
      newStatus = "paid";
      console.log(`✅ [Webhook] Transfer successful: ${transferId}`);
    } else if (transferStatus === "FAILED") {
      newStatus = "failed";
      failureReason = transfer.complete_message || "Transfer failed";
      console.log(`❌ [Webhook] Transfer failed: ${failureReason}`);
    } else {
      newStatus = "processing";
      console.log(`⏳ [Webhook] Transfer still processing: ${transferStatus}`);
    }

    if (withdrawal.status === "paid" || withdrawal.status === "failed") {
      console.log(
        `ℹ️ [Webhook] Withdrawal ${withdrawal.id} already ${withdrawal.status}; ignoring duplicate.`,
      );
      return new Response("OK (already processed)", {
        status: 200,
        headers: corsHeaders,
      });
    }

    const { error: updateWithdrawalError } = await supabase
      .from("withdrawal_requests")
      .update({
        status: newStatus,
        failure_reason: failureReason,
        flutterwave_transfer_id: withdrawal.flutterwave_transfer_id ??
          String(transferId),
        metadata: {
          ...((withdrawal.metadata as Record<string, unknown> | null) ?? {}),
          webhook_payload: transfer,
          webhook_received_at: new Date().toISOString(),
        },
        updated_at: new Date().toISOString(),
      })
      .eq("id", withdrawal.id);

    if (updateWithdrawalError) {
      console.error("❌ [Webhook] Error updating withdrawal:", updateWithdrawalError);
    }

    if (newStatus === "paid") {
      const amountNaira = Number(withdrawal.amount_kobo) / 100;

      const { data: existingTx } = await supabase
        .from("wallet_transactions")
        .select("id")
        .eq("reference_type", "withdrawal")
        .eq("reference_id", withdrawal.id)
        .eq("type", "payout")
        .maybeSingle();

      if (existingTx) {
        console.log(
          `ℹ️ [Webhook] Payout already debited for withdrawal ${withdrawal.id}; skipping.`,
        );
      } else {
        const { error: updateBalanceError } = await supabase.rpc("debit_wallet", {
          p_user_id: withdrawal.student_id,
          p_amount: amountNaira,
          p_description:
            `Withdrawal completed: ${transferReference || withdrawal.flutterwave_reference}`,
          p_type: "payout",
          p_reference_type: "withdrawal",
          p_reference_id: withdrawal.id,
        });

        if (updateBalanceError) {
          console.error("❌ [Webhook] Error debiting wallet:", updateBalanceError);
        } else {
          console.log(`✅ [Webhook] Wallet debited: ₦${amountNaira}`);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Webhook processed successfully",
        withdrawal_status: newStatus,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    console.error("❌ [Webhook] Error processing webhook:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "Webhook processing failed",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});

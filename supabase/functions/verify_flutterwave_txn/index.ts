import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const FLW_SECRET_KEY = Deno.env.get("FLW_SECRET_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

async function requireUser(req: Request): Promise<string | null> {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) return null;
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) return null;
  return data.user.id;
}

async function getAdminClient() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("missing_supabase_env");
  }
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
}

async function verifyWithFlutterwave(transactionId: string) {
  if (!FLW_SECRET_KEY) {
    throw new Error("FLW_SECRET_KEY not configured");
  }

  const response = await fetch(
    `https://api.flutterwave.com/v3/transactions/${transactionId}/verify`,
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${FLW_SECRET_KEY}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error(`Flutterwave API error: ${response.status}`);
  }

  return await response.json();
}

async function verifyWithFlutterwaveByRef(txRef: string) {
  if (!FLW_SECRET_KEY) {
    throw new Error("FLW_SECRET_KEY not configured");
  }

  const response = await fetch(
    `https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=${
      encodeURIComponent(txRef)
    }`,
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${FLW_SECRET_KEY}`,
      },
    },
  );

  if (!response.ok) {
    throw new Error(`Flutterwave API error: ${response.status}`);
  }

  return await response.json();
}

async function resolveFlutterwaveTxn(
  transactionId: string,
  txRef: string,
) {
  if (transactionId) {
    try {
      return await verifyWithFlutterwave(transactionId);
    } catch (e) {
      console.warn("verify by id failed, trying tx_ref:", e);
    }
  }
  if (txRef) {
    return await verifyWithFlutterwaveByRef(txRef);
  }
  throw new Error("transaction_id or tx_ref required");
}

async function processSubscription(
  admin: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
  callerUserId: string,
) {
  let transaction_id = String(payload.transaction_id ?? payload.id ?? "");
  const tx_ref = String(payload.tx_ref ?? "");
  const user_id = String(payload.user_id ?? callerUserId);

  if (!tx_ref) {
    throw new Error("tx_ref is required");
  }

  console.log(`Processing subscription: ${tx_ref}`);

  const flwData = await resolveFlutterwaveTxn(transaction_id, tx_ref);
  if (flwData.status !== "success") {
    throw new Error(`Flutterwave verification failed: ${flwData.status}`);
  }

  const txData = flwData.data;
  if (txData.status !== "successful") {
    throw new Error(`Transaction not successful: ${txData.status}`);
  }

  transaction_id = String(txData.id ?? transaction_id);
  if (!transaction_id) {
    throw new Error("Flutterwave transaction id missing");
  }

  const { data: attempt, error: attemptError } = await admin
    .from("payment_attempts")
    .select("*")
    .eq("tx_ref", tx_ref)
    .maybeSingle();

  if (attemptError) {
    console.error("Error fetching payment attempt:", attemptError);
  }

  if (attempt && attempt.status === "completed") {
    console.log("Subscription already processed:", tx_ref);
    return { success: true, idempotent: true };
  }

  if (!attempt) {
    throw new Error("payment_attempt_not_found");
  }

  if (
    attempt.user_id !== callerUserId ||
    (user_id && attempt.user_id !== user_id)
  ) {
    throw new Error("user_mismatch");
  }

  const expectedAmount = Number(attempt.amount);
  if (Math.abs(Number(txData.amount) - expectedAmount) > 0.01) {
    throw new Error(
      `Amount mismatch: expected ${expectedAmount}, got ${txData.amount}`,
    );
  }

  const { data: fulfillResult, error: fulfillError } = await admin.rpc(
    "fulfill_subscription_from_attempt",
    {
      p_tx_ref: tx_ref,
      p_transaction_id: String(transaction_id),
    },
  );

  if (fulfillError) {
    throw new Error(`Fulfillment failed: ${fulfillError.message}`);
  }

  console.log(`✅ Subscription fulfilled:`, fulfillResult);

  return {
    success: true,
    ...(fulfillResult ?? {}),
  };
}

async function processCoins(
  admin: ReturnType<typeof createClient>,
  payload: Record<string, unknown>,
  callerUserId: string,
) {
  let transaction_id = String(payload.transaction_id ?? payload.id ?? "");
  const tx_ref = String(payload.tx_ref ?? "");
  const user_id = String(payload.user_id ?? callerUserId);

  if (!tx_ref) {
    throw new Error("tx_ref is required");
  }

  console.log(`Processing coins purchase: ${tx_ref}`);

  const flwData = await resolveFlutterwaveTxn(transaction_id, tx_ref);
  if (flwData.status !== "success") {
    throw new Error(`Flutterwave verification failed: ${flwData.status}`);
  }

  const txData = flwData.data;
  if (txData.status !== "successful") {
    throw new Error(`Transaction not successful: ${txData.status}`);
  }

  transaction_id = String(txData.id ?? transaction_id);

  const { data: attempt, error: attemptError } = await admin
    .from("payment_attempts")
    .select("*")
    .eq("tx_ref", tx_ref)
    .maybeSingle();

  if (attemptError) {
    console.error("Error fetching payment attempt:", attemptError);
  }

  if (!attempt) {
    throw new Error("payment_attempt_not_found");
  }

  if (attempt.status === "completed") {
    console.log("Coins already processed:", tx_ref);
    return { success: true, idempotent: true };
  }

  if (
    attempt.user_id !== callerUserId ||
    (user_id && attempt.user_id !== user_id)
  ) {
    throw new Error("user_mismatch");
  }

  const expectedAmount = Number(attempt.amount);
  if (Math.abs(Number(txData.amount) - expectedAmount) > 0.01) {
    throw new Error(
      `Amount mismatch: expected ${expectedAmount}, got ${txData.amount}`,
    );
  }

  const coins = Number(attempt.coins) || 0;
  if (coins <= 0) {
    throw new Error("invalid_coin_amount");
  }

  const { data: result, error: coinsError } = await admin.rpc("add_coins", {
    p_user_id: attempt.user_id,
    p_amount: coins,
    p_description: "Coin purchase",
    p_transaction_type: "purchase",
    p_reference_type: "payment",
    p_reference_id: tx_ref,
  });

  if (coinsError) {
    throw new Error(`Failed to credit coins: ${coinsError.message}`);
  }

  await admin.rpc("update_payment_attempt_status", {
    p_tx_ref: tx_ref,
    p_status: "completed",
    p_transaction_id: String(transaction_id),
    p_event_data: {
      coins_credited: coins,
      source: "edge_function",
    },
  });

  console.log(`✅ Coins credited successfully: ${coins}`);

  return {
    success: true,
    coins_credited: coins,
    new_balance: result?.new_balance,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const callerUserId = await requireUser(req);
    if (!callerUserId) {
      return new Response(
        JSON.stringify({
          status: "error",
          success: false,
          error: "Unauthorized",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const payload = await req.json();
    const { type } = payload;

    console.log(`Verification request: type=${type} user=${callerUserId}`);

    const admin = await getAdminClient();

    let result;
    if (type === "subscription") {
      result = await processSubscription(admin, payload, callerUserId);
    } else if (type === "coins") {
      result = await processCoins(admin, payload, callerUserId);
    } else {
      throw new Error(`Unknown payment type: ${type}`);
    }

    return new Response(
      JSON.stringify({
        status: "ok",
        success: true,
        ...result,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    console.error("Verification error:", e);
    return new Response(
      JSON.stringify({
        status: "error",
        success: false,
        error: String(e),
      }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

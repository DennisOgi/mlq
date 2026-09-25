// ============================================================================
// Flutterwave Validate Account Edge Function
// ============================================================================
// Validates bank account number and returns account holder name.
// In Flutterwave TEST/sandbox mode, only Access Bank (044) is supported.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** Reject anonymous callers. Returns the user id, or null if unauthenticated. */
async function requireUser(req: Request): Promise<string | null> {
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !authHeader) return null;

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) return null;
  return data.user.id;
}

function isFlutterwaveSandbox(secretKey: string): boolean {
  return secretKey.includes("TEST") || secretKey.includes("test");
}

/** Normalize Flutterwave bank code (2–10 digits; pad legacy 3-digit NIP codes). */
function normalizeBankCode(raw: unknown): string {
  const digits = String(raw ?? "").replace(/\D/g, "");
  if (!digits) return "";
  // Traditional NIP codes are 3 digits (e.g. 44 → "044"). Fintechs like Opay
  // use longer codes (e.g. "100004") and must be passed through unchanged.
  if (digits.length <= 3) return digits.padStart(3, "0");
  return digits;
}

function isValidBankCode(code: string): boolean {
  return /^\d{2,10}$/.test(code);
}

function friendlyResolveError(message: string): string {
  const lower = message.toLowerCase();
  if (lower.includes("could not connect to your bank")) {
    return "We couldn't reach your bank right now (NIBSS may be busy). " +
      "Double-check your account number and try again in a few minutes.";
  }
  if (lower.includes("account number is invalid") ||
    lower.includes("could not resolve")) {
    return "That account number doesn't match this bank. Please check and try again.";
  }
  return message;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userId = await requireUser(req);
    if (!userId) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const FLW_SECRET_KEY = Deno.env.get("FLW_SECRET_KEY");
    if (!FLW_SECRET_KEY) {
      throw new Error("FLW_SECRET_KEY not configured");
    }

    const { account_number, account_bank } = await req.json();

    if (!account_number || account_bank == null || account_bank === "") {
      throw new Error("account_number and account_bank are required");
    }

    const bankCode = normalizeBankCode(account_bank);
    const accountNumber = String(account_number).trim();

    if (!isValidBankCode(bankCode)) {
      throw new Error("Invalid bank code. Please re-select your bank.");
    }

    const sandbox = isFlutterwaveSandbox(FLW_SECRET_KEY);

    // Flutterwave sandbox only resolves Access Bank (044).
    if (sandbox && bankCode !== "044") {
      return new Response(
        JSON.stringify({
          success: false,
          sandbox: true,
          error:
            "Test mode only supports Access Bank for account validation. Please select Access Bank, or switch to live Flutterwave keys for other banks.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        },
      );
    }

    console.log(
      `🔍 [Flutterwave] Validating account: ${accountNumber} at bank ${bankCode} (sandbox=${sandbox})`,
    );

    const response = await fetch("https://api.flutterwave.com/v3/accounts/resolve", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${FLW_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        account_number: accountNumber,
        account_bank: bankCode,
      }),
    });

    const data = await response.json();

    if (response.status === 200 && data.status === "success") {
      console.log(`✅ [Flutterwave] Account validated: ${data.data.account_name}`);

      return new Response(
        JSON.stringify({
          success: true,
          sandbox,
          account_name: data.data.account_name,
          account_number: data.data.account_number,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      );
    }

    const message = data.message || "Account validation failed";
    console.error(
      `❌ [Flutterwave] Resolve failed (${response.status}): ${message}`,
      JSON.stringify(data),
    );

    // Map Flutterwave sandbox restriction to a clear message.
    if (message.includes("only 044 is allowed")) {
      return new Response(
        JSON.stringify({
          success: false,
          sandbox: true,
          error:
            "Test mode only supports Access Bank for account validation. Please select Access Bank.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        },
      );
    }

    return new Response(
      JSON.stringify({
        success: false,
        sandbox,
        error: friendlyResolveError(message),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      },
    );
  } catch (error) {
    console.error("❌ [Flutterwave] Error validating account:", error);

    const errMsg = error instanceof Error ? error.message : "Account validation failed";

    return new Response(
      JSON.stringify({
        success: false,
        error: friendlyResolveError(errMsg),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: errMsg.includes("Invalid bank code") ? 400 : 500,
      },
    );
  }
});

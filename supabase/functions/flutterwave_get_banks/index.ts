// ============================================================================
// Flutterwave Get Banks Edge Function
// ============================================================================
// Returns list of Nigerian banks from Flutterwave API.
// In TEST/sandbox mode, only Access Bank (044) is returned because that is
// the only bank Flutterwave allows for account-resolve in sandbox.
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

/**
 * Normalize bank code. Pad short traditional codes to 3 digits;
 * keep longer fintech codes (e.g. Opay 100004) intact.
 */
function normalizeBankCode(raw: unknown): string {
  const digits = String(raw ?? "").replace(/\D/g, "");
  if (!digits) return "";
  if (digits.length <= 3) return digits.padStart(3, "0");
  return digits;
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

    const sandbox = isFlutterwaveSandbox(FLW_SECRET_KEY);

    console.log(`📋 [Flutterwave] Fetching Nigerian banks... (sandbox=${sandbox})`);

    const response = await fetch("https://api.flutterwave.com/v3/banks/NG", {
      method: "GET",
      headers: {
        Authorization: `Bearer ${FLW_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
    });

    const data = await response.json();

    if (response.status === 200 && data.status === "success") {
      let banks = (data.data as Array<Record<string, unknown>>).map((bank) => ({
        id: bank.id,
        code: normalizeBankCode(bank.code),
        name: bank.name,
      }));

      // Sandbox: Flutterwave only allows account resolve for Access Bank (044).
      if (sandbox) {
        banks = banks.filter((b) => b.code === "044");
      }

      console.log(`✅ [Flutterwave] Returning ${banks.length} bank(s)`);

      return new Response(
        JSON.stringify({
          success: true,
          is_sandbox: sandbox,
          banks,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        },
      );
    }

    throw new Error(data.message || "Failed to fetch banks");
  } catch (error) {
    console.error("❌ [Flutterwave] Error fetching banks:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "Failed to fetch banks",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});

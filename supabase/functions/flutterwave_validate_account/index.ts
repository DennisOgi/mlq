// ============================================================================
// Flutterwave Validate Account Edge Function
// ============================================================================
// Validates bank account number and returns account holder name
// MUST be called before saving bank account for withdrawals
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get Flutterwave secret key from environment
    const FLW_SECRET_KEY = Deno.env.get('FLW_SECRET_KEY');
    if (!FLW_SECRET_KEY) {
      throw new Error('FLW_SECRET_KEY not configured');
    }

    // Parse request body
    const { account_number, account_bank } = await req.json();

    if (!account_number || !account_bank) {
      throw new Error('account_number and account_bank are required');
    }

    console.log(`🔍 [Flutterwave] Validating account: ${account_number} at bank ${account_bank}`);

    // Call Flutterwave Account Resolve API
    const response = await fetch('https://api.flutterwave.com/v3/accounts/resolve', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${FLW_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        account_number,
        account_bank,
      }),
    });

    const data = await response.json();

    if (response.status === 200 && data.status === 'success') {
      console.log(`✅ [Flutterwave] Account validated: ${data.data.account_name}`);

      return new Response(
        JSON.stringify({
          success: true,
          account_name: data.data.account_name,
          account_number: data.data.account_number,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    throw new Error(data.message || 'Account validation failed');
  } catch (error) {
    console.error('❌ [Flutterwave] Error validating account:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Account validation failed',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});

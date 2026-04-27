// ============================================================================
// Flutterwave Get Banks Edge Function
// ============================================================================
// Returns list of Nigerian banks from Flutterwave API
// Used when user is setting up withdrawal bank account
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

    console.log('📋 [Flutterwave] Fetching Nigerian banks...');

    // Call Flutterwave API
    const response = await fetch('https://api.flutterwave.com/v3/banks/NG', {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${FLW_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
    });

    const data = await response.json();

    if (response.status === 200 && data.status === 'success') {
      console.log(`✅ [Flutterwave] Fetched ${data.data.length} banks`);

      return new Response(
        JSON.stringify({
          success: true,
          banks: data.data.map((bank: any) => ({
            id: bank.id,
            code: bank.code,
            name: bank.name,
          })),
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    throw new Error(data.message || 'Failed to fetch banks');
  } catch (error) {
    console.error('❌ [Flutterwave] Error fetching banks:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to fetch banks',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});

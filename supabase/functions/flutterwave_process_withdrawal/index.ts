// ============================================================================
// Flutterwave Process Withdrawal Edge Function
// ============================================================================
// Processes approved withdrawal request via Flutterwave Transfer API
// Called by backend/admin after withdrawal is approved
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
    // Get environment variables
    const FLW_SECRET_KEY = Deno.env.get('FLW_SECRET_KEY');
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!FLW_SECRET_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Required environment variables not configured');
    }

    // Create Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Parse request body
    const { withdrawal_id } = await req.json();

    if (!withdrawal_id) {
      throw new Error('withdrawal_id is required');
    }

    console.log(`💸 [Flutterwave] Processing withdrawal: ${withdrawal_id}`);

    // Fetch withdrawal request from database
    const { data: withdrawal, error: fetchError } = await supabase
      .from('withdrawal_requests')
      .select('*')
      .eq('id', withdrawal_id)
      .single();

    if (fetchError || !withdrawal) {
      throw new Error('Withdrawal request not found');
    }

    // Validate withdrawal status
    if (withdrawal.status !== 'approved') {
      throw new Error(`Withdrawal not approved. Status: ${withdrawal.status}`);
    }

    // Check if already processed
    if (withdrawal.flutterwave_transfer_id) {
      throw new Error('Withdrawal already processed');
    }

    // Convert kobo to naira
    const amountNaira = withdrawal.amount_kobo / 100;

    console.log(`💰 [Flutterwave] Transferring ₦${amountNaira} to ${withdrawal.account_number}`);

    // Call Flutterwave Transfer API
    const transferResponse = await fetch('https://api.flutterwave.com/v3/transfers', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${FLW_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        account_bank: withdrawal.bank_code,
        account_number: withdrawal.account_number,
        amount: amountNaira,
        currency: 'NGN',
        reference: withdrawal.flutterwave_reference,
        narration: 'LeadWallet Withdrawal',
        callback_url: `${SUPABASE_URL}/functions/v1/flutterwave_webhook`,
        meta: {
          withdrawal_id: withdrawal.id,
          student_id: withdrawal.student_id,
          product: 'LeadWallet',
        },
      }),
    });

    const transferData = await transferResponse.json();

    if (transferResponse.status === 200 && transferData.status === 'success') {
      const transferId = transferData.data.id;
      const transferStatus = transferData.data.status;

      console.log(`✅ [Flutterwave] Transfer initiated: ${transferId}, status: ${transferStatus}`);

      // Update withdrawal request with transfer ID and status
      const { error: updateError } = await supabase
        .from('withdrawal_requests')
        .update({
          flutterwave_transfer_id: transferId,
          status: 'processing',
          metadata: {
            ...withdrawal.metadata,
            transfer_response: transferData.data,
          },
          updated_at: new Date().toISOString(),
        })
        .eq('id', withdrawal_id);

      if (updateError) {
        console.error('❌ [Flutterwave] Error updating withdrawal:', updateError);
      }

      // Create wallet transaction record
      await supabase.from('wallet_transactions').insert({
        user_id: withdrawal.student_id,
        amount: -amountNaira, // Negative for withdrawal
        type: 'payout',
        status: 'pending',
        description: `Withdrawal to ${withdrawal.account_name}`,
        reference_type: 'withdrawal',
        reference_id: withdrawal.id,
        bank_transaction_id: transferId,
        metadata: {
          flutterwave_reference: withdrawal.flutterwave_reference,
          bank_code: withdrawal.bank_code,
          account_number: withdrawal.account_number,
        },
      });

      return new Response(
        JSON.stringify({
          success: true,
          transfer_id: transferId,
          reference: withdrawal.flutterwave_reference,
          status: transferStatus,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    throw new Error(transferData.message || 'Transfer failed');
  } catch (error) {
    console.error('❌ [Flutterwave] Error processing withdrawal:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Transfer failed',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});

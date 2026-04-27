// ============================================================================
// Flutterwave Webhook Edge Function
// ============================================================================
// Receives transfer status updates from Flutterwave
// Verifies webhook signature and updates transaction status in database
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, verif-hash',
  };

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get environment variables
    const FLW_SECRET_HASH = Deno.env.get('FLW_SECRET_HASH');
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!FLW_SECRET_HASH || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Required environment variables not configured');
    }

    // Verify webhook signature
    const signature = req.headers.get('verif-hash');
    if (!signature || signature !== FLW_SECRET_HASH) {
      console.error('❌ [Webhook] Invalid signature');
      return new Response('Unauthorized', { status: 401 });
    }

    // Parse webhook payload
    const payload = await req.json();
    console.log('📨 [Webhook] Received:', JSON.stringify(payload, null, 2));

    const eventType = payload.event;
    const data = payload.data;

    // Only process transfer events
    if (eventType !== 'transfer.completed') {
      console.log(`ℹ️ [Webhook] Ignoring event type: ${eventType}`);
      return new Response('OK', { status: 200 });
    }

    // Create Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Extract transfer details
    const transferId = data.id;
    const transferReference = data.reference;
    const transferStatus = data.status; // SUCCESSFUL, FAILED, etc.
    const amount = data.amount;
    const currency = data.currency;

    console.log(`💸 [Webhook] Transfer ${transferId}: ${transferStatus}`);

    // Find withdrawal request by Flutterwave reference
    const { data: withdrawal, error: fetchError } = await supabase
      .from('withdrawal_requests')
      .select('*')
      .eq('flutterwave_reference', transferReference)
      .single();

    if (fetchError || !withdrawal) {
      console.error('❌ [Webhook] Withdrawal not found for reference:', transferReference);
      return new Response('Withdrawal not found', { status: 404 });
    }

    // Verify amount matches
    const expectedAmount = withdrawal.amount_kobo / 100;
    if (Math.abs(amount - expectedAmount) > 0.01) {
      console.error(`❌ [Webhook] Amount mismatch. Expected: ${expectedAmount}, Got: ${amount}`);
      return new Response('Amount mismatch', { status: 400 });
    }

    // Determine new status based on Flutterwave status
    let newStatus: string;
    let failureReason: string | null = null;

    if (transferStatus === 'SUCCESSFUL') {
      newStatus = 'paid';
      console.log(`✅ [Webhook] Transfer successful: ${transferId}`);
    } else if (transferStatus === 'FAILED') {
      newStatus = 'failed';
      failureReason = data.complete_message || 'Transfer failed';
      console.log(`❌ [Webhook] Transfer failed: ${failureReason}`);
    } else {
      newStatus = 'processing';
      console.log(`⏳ [Webhook] Transfer still processing: ${transferStatus}`);
    }

    // Update withdrawal request
    const { error: updateWithdrawalError } = await supabase
      .from('withdrawal_requests')
      .update({
        status: newStatus,
        failure_reason: failureReason,
        metadata: {
          ...withdrawal.metadata,
          webhook_payload: data,
          webhook_received_at: new Date().toISOString(),
        },
        updated_at: new Date().toISOString(),
      })
      .eq('id', withdrawal.id);

    if (updateWithdrawalError) {
      console.error('❌ [Webhook] Error updating withdrawal:', updateWithdrawalError);
    }

    // Update wallet transaction
    const transactionStatus = newStatus === 'paid' ? 'completed' : newStatus === 'failed' ? 'failed' : 'pending';

    const { error: updateTransactionError } = await supabase
      .from('wallet_transactions')
      .update({
        status: transactionStatus,
        metadata: {
          webhook_payload: data,
          webhook_received_at: new Date().toISOString(),
        },
      })
      .eq('bank_transaction_id', transferId);

    if (updateTransactionError) {
      console.error('❌ [Webhook] Error updating transaction:', updateTransactionError);
    }

    // If successful, deduct from wallet balance
    if (newStatus === 'paid') {
      const amountNaira = withdrawal.amount_kobo / 100;

      const { error: updateBalanceError } = await supabase.rpc('debit_wallet', {
        p_user_id: withdrawal.student_id,
        p_amount: amountNaira,
        p_description: `Withdrawal completed: ${transferReference}`,
        p_type: 'payout',
        p_reference_type: 'withdrawal',
        p_reference_id: withdrawal.id,
      });

      if (updateBalanceError) {
        console.error('❌ [Webhook] Error debiting wallet:', updateBalanceError);
      } else {
        console.log(`✅ [Webhook] Wallet debited: ₦${amountNaira}`);
      }
    }

    // TODO: Send notification to student about withdrawal status

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Webhook processed successfully',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('❌ [Webhook] Error processing webhook:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Webhook processing failed',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});

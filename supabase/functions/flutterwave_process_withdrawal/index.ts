// ============================================================================
// Flutterwave Process Withdrawal Edge Function
// ============================================================================
// Processes approved withdrawal request via Flutterwave Transfer API.
// Requires authenticated admin (admin_users).
// Ledger debit happens on webhook success via debit_wallet.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function isFlutterwaveSandbox(secretKey: string): boolean {
  return secretKey.includes('TEST') || secretKey.includes('test');
}

function isIpWhitelistError(message: string): boolean {
  return /ip whitelisting/i.test(message);
}

const IP_WHITELIST_HELP =
  'Flutterwave blocks API payouts until IP addresses are whitelisted. ' +
  'In Flutterwave Dashboard go to Settings → Whitelisted IP addresses → Add IP. ' +
  'For sandbox testing you can add 0.0.0.0 (allows all IPs). ' +
  'Also ensure Settings → Business preference → Security → Transfer preferences allows API payouts. ' +
  'Supabase Edge Functions use dynamic outbound IPs, so 0.0.0.0 is required for testing unless you use a static-IP proxy.';

async function simulateSandboxTransfer(
  supabase: ReturnType<typeof createClient>,
  withdrawal: Record<string, unknown>,
  adminId: string,
) {
  const transferId = `SIM-${crypto.randomUUID()}`;
  const amountNaira = (withdrawal.amount_kobo as number) / 100;

  console.log(`🧪 [Flutterwave] Simulating sandbox transfer for withdrawal ${withdrawal.id}`);

  const { error: updateError } = await supabase
    .from('withdrawal_requests')
    .update({
      flutterwave_transfer_id: transferId,
      status: 'paid',
      metadata: {
        ...(withdrawal.metadata as Record<string, unknown> | null) ?? {},
        simulated: true,
        simulated_reason: 'flutterwave_ip_whitelist_bypass',
        processed_by: adminId,
        transfer_response: { id: transferId, status: 'SUCCESSFUL', simulated: true },
      },
      updated_at: new Date().toISOString(),
    })
    .eq('id', withdrawal.id);

  if (updateError) {
    throw new Error(`Failed to update simulated withdrawal: ${updateError.message}`);
  }

  const { data: existingTx } = await supabase
    .from('wallet_transactions')
    .select('id')
    .eq('reference_type', 'withdrawal')
    .eq('reference_id', withdrawal.id)
    .eq('type', 'payout')
    .maybeSingle();

  if (!existingTx) {
    const { error: debitError } = await supabase.rpc('debit_wallet', {
      p_user_id: withdrawal.student_id,
      p_amount: amountNaira,
      p_description: `Withdrawal completed (sandbox simulated): ${withdrawal.flutterwave_reference}`,
      p_type: 'payout',
      p_reference_type: 'withdrawal',
      p_reference_id: withdrawal.id,
    });

    if (debitError) {
      throw new Error(`Simulated payout recorded but wallet debit failed: ${debitError.message}`);
    }
  }

  return {
    success: true,
    transfer_id: transferId,
    reference: withdrawal.flutterwave_reference,
    status: 'paid',
    simulated: true,
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Track whether we moved the request to 'processing' so we can release it
  // back to 'approved' if the transfer never actually started.
  let claimed = false;
  let claimedWithdrawalId: string | null = null;
  let releaseClient: ReturnType<typeof createClient> | null = null;

  const releaseClaim = async () => {
    if (!claimed || !claimedWithdrawalId || !releaseClient) return;
    try {
      await releaseClient
        .from('withdrawal_requests')
        .update({ status: 'approved', updated_at: new Date().toISOString() })
        .eq('id', claimedWithdrawalId)
        .eq('status', 'processing')
        .is('flutterwave_transfer_id', null);
    } catch (releaseErr) {
      console.error('❌ [Flutterwave] Failed to release withdrawal claim:', releaseErr);
    }
  };

  try {
    const FLW_SECRET_KEY = Deno.env.get('FLW_SECRET_KEY');
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');

    if (!FLW_SECRET_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
      throw new Error('Required environment variables not configured');
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: adminRow, error: adminErr } = await userClient
      .from('admin_users')
      .select('user_id')
      .eq('user_id', userData.user.id)
      .maybeSingle();

    if (adminErr || !adminRow) {
      return new Response(JSON.stringify({ success: false, error: 'Admin access required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    releaseClient = supabase;

    const { withdrawal_id } = await req.json();

    if (!withdrawal_id) {
      throw new Error('withdrawal_id is required');
    }

    console.log(`💸 [Flutterwave] Processing withdrawal: ${withdrawal_id} by admin ${userData.user.id}`);

    // Atomically claim the request: only one caller can move it from
    // 'approved' → 'processing'. Any concurrent/duplicate click sees 0 rows
    // and bails out, preventing a double payout.
    const { data: claimedRows, error: claimError } = await supabase
      .from('withdrawal_requests')
      .update({ status: 'processing', updated_at: new Date().toISOString() })
      .eq('id', withdrawal_id)
      .eq('status', 'approved')
      .is('flutterwave_transfer_id', null)
      .select('*');

    if (claimError) {
      throw new Error(`Failed to claim withdrawal: ${claimError.message}`);
    }

    if (!claimedRows || claimedRows.length === 0) {
      // Not approved, already processing, or already has a transfer id.
      const { data: current } = await supabase
        .from('withdrawal_requests')
        .select('status, flutterwave_transfer_id')
        .eq('id', withdrawal_id)
        .maybeSingle();
      const statusMsg = current
        ? `Withdrawal not available for processing (status: ${current.status}${current.flutterwave_transfer_id ? ', already has transfer' : ''}).`
        : 'Withdrawal request not found';
      throw new Error(statusMsg);
    }

    const withdrawal = claimedRows[0];
    claimed = true;
    claimedWithdrawalId = withdrawal_id;

    const amountNaira = withdrawal.amount_kobo / 100;
    const sandbox = isFlutterwaveSandbox(FLW_SECRET_KEY);
    const simulateTransfers = Deno.env.get('FLW_SIMULATE_TRANSFERS') === 'true';

    if (sandbox && simulateTransfers) {
      const simulated = await simulateSandboxTransfer(supabase, withdrawal, userData.user.id);
      return new Response(JSON.stringify(simulated), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // Flutterwave TEST mode leaves transfers PENDING forever unless the
    // reference uses their mock suffix (_PMCK / _PMCKDU_{minutes}).
    // See: https://developer.flutterwave.com/docs/testing
    let transferReference = String(withdrawal.flutterwave_reference ?? '');
    if (sandbox && !/_PMCK/i.test(transferReference)) {
      transferReference = `${transferReference}_PMCKDU_1`;
      const { error: refError } = await supabase
        .from('withdrawal_requests')
        .update({
          flutterwave_reference: transferReference,
          updated_at: new Date().toISOString(),
        })
        .eq('id', withdrawal_id);
      if (refError) {
        console.warn('⚠️ [Flutterwave] Could not persist sandbox mock reference:', refError);
      } else {
        withdrawal.flutterwave_reference = transferReference;
      }
      console.log(`🧪 [Flutterwave] Sandbox mock reference: ${transferReference}`);
    }

    console.log(`💰 [Flutterwave] Transferring ₦${amountNaira} to ${withdrawal.account_number} (sandbox=${sandbox})`);

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
        reference: transferReference,
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

      const { error: updateError } = await supabase
        .from('withdrawal_requests')
        .update({
          flutterwave_transfer_id: transferId,
          flutterwave_reference: transferReference,
          status: 'processing',
          metadata: {
            ...withdrawal.metadata,
            transfer_response: transferData.data,
            processed_by: userData.user.id,
            sandbox_mock_reference: sandbox,
          },
          updated_at: new Date().toISOString(),
        })
        .eq('id', withdrawal_id);

      if (updateError) {
        console.error('❌ [Flutterwave] Error updating withdrawal:', updateError);
      }

      // Ledger debit is recorded once on webhook success via debit_wallet.

      return new Response(
        JSON.stringify({
          success: true,
          transfer_id: transferId,
          reference: transferReference,
          status: transferStatus,
          sandbox_mock: sandbox && /_PMCK/i.test(transferReference),
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    const errorMessage = transferData.message || transferData.error || 'Transfer failed';

    // Sandbox fallback: Flutterwave requires IP whitelisting for transfers but
    // Supabase Edge Functions use dynamic egress IPs. Simulate payout in TEST mode.
    if (sandbox && isIpWhitelistError(errorMessage)) {
      console.warn(`⚠️ [Flutterwave] IP whitelist blocked transfer; using sandbox simulation`);
      const simulated = await simulateSandboxTransfer(supabase, withdrawal, userData.user.id);
      return new Response(JSON.stringify(simulated), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // Transfer never started — release the claim so an admin can retry.
    await releaseClaim();

    if (isIpWhitelistError(errorMessage)) {
      throw new Error(`${errorMessage}. ${IP_WHITELIST_HELP}`);
    }

    throw new Error(errorMessage);
  } catch (error) {
    console.error('❌ [Flutterwave] Error processing withdrawal:', error);

    // If we claimed the request but never dispatched a transfer, release it.
    await releaseClaim();

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

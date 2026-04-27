# Flutterwave Wallet MVP - Implementation Guide

## Overview

This guide walks you through implementing the LeadWallet MVP using the **Internal Ledger + Flutterwave Transfer API** strategy.

**Timeline**: 2-3 weeks to production  
**Complexity**: Medium  
**Cost**: ~₦10.75 per withdrawal

---

## Phase 1: Database Setup (Day 1-2)

### Step 1: Run Database Migration

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `WALLET_MVP_DATABASE_MIGRATION.sql`
3. Execute the migration
4. Verify tables created:
   - `withdrawal_requests`
   - Views: `pending_withdrawals_admin`
   - RPCs: `get_wallet_balance_kobo`, `get_available_balance_kobo`, `validate_withdrawal_request`

### Step 2: Verify Existing Tables

Confirm these tables already exist (they do):
- ✅ `profiles` (with wallet fields)
- ✅ `wallet_transactions`
- ✅ `wallet_consent`
- ✅ `savings_goals`
- ✅ `reward_disbursements`
- ✅ `wallet_audit_log`

---

## Phase 2: Edge Functions Setup (Day 3-5)

### Step 1: Set Environment Variables

In Supabase Dashboard → Edge Functions → Settings, add:

```
FLW_SECRET_KEY=FLWSECK-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X
FLW_SECRET_HASH=your_webhook_secret_hash
```

**How to get these**:
1. Login to Flutterwave Dashboard
2. Settings → API Keys
3. Copy Secret Key (starts with `FLWSECK-`)
4. Settings → Webhooks → Create webhook
5. Set URL: `https://your-project.supabase.co/functions/v1/flutterwave_webhook`
6. Copy Secret Hash

### Step 2: Deploy Edge Functions

Deploy the 4 Edge Functions:

```bash
# Navigate to project
cd my_leadership_quest

# Deploy functions
supabase functions deploy flutterwave_get_banks
supabase functions deploy flutterwave_validate_account
supabase functions deploy flutterwave_process_withdrawal
supabase functions deploy flutterwave_webhook
```

**Files to deploy**:
- `supabase/functions/flutterwave_get_banks/index.ts`
- `supabase/functions/flutterwave_validate_account/index.ts`
- `supabase/functions/flutterwave_process_withdrawal/index.ts`
- `supabase/functions/flutterwave_webhook/index.ts`

### Step 3: Test Edge Functions

Test each function in Supabase Dashboard → Edge Functions:

**Test `flutterwave_get_banks`**:
```json
{}
```
Expected: List of Nigerian banks

**Test `flutterwave_validate_account`**:
```json
{
  "account_number": "0690000031",
  "account_bank": "044"
}
```
Expected: Account name returned

---

## Phase 3: Flutter Service Updates (Day 6-8)

### Step 1: Update FlutterwaveWalletService

The service is already created at:
`lib/services/flutterwave_wallet_service.dart`

**Key methods**:
- `getNigerianBanks()` - Get list of banks
- `validateBankAccount()` - Verify account details
- `createWithdrawalRequest()` - Student initiates withdrawal
- `processWithdrawal()` - Admin processes approved withdrawal
- `getWithdrawalRequests()` - Get withdrawal history

### Step 2: Update WalletService

Update `lib/services/wallet_service.dart` to integrate with new withdrawal flow:

```dart
// Add method to get available balance (excluding pending withdrawals)
Future<double> getAvailableBalance(String userId) async {
  try {
    final result = await _client.rpc('get_available_balance_kobo', params: {
      'p_user_id': userId,
    });
    return (result as num).toDouble() / 100.0; // Convert kobo to naira
  } catch (e) {
    debugPrint('Error fetching available balance: $e');
    return 0.0;
  }
}
```

### Step 3: Create UI Screens

**Required Screens**:

1. **Bank Account Setup Screen** (`lib/screens/wallet/bank_account_setup_screen.dart`)
   - Select bank from dropdown
   - Enter account number
   - Validate account (shows account name)
   - Save account details

2. **Withdrawal Request Screen** (`lib/screens/wallet/withdrawal_request_screen.dart`)
   - Show available balance
   - Enter withdrawal amount
   - Select saved bank account
   - Confirm and submit

3. **Withdrawal History Screen** (`lib/screens/wallet/withdrawal_history_screen.dart`)
   - List all withdrawal requests
   - Show status (pending, processing, paid, failed)
   - Show details (amount, bank, date)

4. **Admin Withdrawal Approval Screen** (`lib/screens/admin/withdrawal_approval_screen.dart`)
   - List pending withdrawals
   - Show student details
   - Approve/reject withdrawals

---

## Phase 4: Testing (Day 9-12)

### Step 1: Flutterwave Test Mode

1. Use Flutterwave Test API keys
2. Test bank codes for sandbox:
   - Access Bank: `044`
   - GTBank: `058`
   - Zenith Bank: `057`

3. Test account numbers (Flutterwave sandbox):
   - `0690000031` - Success
   - `0690000032` - Failed

### Step 2: Test Scenarios

**Scenario 1: Successful Withdrawal**
1. Student earns reward (₦1,000)
2. Admin approves reward
3. Student requests withdrawal (₦500)
4. Parent approves (if consent required)
5. Admin approves withdrawal
6. Edge Function processes transfer
7. Webhook confirms success
8. Balance updated

**Scenario 2: Failed Withdrawal**
1. Same as above, but use test account that fails
2. Webhook confirms failure
3. Status updated to 'failed'
4. Balance NOT deducted

**Scenario 3: Insufficient Balance**
1. Student tries to withdraw more than available
2. Validation fails
3. Error message shown

**Scenario 4: Daily Limit Exceeded**
1. Student withdraws ₦10,000
2. Tries to withdraw again same day
3. Validation fails
4. Error message shown

### Step 3: Monitor Logs

Check logs in:
- Supabase Dashboard → Edge Functions → Logs
- Flutterwave Dashboard → Logs
- Database: `wallet_audit_log` table

---

## Phase 5: Production Launch (Day 13-15)

### Step 1: Switch to Live Keys

1. Get live Flutterwave API keys
2. Update environment variables in Supabase
3. Update webhook URL in Flutterwave Dashboard

### Step 2: Pilot Program

**Launch to 10-20 students**:
- Small reward amounts (₦100-500)
- Monitor closely for 1 week
- Gather feedback
- Fix any issues

### Step 3: Full Launch

**Enable for all users**:
- Announce feature
- Provide user guide
- Monitor performance
- Iterate based on feedback

---

## Security Checklist

Before production launch, verify:

- [ ] Flutterwave secret keys stored in environment variables (NOT in code)
- [ ] Webhook signature verification enabled
- [ ] RLS policies enabled on all tables
- [ ] Parent consent required for withdrawals
- [ ] Admin approval required for high-value withdrawals
- [ ] Withdrawal limits enforced (min ₦500, max ₦10,000/day)
- [ ] Audit logging enabled for all operations
- [ ] Error handling and logging in place
- [ ] CORS configured correctly
- [ ] Test mode disabled in production

---

## Monitoring & Maintenance

### Daily Checks

1. **Check pending withdrawals**:
   ```sql
   SELECT * FROM pending_withdrawals_admin;
   ```

2. **Check failed transfers**:
   ```sql
   SELECT * FROM withdrawal_requests WHERE status = 'failed';
   ```

3. **Check audit logs**:
   ```sql
   SELECT * FROM wallet_audit_log ORDER BY created_at DESC LIMIT 100;
   ```

### Weekly Checks

1. **Reconciliation**:
   - Compare database balances with Flutterwave transfer history
   - Verify all successful transfers deducted from wallets
   - Check for any stuck transactions

2. **Performance**:
   - Check Edge Function response times
   - Monitor webhook delivery success rate
   - Review error logs

### Monthly Checks

1. **Cost Analysis**:
   - Total withdrawals processed
   - Total Flutterwave fees paid
   - Average withdrawal amount

2. **User Feedback**:
   - Withdrawal success rate
   - Average processing time
   - User satisfaction

---

## Troubleshooting

### Issue: Webhook not received

**Symptoms**: Transfer status stuck at 'processing'

**Solutions**:
1. Check webhook URL in Flutterwave Dashboard
2. Verify webhook secret hash matches
3. Check Edge Function logs for errors
4. Manually check transfer status:
   ```dart
   final status = await flutterwaveWalletService.getTransferStatus(transferId);
   ```

### Issue: Transfer failed

**Symptoms**: Withdrawal status 'failed'

**Common Causes**:
1. Invalid bank account number
2. Insufficient Flutterwave balance
3. Bank service unavailable
4. Account frozen/restricted

**Solutions**:
1. Check `failure_reason` in `withdrawal_requests` table
2. Verify bank account details
3. Check Flutterwave Dashboard for more details
4. Retry transfer if temporary issue

### Issue: Balance mismatch

**Symptoms**: Database balance doesn't match expected

**Solutions**:
1. Check `wallet_transactions` table for all transactions
2. Verify all successful withdrawals deducted
3. Check for any failed transactions that weren't reversed
4. Run reconciliation query:
   ```sql
   SELECT 
     user_id,
     wallet_balance,
     (SELECT SUM(amount) FROM wallet_transactions WHERE user_id = profiles.id AND status = 'completed') as calculated_balance
   FROM profiles
   WHERE wallet_balance != (SELECT SUM(amount) FROM wallet_transactions WHERE user_id = profiles.id AND status = 'completed');
   ```

---

## Future Enhancements

### Phase 2: Payout Subaccounts (Optional)

**When to implement**:
- After MVP proves successful
- When you need real-time balance sync
- When you want students to fund wallets from bank

**Benefits**:
- Flutterwave-managed per-user wallet balances
- Dedicated virtual accounts per student
- Better wallet reconciliation
- Enable bank-to-wallet deposits

**Implementation**:
- Create Flutterwave Payout Subaccount per student
- Sync balances between database and Flutterwave
- Update Edge Functions to use subaccounts
- More complex but more features

### Phase 3: Advanced Features

- **Automated savings**: Round-up purchases to savings goals
- **Interest on savings**: Reward students for saving
- **Peer-to-peer transfers**: Students can send money to each other
- **Bill payments**: Pay for airtime, data, etc.
- **School fee payments**: Pay school fees from wallet

---

## Support Resources

### Documentation
- Flutterwave API Docs: https://developer.flutterwave.com/docs
- Supabase Edge Functions: https://supabase.com/docs/guides/functions
- This implementation guide

### Dashboards
- Flutterwave Dashboard: https://dashboard.flutterwave.com
- Supabase Dashboard: https://supabase.com/dashboard

### Contact
- Flutterwave Support: support@flutterwave.com
- Supabase Support: support@supabase.com

---

## Summary

**MVP Implementation Checklist**:

- [ ] Phase 1: Database migration complete
- [ ] Phase 2: Edge Functions deployed and tested
- [ ] Phase 3: Flutter services updated
- [ ] Phase 4: Testing complete (sandbox mode)
- [ ] Phase 5: Production launch (pilot → full)

**Timeline**: 2-3 weeks  
**Status**: Ready to implement  
**Next Action**: Run database migration

---

**Good luck with the implementation! 🚀**


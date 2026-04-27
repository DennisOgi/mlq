# Flutterwave Wallet Integration - MVP Strategy

## Analysis: New Information vs Core LeadWallet Idea

### ✅ HIGHLY RELEVANT - Critical Corrections

The new information provides **essential corrections** to our original approach:

#### 1. **Subaccount Confusion Clarified**
**Original Plan**: Use Flutterwave "Subaccounts" for each student
**Problem**: Flutterwave has TWO different subaccount types:
- **Collection Subaccounts**: For splitting incoming payments (NOT what we need)
- **Payout Subaccounts (PSA Wallets)**: Virtual wallets for end users (closer to our need)

**Impact**: We were about to implement the WRONG type of subaccount!

#### 2. **MVP Recommendation: Internal Ledger + Direct Transfers**
**Better Approach**: 
- Use Supabase database as source of truth (internal ledger)
- Use Flutterwave Transfer API ONLY for withdrawals
- No per-student Flutterwave accounts needed initially

**Why This is Better**:
- ✅ Simpler implementation (2-3 weeks vs 4-6 weeks)
- ✅ Lower costs (only pay for actual withdrawals)
- ✅ Easier to audit and reconcile
- ✅ Full control over wallet logic
- ✅ Faster to launch and test
- ✅ Can upgrade to PSA Wallets later if needed

#### 3. **Security Best Practices**
**Critical Rule**: Flutter app NEVER calls Flutterwave directly
- All secret API calls via Supabase Edge Functions
- Webhook verification mandatory
- Never trust client-side calculations

#### 4. **Use Kobo, Not Naira**
**Important**: Store amounts in kobo (₦1 = 100 kobo) to avoid floating-point errors
- Database: `amount_kobo INTEGER`
- Display: Convert to Naira for UI

#### 5. **Compliance & Wording**
**Risk**: Calling it a "bank wallet" or "student bank account" may trigger CBN regulations
**Safer Wording**:
- "LeadWallet Rewards Balance"
- "Approved Rewards Balance"
- "Earnings Wallet"

---

## Current Database Status

### ✅ Already Implemented (Good Foundation)

**profiles table** has wallet fields:
```sql
- wallet_balance: NUMERIC (current balance in NGN)
- wallet_status: TEXT (inactive, pending_consent, active, frozen)
- wallet_activated_at: TIMESTAMPTZ
```

**wallet_transactions table** exists:
```sql
- id, user_id, amount, balance_after
- type: reward, savings_deposit, savings_withdrawal, payout, adjustment
- status: pending, completed, failed, reversed
- description, reference_type, reference_id
- approved_by, bank_transaction_id
- created_at
```

**wallet_consent table** exists:
```sql
- student_id, parent_email, consent_type
- consent_token, status, approved_at
- ip_address, created_at, expires_at
```

**savings_goals table** exists:
```sql
- user_id, title, target_amount, current_amount
- icon, status, completed_at
- created_at, updated_at
```

**reward_disbursements table** exists:
```sql
- student_id, amount, reason, challenge_id
- status, approved_by, approved_at, disbursed_at
- bank_reference, created_at, updated_at
```

**wallet_audit_log table** exists:
```sql
- actor_id, action, target_user_id
- amount, metadata, created_at
```

### ❌ Missing (Need to Create)

**withdrawal_requests table** - CRITICAL for MVP:
```sql
- id, student_id, amount_kobo (INTEGER!)
- bank_code, account_number, account_name
- status: pending_parent_approval, pending_admin_approval, processing, paid, failed, rejected
- flutterwave_reference, flutterwave_transfer_id
- approved_by, approved_at, failure_reason
- created_at, updated_at
```

---

## MVP Implementation Plan

### Phase 1: Database Schema Updates (1-2 days)

**1. Create `withdrawal_requests` table**
**2. Add kobo fields to existing tables** (migration strategy)
**3. Create database RPCs**:
   - `get_wallet_balance_kobo(user_id)` - Calculate from ledger
   - Update existing RPCs to handle kobo

### Phase 2: Edge Functions (3-5 days)

**1. `flutterwave_get_banks`**
   - GET https://api.flutterwave.com/v3/banks/NG
   - Returns list of Nigerian banks

**2. `flutterwave_validate_account`**
   - POST https://api.flutterwave.com/v3/accounts/resolve
   - Verifies account number and returns account holder name

**3. `flutterwave_process_withdrawal`**
   - POST https://api.flutterwave.com/v3/transfers
   - Executes actual bank transfer
   - Updates withdrawal_request status

**4. `flutterwave_webhook`**
   - Receives transfer status updates
   - Verifies webhook signature
   - Updates transaction status in database

**5. `flutterwave_get_transfer_status`**
   - GET https://api.flutterwave.com/v3/transfers/{id}
   - Manual status check for pending transfers

### Phase 3: Flutter Service Updates (2-3 days)

**1. Update `FlutterwaveWalletService`** (already created, needs refinement)
**2. Update `WalletService`** to use new withdrawal flow
**3. Create UI screens**:
   - Bank account setup screen
   - Withdrawal request screen
   - Withdrawal history screen
   - Parent approval screen (web/email)
   - Admin approval dashboard

### Phase 4: Testing & Launch (3-5 days)

**1. Flutterwave Test Mode**
   - Test with small amounts (₦100-500)
   - Verify webhook handling
   - Test all failure scenarios

**2. Pilot Program**
   - 10-20 students
   - Small reward amounts
   - Monitor closely

**3. Production Launch**
   - Switch to live Flutterwave keys
   - Enable for all users
   - Monitor and iterate

---

## Architecture: MVP vs Future

### MVP (Recommended - Start Here)

```
Student earns achievement
    ↓
Backend creates transaction (pending)
    ↓
Admin/parent approves
    ↓
Ledger balance increases (in database)
    ↓
Student requests withdrawal
    ↓
Creates withdrawal_request (pending_parent_approval)
    ↓
Parent approves
    ↓
Status: pending_admin_approval
    ↓
Admin approves
    ↓
Edge Function calls Flutterwave Transfer API
    ↓
Status: processing
    ↓
Webhook confirms success/failure
    ↓
Status: paid or failed
    ↓
If paid: Money in student's bank account
```

**Pros**:
- Simple and fast to implement
- Full control over wallet logic
- Easy to audit and debug
- Lower costs (only pay for withdrawals)
- Can launch in 2-3 weeks

**Cons**:
- No real-time bank balance sync
- Manual reconciliation needed
- Students can't fund wallet from bank

### Future Enhancement: Payout Subaccounts

**When to Upgrade**:
- After MVP proves successful
- When you need real-time balance sync
- When you want students to fund wallets from bank
- When you need dedicated virtual accounts per student

**Implementation**:
- Create Flutterwave Payout Subaccount per student
- Sync balances between database and Flutterwave
- Enable bank-to-wallet deposits
- More complex but more features

---

## Key Differences from Original Plan

| Aspect | Original Plan | MVP Strategy |
|--------|--------------|--------------|
| **Flutterwave Integration** | Subaccounts for each student | Direct Transfer API only |
| **Balance Storage** | Flutterwave + Database | Database only (source of truth) |
| **Money Movement** | All via Flutterwave | Only withdrawals via Flutterwave |
| **Complexity** | High | Low |
| **Timeline** | 4-6 weeks | 2-3 weeks |
| **Cost** | Per-student + per-transfer | Per-transfer only |
| **Reconciliation** | Complex (two systems) | Simple (one system) |
| **Upgrade Path** | N/A | Can add PSA Wallets later |

---

## Security & Compliance

### Security Measures (MVP)

1. **Never expose Flutterwave secret key to Flutter**
2. **All transfers via Edge Functions**
3. **Webhook signature verification**
4. **Parent consent required**
5. **Admin approval for high-value withdrawals**
6. **Audit logging for all operations**
7. **Store amounts in kobo (avoid float errors)**
8. **Rate limiting on withdrawal requests**

### Compliance Considerations

**Wording**:
- ❌ "Bank Account"
- ❌ "Student Wallet"
- ✅ "Rewards Balance"
- ✅ "Earnings Wallet"
- ✅ "LeadWallet"

**Limits** (Recommended):
- Minimum withdrawal: ₦500 (50,000 kobo)
- Maximum withdrawal per day: ₦10,000 (1,000,000 kobo)
- Maximum withdrawal per month: ₦50,000 (5,000,000 kobo)
- Parent approval required for all withdrawals
- Admin approval for withdrawals > ₦5,000

---

## Cost Analysis

### MVP Costs

**Flutterwave Transfer Fees**:
- ₦10.75 per transfer (standard rate)
- Only charged on actual withdrawals

**Example Scenarios**:
- 100 students, 1 withdrawal/month = ₦1,075/month
- 1000 students, 2 withdrawals/month = ₦21,500/month

**No Costs For**:
- Reward credits (database only)
- Balance checks (database only)
- Savings goals (database only)
- Transaction history (database only)

### Future PSA Wallet Costs

**If you upgrade to Payout Subaccounts**:
- Subaccount creation: Free
- Transfers to subaccounts: ₦10.75 each
- Transfers from subaccounts to banks: ₦10.75 each
- Balance checks: Free

---

## Recommendation

### ✅ Proceed with MVP Strategy

**Reasons**:
1. **Faster to market** (2-3 weeks vs 4-6 weeks)
2. **Lower risk** (simpler system, easier to debug)
3. **Lower cost** (only pay for withdrawals)
4. **Easier to audit** (single source of truth)
5. **Upgrade path exists** (can add PSA Wallets later)
6. **Aligns with current database** (minimal changes needed)

### Next Steps

1. ✅ Create `withdrawal_requests` table
2. ✅ Create Edge Functions for Flutterwave API
3. ✅ Update Flutter services
4. ✅ Build UI screens
5. ✅ Test in Flutterwave sandbox
6. ✅ Launch pilot program
7. ✅ Monitor and iterate

---

## Summary

The new information is **highly relevant** and provides **critical corrections** to our approach. The MVP strategy (Internal Ledger + Direct Transfers) is:

- **Simpler** than our original subaccount plan
- **Faster** to implement (2-3 weeks)
- **Cheaper** (only pay for withdrawals)
- **Safer** (easier to audit and control)
- **Scalable** (can upgrade to PSA Wallets later)

**Core LeadWallet idea remains the same**: Students earn real money through achievements. The implementation strategy is just smarter and more practical for MVP.

---

**Status**: Ready to implement MVP  
**Timeline**: 2-3 weeks to production  
**Next Action**: Create database migration for `withdrawal_requests` table


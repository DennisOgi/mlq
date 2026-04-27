# LeadWallet MVP - Quick Start Checklist

## 🚀 Complete Setup in 30 Minutes

Follow this checklist to get LeadWallet up and running quickly.

---

## Phase 1: Get Flutterwave Keys (10 minutes)

### Step 1: Get API Keys

- [ ] Go to https://dashboard.flutterwave.com
- [ ] Login to your account
- [ ] Navigate to **Settings** → **API Keys**
- [ ] Copy **TEST Secret Key** (starts with `FLWSECK-TEST-`)
- [ ] Copy **LIVE Secret Key** (starts with `FLWSECK-`) - for production later
- [ ] Save both keys in a secure location

**Your keys should look like**:
```
TEST: FLWSECK-TEST-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X
LIVE: FLWSECK-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X
```

### Step 2: Create Webhook

- [ ] In Flutterwave Dashboard, go to **Settings** → **Webhooks**
- [ ] Click **"Add Webhook"**
- [ ] Enter URL: `https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/flutterwave_webhook`
  - Replace `hcvyumbkonrisrxbjnst` with your Supabase project ID
- [ ] Select event: **transfer.completed**
- [ ] Click **"Save"**
- [ ] Copy the **Secret Hash** that's generated
- [ ] Save the Secret Hash

**Your webhook hash should look like**:
```
flw_secret_hash_1234567890abcdef
```

---

## Phase 2: Configure Supabase (5 minutes)

### Step 3: Add Environment Variables

- [ ] Go to https://supabase.com/dashboard
- [ ] Select project: **My Leadership Quest**
- [ ] Click **Edge Functions** in sidebar
- [ ] Click **"Manage secrets"** or **"Environment Variables"**
- [ ] Add variable 1:
  - Name: `FLW_SECRET_KEY`
  - Value: Your Flutterwave TEST Secret Key
- [ ] Add variable 2:
  - Name: `FLW_SECRET_HASH`
  - Value: Your Webhook Secret Hash
- [ ] Click **"Save"**

**You should see**:
```
FLW_SECRET_KEY = FLWSECK-TEST-••••••••••••••••••••••••••••••••-X
FLW_SECRET_HASH = flw_secret_hash_••••••••••••••••
```

---

## Phase 3: Database Setup (5 minutes)

### Step 4: Run Migration

- [ ] In Supabase Dashboard, click **SQL Editor**
- [ ] Click **"New query"**
- [ ] Open file: `WALLET_MVP_DATABASE_MIGRATION.sql`
- [ ] Copy ALL contents
- [ ] Paste into SQL Editor
- [ ] Click **"Run"** or press `Ctrl+Enter`
- [ ] Wait for success message

**Expected result**:
```
Success. No rows returned
```

### Step 5: Verify Tables Created

- [ ] In Supabase Dashboard, click **Table Editor**
- [ ] Verify these tables exist:
  - `withdrawal_requests` ✅
  - `wallet_transactions` ✅
  - `wallet_consent` ✅
  - `savings_goals` ✅

---

## Phase 4: Deploy Edge Functions (10 minutes)

### Step 6: Install Supabase CLI (if not installed)

**Windows**:
```powershell
# Using Scoop
scoop install supabase

# Or download from: https://github.com/supabase/cli/releases
```

**Mac/Linux**:
```bash
brew install supabase/tap/supabase
```

### Step 7: Login to Supabase

```bash
supabase login
```

- [ ] Follow the prompts to authenticate
- [ ] Verify login successful

### Step 8: Link Project

```bash
cd my_leadership_quest
supabase link --project-ref hcvyumbkonrisrxbjnst
```

- [ ] Replace `hcvyumbkonrisrxbjnst` with your project ID
- [ ] Enter your database password when prompted

### Step 9: Deploy Functions

```bash
# Deploy all 4 functions
supabase functions deploy flutterwave_get_banks
supabase functions deploy flutterwave_validate_account
supabase functions deploy flutterwave_process_withdrawal
supabase functions deploy flutterwave_webhook
```

- [ ] Wait for each deployment to complete
- [ ] Verify all 4 functions deployed successfully

**Expected output**:
```
✓ Deployed function flutterwave_get_banks
✓ Deployed function flutterwave_validate_account
✓ Deployed function flutterwave_process_withdrawal
✓ Deployed function flutterwave_webhook
```

---

## Phase 5: Test Configuration (5 minutes)

### Step 10: Test API Connection

- [ ] In Supabase Dashboard, go to **Edge Functions**
- [ ] Click on **flutterwave_get_banks**
- [ ] Click **"Invoke"** or **"Test"**
- [ ] Send empty body: `{}`
- [ ] Verify you get a list of Nigerian banks

**Expected response**:
```json
{
  "success": true,
  "banks": [
    {"id": 1, "code": "044", "name": "Access Bank"},
    {"id": 2, "code": "058", "name": "Guaranty Trust Bank"},
    ...
  ]
}
```

### Step 11: Test Account Validation

- [ ] Click on **flutterwave_validate_account**
- [ ] Click **"Invoke"**
- [ ] Send test body:
```json
{
  "account_number": "0690000031",
  "account_bank": "044"
}
```
- [ ] Verify you get account name back

**Expected response**:
```json
{
  "success": true,
  "account_name": "Test Account Name",
  "account_number": "0690000031"
}
```

---

## ✅ Setup Complete!

If all steps are checked, your LeadWallet MVP is configured and ready!

---

## Next Steps

### For Testing (This Week)

1. **Test withdrawal flow in sandbox mode**:
   - Create test student account
   - Credit wallet with test reward
   - Request withdrawal
   - Process withdrawal
   - Verify webhook updates status

2. **Test all scenarios**:
   - Successful withdrawal
   - Failed withdrawal
   - Insufficient balance
   - Daily limit exceeded
   - Invalid bank account

### For Production (Next Week)

1. **Switch to LIVE keys**:
   - Update `FLW_SECRET_KEY` with LIVE key
   - Keep `FLW_SECRET_HASH` the same
   - Redeploy Edge Functions

2. **Launch pilot program**:
   - Select 10-20 students
   - Small reward amounts (₦100-500)
   - Monitor closely for 1 week

3. **Full launch**:
   - Enable for all users
   - Announce feature
   - Monitor and iterate

---

## Troubleshooting

### ❌ "FLW_SECRET_KEY not configured"

**Fix**:
1. Verify you added the variable in Supabase
2. Check spelling: `FLW_SECRET_KEY` (case-sensitive)
3. Redeploy Edge Functions

### ❌ "Invalid signature" webhook error

**Fix**:
1. Verify `FLW_SECRET_HASH` matches Flutterwave
2. Check for extra spaces
3. Regenerate webhook in Flutterwave if needed

### ❌ No banks returned from test

**Fix**:
1. Check `FLW_SECRET_KEY` is correct
2. Verify key starts with `FLWSECK-TEST-`
3. Check Edge Function logs for errors

### ❌ Supabase CLI not found

**Fix**:
1. Install Supabase CLI (see Step 6)
2. Restart terminal after installation
3. Verify with: `supabase --version`

---

## Quick Reference

### Your Configuration

```
Supabase Project ID: hcvyumbkonrisrxbjnst
Webhook URL: https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/flutterwave_webhook

Environment Variables:
- FLW_SECRET_KEY = FLWSECK-TEST-••••••••••••••••••••••••••••••••-X
- FLW_SECRET_HASH = flw_secret_hash_••••••••••••••••

Edge Functions Deployed:
✓ flutterwave_get_banks
✓ flutterwave_validate_account
✓ flutterwave_process_withdrawal
✓ flutterwave_webhook
```

### Test Bank Accounts (Flutterwave Sandbox)

```
Success: 0690000031 (Access Bank - 044)
Failed:  0690000032 (Access Bank - 044)
```

### Useful Commands

```bash
# Check Supabase CLI version
supabase --version

# Login to Supabase
supabase login

# Link project
supabase link --project-ref hcvyumbkonrisrxbjnst

# Deploy single function
supabase functions deploy flutterwave_get_banks

# Deploy all functions
supabase functions deploy flutterwave_get_banks && \
supabase functions deploy flutterwave_validate_account && \
supabase functions deploy flutterwave_process_withdrawal && \
supabase functions deploy flutterwave_webhook

# View function logs
supabase functions logs flutterwave_webhook
```

---

## Support Resources

**Documentation**:
- `FLUTTERWAVE_API_KEYS_SETUP_GUIDE.md` - Detailed key setup
- `FLUTTERWAVE_WALLET_IMPLEMENTATION_GUIDE.md` - Full implementation guide
- `FLUTTERWAVE_WALLET_MVP_STRATEGY.md` - Architecture and strategy

**External**:
- Flutterwave Dashboard: https://dashboard.flutterwave.com
- Flutterwave Docs: https://developer.flutterwave.com/docs
- Supabase Dashboard: https://supabase.com/dashboard
- Supabase Docs: https://supabase.com/docs

---

## Estimated Time

- ⏱️ **Phase 1**: 10 minutes (Get Flutterwave keys)
- ⏱️ **Phase 2**: 5 minutes (Configure Supabase)
- ⏱️ **Phase 3**: 5 minutes (Database setup)
- ⏱️ **Phase 4**: 10 minutes (Deploy Edge Functions)
- ⏱️ **Phase 5**: 5 minutes (Test configuration)

**Total**: ~35 minutes

---

**Ready to start? Begin with Phase 1! 🚀**


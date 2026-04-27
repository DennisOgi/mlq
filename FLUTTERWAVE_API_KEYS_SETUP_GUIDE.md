# Flutterwave API Keys Setup Guide

## Complete Step-by-Step Guide to Get Flutterwave Keys and Configure Supabase

---

## Part 1: Get Flutterwave API Keys

### Step 1: Login to Flutterwave Dashboard

1. Go to **https://dashboard.flutterwave.com**
2. Login with your Flutterwave account credentials
3. If you don't have an account:
   - Click "Sign Up"
   - Choose "Business Account"
   - Complete registration
   - Verify your email

### Step 2: Navigate to API Settings

Once logged in:

1. Look at the **left sidebar menu**
2. Click on **"Settings"** (gear icon at bottom)
3. In the Settings menu, click on **"API"** or **"API Keys"**

**What you'll see**:
- A page titled "API Keys" or "API Settings"
- Two sections: **Test Keys** and **Live Keys**

### Step 3: Get Test Keys (For Development)

**Important**: Start with TEST keys for development and testing!

1. In the **"Test"** section, you'll see:
   - **Public Key** (starts with `FLWPUBK-TEST-`)
   - **Secret Key** (starts with `FLWSECK-TEST-`)
   - **Encryption Key** (optional, not needed for our use case)

2. **Copy the Secret Key**:
   - Click the **"Show"** or **"Reveal"** button next to Secret Key
   - Click the **"Copy"** icon
   - Save it somewhere safe (you'll need this for Supabase)

**Example format**:
```
FLWSECK-TEST-1234567890abcdef1234567890abcdef-X
```

3. **Copy the Public Key** (you already have this):
   - You mentioned you have: `FLWPUBK-3458a6b1472c5d67e1f5e1ccc4be9598-X`
   - This is your LIVE public key
   - For testing, also copy the TEST public key

### Step 4: Get Live Keys (For Production)

**Only do this when ready for production!**

1. In the **"Live"** section, you'll see:
   - **Public Key** (starts with `FLWPUBK-`)
   - **Secret Key** (starts with `FLWSECK-`)

2. **Copy the Live Secret Key**:
   - Click "Show" or "Reveal"
   - Click "Copy"
   - **KEEP THIS EXTREMELY SECURE** - Never share or commit to code!

**Your Live Public Key** (you already have):
```
FLWPUBK-3458a6b1472c5d67e1f5e1ccc4be9598-X
```

**You need to get**:
```
FLWSECK-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X (Live Secret Key)
```

---

## Part 2: Set Up Webhook Secret Hash

### Step 5: Create Webhook in Flutterwave

1. In Flutterwave Dashboard, go to **Settings** → **Webhooks**
2. Click **"Add Webhook"** or **"Create Webhook"**

3. **Fill in the form**:
   - **Webhook URL**: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/flutterwave_webhook`
     - Replace `YOUR_PROJECT_ID` with your actual Supabase project ID
     - Example: `https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/flutterwave_webhook`
   
   - **Events to listen for**: Select **"Transfer"** events
     - Check: `transfer.completed`
     - Check: `transfer.failed` (if available)
   
   - **Secret Hash**: Flutterwave will generate this automatically
     - After creating the webhook, you'll see a **Secret Hash**
     - Click **"Copy"** to copy it
     - Save it somewhere safe

**Example Secret Hash format**:
```
flw_secret_hash_1234567890abcdef
```

4. Click **"Save"** or **"Create Webhook"**

### Step 6: Find Your Supabase Project ID

**Method 1: From Supabase Dashboard URL**
1. Go to your Supabase Dashboard
2. Look at the URL in your browser
3. It will look like: `https://supabase.com/dashboard/project/hcvyumbkonrisrxbjnst`
4. Your project ID is: `hcvyumbkonrisrxbjnst`

**Method 2: From Project Settings**
1. In Supabase Dashboard, click **"Project Settings"** (gear icon)
2. Go to **"General"** tab
3. Look for **"Reference ID"** or **"Project ID"**
4. Copy the ID

---

## Part 3: Configure Supabase Environment Variables

### Step 7: Navigate to Edge Functions Settings

1. Go to **Supabase Dashboard**: https://supabase.com/dashboard
2. Select your project: **"My Leadership Quest"**
3. In the left sidebar, click **"Edge Functions"**
4. Click on **"Manage secrets"** or look for **"Environment Variables"** section
   - If you don't see this, click on any function, then look for **"Settings"** or **"Secrets"** tab

### Step 8: Add Environment Variables

You need to add **2 environment variables**:

#### Variable 1: FLW_SECRET_KEY

1. Click **"Add new secret"** or **"New variable"**
2. **Name**: `FLW_SECRET_KEY`
3. **Value**: Paste your Flutterwave Secret Key
   - For testing: `FLWSECK-TEST-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X`
   - For production: `FLWSECK-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X`
4. Click **"Save"** or **"Add"**

#### Variable 2: FLW_SECRET_HASH

1. Click **"Add new secret"** or **"New variable"** again
2. **Name**: `FLW_SECRET_HASH`
3. **Value**: Paste your Webhook Secret Hash from Step 5
   - Example: `flw_secret_hash_1234567890abcdef`
4. Click **"Save"** or **"Add"**

### Step 9: Verify Environment Variables

After adding both variables, you should see:

```
FLW_SECRET_KEY = FLWSECK-TEST-••••••••••••••••••••••••••••••••-X
FLW_SECRET_HASH = flw_secret_hash_••••••••••••••••
```

**Note**: The values will be hidden (shown as dots) for security.

---

## Part 4: Update Webhook URL (If Needed)

### Step 10: Update Flutterwave Webhook URL

If you created the webhook before knowing your Supabase project ID:

1. Go back to **Flutterwave Dashboard** → **Settings** → **Webhooks**
2. Find your webhook
3. Click **"Edit"**
4. Update the URL to: `https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/flutterwave_webhook`
   - Use your actual project ID
5. Click **"Save"**

---

## Part 5: Test the Configuration

### Step 11: Test API Keys

You can test if the keys are working by deploying and testing the Edge Functions:

1. **Deploy the Edge Functions** (we'll do this next)
2. **Test `flutterwave_get_banks` function**:
   - Go to Supabase Dashboard → Edge Functions
   - Click on `flutterwave_get_banks`
   - Click **"Invoke"** or **"Test"**
   - Send empty body: `{}`
   - You should get a list of Nigerian banks

**Expected Response**:
```json
{
  "success": true,
  "banks": [
    {
      "id": 1,
      "code": "044",
      "name": "Access Bank"
    },
    {
      "id": 2,
      "code": "058",
      "name": "Guaranty Trust Bank"
    },
    ...
  ]
}
```

**If you get an error**:
- Check that `FLW_SECRET_KEY` is set correctly
- Verify the key starts with `FLWSECK-`
- Make sure you copied the entire key (including the `-X` at the end)

### Step 12: Test Webhook

To test the webhook:

1. **Make a test transfer** in Flutterwave Dashboard (using test mode)
2. **Check Supabase Edge Function logs**:
   - Go to Supabase Dashboard → Edge Functions
   - Click on `flutterwave_webhook`
   - Click **"Logs"** tab
   - You should see webhook events being received

---

## Quick Reference: What You Need

### For Testing (Development)

```
FLW_SECRET_KEY = FLWSECK-TEST-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X
FLW_SECRET_HASH = flw_secret_hash_xxxxxxxxxxxxxxxx
Webhook URL = https://YOUR_PROJECT_ID.supabase.co/functions/v1/flutterwave_webhook
```

### For Production (Live)

```
FLW_SECRET_KEY = FLWSECK-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X (LIVE key)
FLW_SECRET_HASH = flw_secret_hash_xxxxxxxxxxxxxxxx (same as test)
Webhook URL = https://YOUR_PROJECT_ID.supabase.co/functions/v1/flutterwave_webhook (same)
```

---

## Security Best Practices

### ✅ DO:
- ✅ Keep secret keys in environment variables only
- ✅ Use TEST keys for development
- ✅ Switch to LIVE keys only when ready for production
- ✅ Rotate keys periodically
- ✅ Monitor webhook logs for suspicious activity

### ❌ DON'T:
- ❌ Never commit secret keys to Git
- ❌ Never share secret keys in chat/email
- ❌ Never hardcode keys in your Flutter app
- ❌ Never use LIVE keys for testing
- ❌ Never expose keys in client-side code

---

## Troubleshooting

### Issue: "FLW_SECRET_KEY not configured" error

**Solution**:
1. Check that you added the variable in Supabase Edge Functions settings
2. Verify the variable name is exactly `FLW_SECRET_KEY` (case-sensitive)
3. Redeploy the Edge Functions after adding the variable

### Issue: "Invalid signature" webhook error

**Solution**:
1. Check that `FLW_SECRET_HASH` matches the hash in Flutterwave Dashboard
2. Verify you copied the entire hash
3. Make sure there are no extra spaces

### Issue: "Webhook not receiving events"

**Solution**:
1. Verify webhook URL is correct in Flutterwave Dashboard
2. Check that Edge Function `flutterwave_webhook` is deployed
3. Test the webhook URL manually:
   ```bash
   curl -X POST https://YOUR_PROJECT_ID.supabase.co/functions/v1/flutterwave_webhook \
     -H "Content-Type: application/json" \
     -H "verif-hash: YOUR_SECRET_HASH" \
     -d '{"event":"test"}'
   ```

### Issue: Can't find API Keys in Flutterwave Dashboard

**Solution**:
1. Make sure you're logged into the correct account
2. Check if your account is verified (some features require verification)
3. Contact Flutterwave support if you still can't find it

---

## Visual Guide Summary

### Flutterwave Dashboard Navigation

```
Dashboard Home
    ↓
Settings (gear icon in sidebar)
    ↓
API / API Keys
    ↓
Test Section → Copy Secret Key
    ↓
Live Section → Copy Secret Key (for production)
```

### Webhook Setup

```
Dashboard Home
    ↓
Settings (gear icon in sidebar)
    ↓
Webhooks
    ↓
Add Webhook
    ↓
Enter URL: https://YOUR_PROJECT_ID.supabase.co/functions/v1/flutterwave_webhook
    ↓
Select Events: transfer.completed
    ↓
Save → Copy Secret Hash
```

### Supabase Configuration

```
Supabase Dashboard
    ↓
Select Project: My Leadership Quest
    ↓
Edge Functions (in sidebar)
    ↓
Manage secrets / Environment Variables
    ↓
Add: FLW_SECRET_KEY = FLWSECK-...
Add: FLW_SECRET_HASH = flw_secret_hash_...
    ↓
Save
```

---

## Next Steps

After setting up the API keys:

1. ✅ **Run Database Migration** (`WALLET_MVP_DATABASE_MIGRATION.sql`)
2. ✅ **Deploy Edge Functions** (4 functions)
3. ✅ **Test in Sandbox Mode** (using TEST keys)
4. ✅ **Switch to Live Keys** (when ready for production)

---

## Support

If you need help:

**Flutterwave Support**:
- Email: support@flutterwave.com
- Dashboard: https://dashboard.flutterwave.com
- Docs: https://developer.flutterwave.com/docs

**Supabase Support**:
- Dashboard: https://supabase.com/dashboard
- Docs: https://supabase.com/docs

---

## Summary Checklist

- [ ] Login to Flutterwave Dashboard
- [ ] Copy TEST Secret Key from API Settings
- [ ] Copy LIVE Secret Key from API Settings (for production)
- [ ] Create Webhook in Flutterwave
- [ ] Copy Webhook Secret Hash
- [ ] Find Supabase Project ID
- [ ] Add `FLW_SECRET_KEY` to Supabase Edge Functions
- [ ] Add `FLW_SECRET_HASH` to Supabase Edge Functions
- [ ] Verify webhook URL is correct
- [ ] Test configuration by invoking `flutterwave_get_banks`

---

**You're ready to proceed with the implementation! 🚀**


# How to Get Webhook Secret Hash - Updated Guide

## The Issue

Flutterwave's newer dashboard doesn't automatically generate a webhook secret hash when you create a webhook. The webhook fields might be empty or not show a secret hash.

---

## Solution: Generate Your Own Secret Hash

You have **3 options** to get a webhook secret hash:

---

## Option 1: Generate Your Own (Recommended - Fastest)

You can generate your own secure random string to use as the secret hash.

### Method A: Using PowerShell (Windows)

```powershell
# Generate a random 32-character hash
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

**Example output**:
```
aB3dE5fG7hI9jK1lM3nO5pQ7rS9tU1vW
```

### Method B: Using Online Generator

1. Go to: https://www.random.org/strings/
2. Set these options:
   - Number of strings: 1
   - Length: 32
   - Characters: Alphanumeric (a-z, A-Z, 0-9)
3. Click "Get Strings"
4. Copy the generated string

### Method C: Using Node.js/JavaScript

```javascript
// In browser console or Node.js
const crypto = require('crypto');
const hash = crypto.randomBytes(16).toString('hex');
console.log(hash);
```

**Example output**:
```
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
```

### Method D: Simple Manual String

Create your own random string (at least 20 characters):
```
mySecretHash2024LeadWallet123
```

**Important**: Make it random and secure! Don't use predictable patterns.

---

## Option 2: Use Flutterwave's Secret Hash Setting

Some Flutterwave accounts have a global webhook secret hash setting.

### Steps:

1. Go to **Flutterwave Dashboard**
2. Navigate to **Settings** → **Webhooks**
3. Look for **"Webhook Secret Hash"** or **"Hash"** field at the top
4. If you see a field, you can either:
   - **Copy the existing hash** (if one is shown)
   - **Enter your own hash** (paste a generated hash from Option 1)
5. Click **"Save"** or **"Update"**

**What it looks like**:
```
┌─────────────────────────────────────────────────────────┐
│ Webhook Settings                                         │
│                                                          │
│ Webhook Secret Hash                                      │
│ [_________________________________________________]      │
│                                                          │
│ This hash will be used to verify all webhook requests   │
│                                                          │
│ [ Save ]                                                 │
└─────────────────────────────────────────────────────────┘
```

---

## Option 3: Contact Flutterwave Support

If you can't find the webhook hash setting:

1. Email: **support@flutterwave.com**
2. Subject: "Need Webhook Secret Hash"
3. Message:
   ```
   Hi,
   
   I need to set up webhooks for my account but can't find where to 
   configure the webhook secret hash. Could you please help me:
   
   1. Enable webhook secret hash for my account
   2. Provide instructions on where to find/set it
   
   My account email: [your email]
   
   Thank you!
   ```

---

## How to Use Your Secret Hash

Once you have your secret hash (from any option above):

### Step 1: Save It Securely

Copy your secret hash and save it. Example:
```
aB3dE5fG7hI9jK1lM3nO5pQ7rS9tU1vW
```

### Step 2: Add to Supabase

1. Go to **Supabase Dashboard** → **Edge Functions** → **Manage Secrets**
2. Add new secret:
   - **Name**: `FLW_SECRET_HASH`
   - **Value**: Your secret hash (paste it)
3. Click **"Save"**

### Step 3: Configure in Flutterwave (If Possible)

If Flutterwave has a field to enter the hash:
1. Go to **Settings** → **Webhooks**
2. Enter your secret hash in the **"Webhook Secret Hash"** field
3. Click **"Save"**

If there's no field, that's okay! The hash is primarily used on your server side (Supabase) to verify incoming webhooks.

---

## How Webhook Verification Works

### With Secret Hash (Recommended)

```javascript
// In your webhook Edge Function
const signature = req.headers.get('verif-hash');
const secretHash = Deno.env.get('FLW_SECRET_HASH');

if (signature !== secretHash) {
  return new Response('Unauthorized', { status: 401 });
}
```

Flutterwave sends the hash in the `verif-hash` header, and you verify it matches your stored hash.

### Without Secret Hash (Alternative)

If Flutterwave doesn't support custom secret hashes on your account, you can verify webhooks by:

1. **Checking the source IP** (Flutterwave's IPs)
2. **Verifying transaction details** against your database
3. **Using transaction reference** to prevent duplicates

**Updated webhook code** (if no secret hash available):

```typescript
// Alternative verification without secret hash
const payload = await req.json();

// Verify it's a valid Flutterwave webhook structure
if (!payload.event || !payload.data) {
  return new Response('Invalid webhook', { status: 400 });
}

// Verify transaction exists in your database
const reference = payload.data.reference;
const withdrawal = await supabase
  .from('withdrawal_requests')
  .select('*')
  .eq('flutterwave_reference', reference)
  .single();

if (!withdrawal.data) {
  return new Response('Transaction not found', { status: 404 });
}

// Process the webhook...
```

---

## Recommended Approach

### For Development/Testing

1. **Generate your own hash** using Option 1 (PowerShell or online generator)
2. **Use a simple hash** like: `test_webhook_hash_2024`
3. **Add to Supabase** as `FLW_SECRET_HASH`
4. **Don't worry about Flutterwave configuration** - the hash is mainly for your server

### For Production

1. **Generate a strong random hash** (32+ characters)
2. **Add to Supabase** as `FLW_SECRET_HASH`
3. **If Flutterwave has a hash field**, enter the same hash there
4. **If not**, use the alternative verification method (checking transaction references)

---

## Quick Start: What to Do Right Now

### Step 1: Generate a Hash

Run this in PowerShell:
```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

**Copy the output**, for example:
```
K7mN2pQ4rS6tU8vW0xY2zA4bC6dE8fG0
```

### Step 2: Add to Supabase

1. Go to Supabase Dashboard
2. Edge Functions → Manage Secrets
3. Add:
   - Name: `FLW_SECRET_HASH`
   - Value: `K7mN2pQ4rS6tU8vW0xY2zA4bC6dE8fG0` (your generated hash)
4. Save

### Step 3: Update Webhook Code (Optional)

If Flutterwave doesn't send the `verif-hash` header, update the webhook Edge Function to use alternative verification:

```typescript
// Check if signature header exists
const signature = req.headers.get('verif-hash');
const secretHash = Deno.env.get('FLW_SECRET_HASH');

if (signature && secretHash) {
  // Verify signature if both exist
  if (signature !== secretHash) {
    return new Response('Unauthorized', { status: 401 });
  }
} else {
  // Alternative: Verify transaction reference exists in database
  const payload = await req.json();
  const reference = payload.data?.reference;
  
  if (!reference) {
    return new Response('Invalid webhook', { status: 400 });
  }
  
  // Verify reference exists in your database
  const { data: withdrawal } = await supabase
    .from('withdrawal_requests')
    .select('id')
    .eq('flutterwave_reference', reference)
    .single();
  
  if (!withdrawal) {
    return new Response('Transaction not found', { status: 404 });
  }
}

// Continue processing webhook...
```

---

## Testing Your Webhook

### Test Without Flutterwave

You can test your webhook locally:

```bash
curl -X POST https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/flutterwave_webhook \
  -H "Content-Type: application/json" \
  -H "verif-hash: K7mN2pQ4rS6tU8vW0xY2zA4bC6dE8fG0" \
  -d '{
    "event": "transfer.completed",
    "data": {
      "id": 12345,
      "reference": "MLQ-test-123",
      "status": "SUCCESSFUL",
      "amount": 500,
      "currency": "NGN"
    }
  }'
```

Replace:
- `hcvyumbkonrisrxbjnst` with your Supabase project ID
- `K7mN2pQ4rS6tU8vW0xY2zA4bC6dE8fG0` with your secret hash
- `MLQ-test-123` with an actual withdrawal reference from your database

---

## Summary

**The webhook secret hash is NOT required from Flutterwave's side**. You can:

1. ✅ **Generate your own hash** (recommended)
2. ✅ **Add it to Supabase** as `FLW_SECRET_HASH`
3. ✅ **Use it to verify webhooks** on your server
4. ✅ **Optionally add to Flutterwave** if they have a field for it

**The hash is primarily for YOUR server to verify incoming webhooks are legitimate.**

---

## What to Do Next

1. **Generate a hash** using PowerShell or online tool
2. **Add to Supabase** as `FLW_SECRET_HASH`
3. **Continue with the setup** - you're ready to proceed!
4. **Test the webhook** after deploying Edge Functions

You don't need to wait for Flutterwave to provide a hash. Generate your own and move forward! 🚀


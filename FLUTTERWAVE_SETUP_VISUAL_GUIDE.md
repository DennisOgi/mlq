# Flutterwave API Keys - Visual Setup Guide

## 📸 Step-by-Step with Visual Descriptions

This guide describes exactly what you'll see on each screen.

---

## Part 1: Getting Flutterwave API Keys

### Screen 1: Flutterwave Login Page

**URL**: https://dashboard.flutterwave.com

**What you'll see**:
```
┌─────────────────────────────────────────┐
│         FLUTTERWAVE LOGO                │
│                                         │
│  Email: [________________]              │
│  Password: [________________]           │
│                                         │
│  [ Login ]                              │
│                                         │
│  Don't have an account? Sign up         │
└─────────────────────────────────────────┘
```

**Action**: Enter your email and password, click "Login"

---

### Screen 2: Flutterwave Dashboard Home

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ FLUTTERWAVE                                    [Profile]│
│                                                          │
│ ┌─────────────┐                                         │
│ │ Dashboard   │  ← You are here                         │
│ │ Transactions│                                         │
│ │ Customers   │                                         │
│ │ Settlements │                                         │
│ │ ...         │                                         │
│ │ Settings ⚙️ │  ← Click here                          │
│ └─────────────┘                                         │
│                                                          │
│  Welcome back! Here's your overview...                  │
│  [Transaction stats, charts, etc.]                      │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "Settings" (gear icon) in the left sidebar

---

### Screen 3: Settings Menu

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Settings                                                 │
│                                                          │
│ ┌─────────────┐                                         │
│ │ General     │                                         │
│ │ API         │  ← Click here                          │
│ │ Webhooks    │                                         │
│ │ Team        │                                         │
│ │ Security    │                                         │
│ └─────────────┘                                         │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "API" or "API Keys"

---

### Screen 4: API Keys Page

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ API Keys                                                 │
│                                                          │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ TEST KEYS                                                │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                          │
│ Public Key (Test)                                        │
│ FLWPUBK-TEST-1234567890abcdef1234567890abcdef-X         │
│ [Copy] [Show]                                            │
│                                                          │
│ Secret Key (Test)                                        │
│ ••••••••••••••••••••••••••••••••••••••••••••            │
│ [Copy] [Show] ← Click "Show" first                      │
│                                                          │
│ Encryption Key (Test)                                    │
│ ••••••••••••••••••••••••••••••••••••••••••••            │
│ [Copy] [Show]                                            │
│                                                          │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ LIVE KEYS                                                │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                          │
│ Public Key (Live)                                        │
│ FLWPUBK-3458a6b1472c5d67e1f5e1ccc4be9598-X              │
│ [Copy] [Show]                                            │
│                                                          │
│ Secret Key (Live)                                        │
│ ••••••••••••••••••••••••••••••••••••••••••••            │
│ [Copy] [Show] ← Click "Show" first                      │
│                                                          │
│ Encryption Key (Live)                                    │
│ ••••••••••••••••••••••••••••••••••••••••••••            │
│ [Copy] [Show]                                            │
└─────────────────────────────────────────────────────────┘
```

**Actions**:
1. In **TEST KEYS** section:
   - Click "Show" next to Secret Key (Test)
   - Click "Copy" to copy the key
   - Save it: `FLWSECK-TEST-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X`

2. In **LIVE KEYS** section:
   - Click "Show" next to Secret Key (Live)
   - Click "Copy" to copy the key
   - Save it: `FLWSECK-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X`

---

## Part 2: Setting Up Webhook

### Screen 5: Webhooks Page

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Webhooks                                                 │
│                                                          │
│ Webhooks allow you to receive real-time notifications   │
│ about events in your Flutterwave account.               │
│                                                          │
│ [ + Add Webhook ]  ← Click here                         │
│                                                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ No webhooks configured yet                          │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "+ Add Webhook" button

---

### Screen 6: Create Webhook Form

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Create Webhook                                           │
│                                                          │
│ Webhook URL *                                            │
│ [_________________________________________________]      │
│                                                          │
│ Events to listen for *                                   │
│ ☐ All events                                            │
│ ☐ Charge events                                         │
│ ☑ Transfer events  ← Check this                         │
│   ☑ transfer.completed                                  │
│   ☑ transfer.failed                                     │
│ ☐ Refund events                                         │
│ ☐ Settlement events                                     │
│                                                          │
│ [ Cancel ]  [ Create Webhook ]                          │
└─────────────────────────────────────────────────────────┘
```

**Actions**:
1. In "Webhook URL" field, enter:
   ```
   https://hcvyumbkonrisrxbjnst.supabase.co/functions/v1/flutterwave_webhook
   ```
   (Replace `hcvyumbkonrisrxbjnst` with your Supabase project ID)

2. Check "Transfer events"
3. Make sure "transfer.completed" is checked
4. Click "Create Webhook"

---

### Screen 7: Webhook Created - Copy Secret Hash

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Webhook Created Successfully!                            │
│                                                          │
│ Your webhook has been created. Here are the details:    │
│                                                          │
│ Webhook URL:                                             │
│ https://hcvyumbkonrisrxbjnst.supabase.co/functions/...  │
│                                                          │
│ Secret Hash:                                             │
│ flw_secret_hash_1234567890abcdef                        │
│ [Copy] ← Click to copy                                  │
│                                                          │
│ ⚠️ Important: Save this secret hash securely.           │
│ You'll need it to verify webhook signatures.            │
│                                                          │
│ [ Done ]                                                 │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "Copy" to copy the Secret Hash, save it securely

---

## Part 3: Configuring Supabase

### Screen 8: Supabase Dashboard

**URL**: https://supabase.com/dashboard

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ SUPABASE                                        [Profile]│
│                                                          │
│ Projects                                                 │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ My Leadership Quest                                 │ │
│ │ hcvyumbkonrisrxbjnst                               │ │
│ │ [Open]  ← Click here                               │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "Open" on your project

---

### Screen 9: Project Dashboard

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ My Leadership Quest                                      │
│                                                          │
│ ┌─────────────┐                                         │
│ │ Home        │                                         │
│ │ Table Editor│                                         │
│ │ SQL Editor  │                                         │
│ │ Database    │                                         │
│ │ Auth        │                                         │
│ │ Storage     │                                         │
│ │ Edge Func...│  ← Click here                          │
│ │ Logs        │                                         │
│ │ Settings    │                                         │
│ └─────────────┘                                         │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "Edge Functions" in the left sidebar

---

### Screen 10: Edge Functions Page

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Edge Functions                                           │
│                                                          │
│ [ Manage secrets ] ← Click here                         │
│                                                          │
│ Functions:                                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ No functions deployed yet                           │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "Manage secrets" button

---

### Screen 11: Environment Variables / Secrets

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Edge Function Secrets                                    │
│                                                          │
│ [ + Add new secret ] ← Click here                       │
│                                                          │
│ Secrets:                                                 │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ No secrets configured yet                           │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "+ Add new secret"

---

### Screen 12: Add First Secret (FLW_SECRET_KEY)

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Add Secret                                               │
│                                                          │
│ Name *                                                   │
│ [_________________________________________________]      │
│                                                          │
│ Value *                                                  │
│ [_________________________________________________]      │
│                                                          │
│ [ Cancel ]  [ Add Secret ]                              │
└─────────────────────────────────────────────────────────┘
```

**Actions**:
1. In "Name" field, type: `FLW_SECRET_KEY`
2. In "Value" field, paste your Flutterwave Secret Key:
   ```
   FLWSECK-TEST-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X
   ```
3. Click "Add Secret"

---

### Screen 13: Add Second Secret (FLW_SECRET_HASH)

**Repeat the same process**:

1. Click "+ Add new secret" again
2. In "Name" field, type: `FLW_SECRET_HASH`
3. In "Value" field, paste your Webhook Secret Hash:
   ```
   flw_secret_hash_xxxxxxxxxxxxxxxx
   ```
4. Click "Add Secret"

---

### Screen 14: Secrets Configured

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Edge Function Secrets                                    │
│                                                          │
│ [ + Add new secret ]                                     │
│                                                          │
│ Secrets:                                                 │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ FLW_SECRET_KEY                                      │ │
│ │ FLWSECK-TEST-••••••••••••••••••••••••••••••••••-X  │ │
│ │ [Edit] [Delete]                                     │ │
│ │                                                     │ │
│ │ FLW_SECRET_HASH                                     │ │
│ │ flw_secret_hash_••••••••••••••••                   │ │
│ │ [Edit] [Delete]                                     │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**✅ Configuration Complete!**

---

## Part 4: Running Database Migration

### Screen 15: SQL Editor

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ SQL Editor                                               │
│                                                          │
│ [ + New query ]  ← Click here                           │
│                                                          │
│ Recent queries:                                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ (empty)                                             │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Action**: Click "+ New query"

---

### Screen 16: SQL Query Editor

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Untitled Query                                           │
│                                                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ -- Write your SQL here                              │ │
│ │                                                     │ │
│ │                                                     │ │
│ │                                                     │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                          │
│ [ Run ] (Ctrl+Enter)                                     │
└─────────────────────────────────────────────────────────┘
```

**Actions**:
1. Open file: `WALLET_MVP_DATABASE_MIGRATION.sql`
2. Copy ALL contents (Ctrl+A, Ctrl+C)
3. Paste into SQL Editor (Ctrl+V)
4. Click "Run" or press Ctrl+Enter

---

### Screen 17: Migration Success

**What you'll see**:
```
┌─────────────────────────────────────────────────────────┐
│ Query Results                                            │
│                                                          │
│ ✓ Success. No rows returned                             │
│                                                          │
│ Execution time: 1.2s                                     │
└─────────────────────────────────────────────────────────┘
```

**✅ Database Migration Complete!**

---

## Quick Visual Summary

### What You Need to Copy

```
┌─────────────────────────────────────────────────────────┐
│ FROM FLUTTERWAVE:                                        │
│                                                          │
│ 1. TEST Secret Key                                       │
│    FLWSECK-TEST-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X      │
│                                                          │
│ 2. LIVE Secret Key (for production)                     │
│    FLWSECK-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X           │
│                                                          │
│ 3. Webhook Secret Hash                                   │
│    flw_secret_hash_xxxxxxxxxxxxxxxx                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ ADD TO SUPABASE:                                         │
│                                                          │
│ Environment Variable 1:                                  │
│ Name:  FLW_SECRET_KEY                                    │
│ Value: FLWSECK-TEST-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-X  │
│                                                          │
│ Environment Variable 2:                                  │
│ Name:  FLW_SECRET_HASH                                   │
│ Value: flw_secret_hash_xxxxxxxxxxxxxxxx                 │
└─────────────────────────────────────────────────────────┘
```

---

## Navigation Flow Summary

### Flutterwave
```
Login → Dashboard → Settings → API → Copy Keys
                  → Settings → Webhooks → Create → Copy Hash
```

### Supabase
```
Login → Select Project → Edge Functions → Manage Secrets → Add Variables
                       → SQL Editor → New Query → Paste Migration → Run
```

---

## ✅ Completion Checklist

- [ ] Copied Flutterwave TEST Secret Key
- [ ] Copied Flutterwave LIVE Secret Key
- [ ] Created Webhook in Flutterwave
- [ ] Copied Webhook Secret Hash
- [ ] Added `FLW_SECRET_KEY` to Supabase
- [ ] Added `FLW_SECRET_HASH` to Supabase
- [ ] Ran database migration in Supabase
- [ ] Verified tables created successfully

---

**All set! Ready to deploy Edge Functions next! 🚀**


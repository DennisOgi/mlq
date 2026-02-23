# Payment Troubleshooting Guide

## Issue 1: Naira Symbol Not Displaying ✅ FIXED

### Problem
The Naira symbol (₦) was showing as an unknown character in the app.

### Root Cause
- Incorrect Unicode escape sequence usage (`\u20A6` vs `\u20a6`)
- Font rendering issues with Unicode characters

### Solution Applied
- Updated all currency displays to use the proper Unicode character: `\u20a6`
- Fixed in the following files:
  - `lib/screens/subscription/upgrade_subscription_screen.dart`
  - `lib/screens/subscription/subscription_management_screen.dart`

### Files Already Correct
- `lib/screens/shop/shop_screen.dart` - Already using correct symbol
- `lib/screens/onboarding/onboarding_screen.dart` - Already using correct symbol

---

## Issue 2: Payment Declined - Insufficient Funds ⚠️ REQUIRES ACTION

### Problem
Payments are being declined by Flutterwave with "insufficient funds" error despite having money in the account.

### Common Causes

#### 1. **Test Mode vs Live Mode**
- **Check**: Are you using test API keys or live API keys?
- **Location**: Supabase `internal_secrets` table, key: `FLW_SECRET_KEY`
- **Test Keys**: Start with `FLWSECK_TEST-`
- **Live Keys**: Start with `FLWSECK-`

**Action Required:**
```sql
-- Check your current key type in Supabase
SELECT key, LEFT(value, 15) as key_prefix 
FROM internal_secrets 
WHERE key = 'FLW_SECRET_KEY';
```

#### 2. **Card Not Enabled for Online Transactions**
Many Nigerian banks disable online transactions by default for security.

**Solutions:**
- Call your bank to enable online/international transactions
- Use your bank's mobile app to enable online transactions
- Some banks require you to set daily transaction limits

#### 3. **Minimum Transaction Amount**
Some cards have minimum transaction amounts for online payments.

**Current Pricing:**
- Premium Monthly: ₦100 (test amount)
- Premium Quarterly: ₦250
- Premium Yearly: ₦500

**Action:** Try with a higher amount if ₦100 fails.

#### 4. **Card Verification Required**
Some cards need to be verified before they can be used online.

**Solutions:**
- Complete your bank's card verification process
- Try using a different card
- Use bank transfer or USSD as alternative payment methods

#### 5. **Daily Transaction Limit Exceeded**
Your card might have reached its daily transaction limit.

**Solutions:**
- Wait 24 hours and try again
- Increase your daily limit through your bank
- Use a different card

### Enhanced Error Messages ✅ IMPLEMENTED

The app now provides detailed guidance when payments fail:

```dart
'Payment declined due to insufficient funds. Please:
1. Ensure your card has enough balance
2. Check if your card is enabled for online transactions
3. Try a different card or payment method
4. Contact your bank if issue persists'
```

### Alternative Payment Methods ✅ ENABLED

The app now supports multiple payment options:
- **Card** (Visa, Mastercard, Verve)
- **Bank Transfer**
- **USSD**

Users can select their preferred method during checkout.

---

## Testing Recommendations

### For Development/Testing:
1. **Use Flutterwave Test Mode:**
   - Get test API keys from Flutterwave Dashboard
   - Use test card numbers provided by Flutterwave
   - Test cards: https://developer.flutterwave.com/docs/integration-guides/testing-helpers

### For Production:
1. **Verify Live API Keys:**
   ```sql
   -- Update to live keys in Supabase
   UPDATE internal_secrets 
   SET value = 'FLWSECK-your-live-secret-key'
   WHERE key = 'FLW_SECRET_KEY';
   ```

2. **Test with Real Card:**
   - Start with small amounts (₦100-500)
   - Ensure card is enabled for online transactions
   - Have sufficient balance + buffer for fees

3. **Monitor Flutterwave Dashboard:**
   - Check transaction logs
   - Review decline reasons
   - Monitor webhook deliveries

---

## Debugging Steps

### 1. Check Console Logs
Look for these key indicators:
```
🔑 [FlutterwaveService] Initializing payment...
🔑 Amount: 100.0
🔑 Currency: NGN
✅ [FlutterwaveService] Payment link generated
```

### 2. Check Payment Attempt in Database
```sql
SELECT * FROM payment_attempts 
WHERE user_id = 'your-user-id'
ORDER BY created_at DESC 
LIMIT 5;
```

### 3. Verify Flutterwave Webhook
```sql
SELECT * FROM payment_webhooks 
ORDER BY created_at DESC 
LIMIT 10;
```

### 4. Check Transaction Status
```sql
SELECT 
  pa.tx_ref,
  pa.amount,
  pa.status,
  pa.created_at,
  pw.event_type,
  pw.status as webhook_status
FROM payment_attempts pa
LEFT JOIN payment_webhooks pw ON pa.tx_ref = pw.tx_ref
WHERE pa.user_id = 'your-user-id'
ORDER BY pa.created_at DESC;
```

---

## User Instructions

### If Payment Fails:

1. **Check Your Card:**
   - Ensure sufficient balance (amount + ₦50 for fees)
   - Verify card is not expired
   - Confirm card is enabled for online transactions

2. **Contact Your Bank:**
   - Ask to enable online/international transactions
   - Verify daily transaction limit
   - Confirm no blocks on the card

3. **Try Alternative Methods:**
   - Use bank transfer instead of card
   - Try USSD payment option
   - Use a different card

4. **Still Having Issues?**
   - Check your subscription status (it might have succeeded)
   - Wait 5 minutes and check again (webhook delay)
   - Contact support with transaction reference

---

## Support Contact

For payment issues that persist:
1. Note your transaction reference (shown in error message)
2. Take a screenshot of the error
3. Contact support with:
   - User email
   - Transaction reference
   - Error message
   - Payment method attempted
   - Amount

---

## Recent Changes

### ✅ Fixed (Current Update):
1. Naira symbol display corrected
2. Added multiple payment options (card, transfer, USSD)
3. Enhanced error messages with actionable guidance
4. Better debugging logs
5. Improved user feedback

### 🔄 Recommended Next Steps:
1. Verify API keys (test vs live)
2. Test with Flutterwave test cards
3. Enable webhook monitoring
4. Add payment retry logic
5. Implement payment status polling

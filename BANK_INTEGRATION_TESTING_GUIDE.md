# Bank Integration Testing Guide

## Quick Test Checklist

### ✅ **Test 1: App Launches Successfully**
- [ ] App opens without crashing
- [ ] Home screen loads
- [ ] No error dialogs appear

**Expected**: App should load normally with all existing features working.

---

### ✅ **Test 2: Wallet Dashboard Loads**
1. Navigate to wallet (tap wallet card on home screen or use navigation)
2. Check that wallet dashboard opens
3. Look for sandbox mode banner (yellow banner at top)

**Expected**: 
- Wallet dashboard opens
- Yellow "Sandbox Mode" banner visible
- Balance displays correctly
- All existing features work (transactions, savings goals)

---

### ✅ **Test 3: Bank Setup Flow (New Feature)**

#### Step 1: Start Setup
1. In wallet dashboard, look for "Activate LeadWallet!" card
2. Tap "Start Setup →" button

**Expected**: Bank setup screen opens with:
- Bank icon at top
- "Give Your Child a LeadWallet!" title
- Three info cards (Safe & Secure, Parent Controlled, Learn to Save)
- Setup steps (1, 2, 3)
- "Start Setup" button at bottom

#### Step 2: BVN Verification
1. Tap "Start Setup" button
2. BVN verification screen opens

**Expected**: Form with:
- Yellow sandbox mode banner at top
- "Parent/Guardian Verification" title
- Three input fields:
  - Your Full Name
  - Bank Verification Number (BVN)
  - Phone Number
- Privacy notice (blue box)
- Terms checkbox
- "Verify & Create Account" button

#### Step 3: Fill Form
1. Enter any name (e.g., "John Doe")
2. Enter any 11 digits for BVN (e.g., "12345678901")
3. Enter phone number (e.g., "08012345678")
4. Check the terms checkbox
5. Tap "Verify & Create Account"

**Expected**:
- Loading indicator appears
- After 2-3 seconds, success dialog appears
- Dialog shows:
  - Green checkmark icon
  - "LeadWallet Activated!" title
  - Sandbox mode notice with mock account number
  - "Open Wallet" button

#### Step 4: Return to Wallet
1. Tap "Open Wallet" button

**Expected**:
- Returns to wallet dashboard
- Sandbox banner now shows mock account number
- Balance still displays correctly
- All features still work

---

### ✅ **Test 4: Existing Features Still Work**

#### Transactions
- [ ] Can view transaction history
- [ ] Transactions display correctly

#### Savings Goals
- [ ] Can view savings goals
- [ ] Can create new savings goal
- [ ] Can allocate funds to goal

#### Admin Rewards (if you have admin access)
- [ ] Can create reward disbursement
- [ ] Can approve disbursement
- [ ] Student receives credit in wallet

---

### ✅ **Test 5: Database Migration (Optional)**

If you want to test with real database:

1. Open Supabase SQL Editor
2. Run the migration:
   ```sql
   -- Copy contents from BANK_INTEGRATION_DATABASE_MIGRATION.sql
   ```
3. Verify tables created:
   ```sql
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'profiles' 
   AND column_name LIKE 'bank_%';
   ```

**Expected**: Should see new columns:
- bank_account_id
- bank_account_number
- bank_account_name
- bank_provider
- guardian_bvn_verified
- account_setup_completed_at
- is_sandbox_mode

---

## Troubleshooting

### Issue: App crashes on launch
**Solution**: 
1. Check for compilation errors: `flutter analyze`
2. Clean and rebuild: `flutter clean && flutter pub get && flutter run`

### Issue: Wallet dashboard doesn't open
**Solution**:
1. Check if route is registered in main.dart
2. Check console for navigation errors

### Issue: Bank setup button doesn't appear
**Solution**:
1. Check wallet_status in database (should be 'inactive')
2. Verify user doesn't already have bank_account_id

### Issue: BVN verification fails
**Solution**:
1. Ensure BVN is exactly 11 digits
2. Check console for error messages
3. Verify BankIntegrationService is imported correctly

### Issue: Sandbox banner doesn't show
**Solution**:
1. Check is_sandbox_mode in database (should be true)
2. Verify _isSandboxMode variable is set in wallet dashboard state

---

## Console Logs to Look For

### Successful Flow:
```
🏦 [SANDBOX] Verifying BVN: 123********
🏦 [SANDBOX] Creating guardian sub-account for: [Student Name]
🏦 [SANDBOX] Account created: [Account Number]
✅ Bank deposit successful: ₦[Amount]
```

### Error Indicators:
```
❌ Error creating guardian sub-account: [Error]
❌ Error fetching balance: [Error]
❌ Error crediting wallet: [Error]
```

---

## Expected Behavior Summary

### ✅ **What Should Work:**
1. App launches normally
2. All existing wallet features work
3. Sandbox mode banner appears
4. Bank setup flow is accessible
5. BVN verification accepts any 11 digits
6. Account creation succeeds with mock data
7. Success dialog appears
8. Returns to wallet with account info
9. Admin can still credit wallets
10. Transactions and savings goals work

### ⚠️ **What's Mock/Placeholder:**
1. BVN verification (format check only, no real API)
2. Account creation (generates mock account number)
3. Balance inquiry (reads from database)
4. Deposits (updates database directly)
5. All bank API calls are simulated

### 🔄 **What Will Change in Production:**
1. Real BVN verification via bank API
2. Real account creation with bank
3. Real balance sync from bank
4. Real deposits via bank transfer API
5. Webhook handling for async updates

---

## Quick Verification Commands

### Check if new files exist:
```bash
ls lib/services/bank_integration_service.dart
ls lib/screens/wallet/bank_setup_screen.dart
ls lib/screens/wallet/bvn_verification_screen.dart
```

### Check for compilation errors:
```bash
flutter analyze
```

### Check diagnostics:
```bash
flutter doctor
```

### View logs in real-time:
```bash
flutter logs
```

---

## Success Criteria

✅ **Implementation is successful if:**
1. App launches without errors
2. Wallet dashboard opens and shows sandbox banner
3. Bank setup flow is accessible and completes successfully
4. Mock account is created and displayed
5. All existing features continue to work
6. No breaking changes to current functionality
7. Code is ready for real bank API integration

---

## Next Steps After Testing

1. ✅ Verify all tests pass
2. ✅ Document any issues found
3. ✅ Run database migration in dev environment
4. ✅ Test with multiple users
5. ⏳ Wait for bank partnership finalization
6. ⏳ Replace mock implementations with real API
7. ⏳ Test in bank's sandbox environment
8. ⏳ Deploy to production

---

**Testing Date**: _____________  
**Tester**: _____________  
**Environment**: Dev / Staging / Production  
**Result**: Pass / Fail  
**Notes**: _____________

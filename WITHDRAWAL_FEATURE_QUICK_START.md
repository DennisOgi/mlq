# LeadWallet Withdrawal Feature - Quick Start Guide

## 🎉 Status: UI Complete & Ready for Testing!

---

## What's Ready

### ✅ Backend Infrastructure (Complete)
- Database schema deployed
- Edge Functions deployed and tested
- Flutterwave API integration working
- Environment variables configured

### ✅ Flutter UI Screens (Complete)
- Bank Account Setup Screen
- Withdrawal Request Screen
- Withdrawal History Screen
- Wallet Dashboard integration

---

## How to Test Right Now

### 1. Run the App

```bash
cd my_leadership_quest
flutter run
```

### 2. Navigate to LeadWallet

From the app:
1. Open the main menu
2. Tap "LeadWallet" or navigate to `/wallet`
3. You'll see the wallet dashboard

### 3. Test Withdrawal Flow

#### Step 1: Click "Withdraw" Button
- Gold button in the quick actions row
- Opens the Withdrawal Request Screen

#### Step 2: Add Bank Account (First Time)
- Click "Add Bank Account" card
- Opens Bank Account Setup Screen
- Select a bank from dropdown (597 Nigerian banks)
- Enter account number: `0690000031` (test account)
- Click "Validate Account"
- See account name: "Forrest Green"
- Click "Save Bank Account"

#### Step 3: Request Withdrawal
- Enter amount (e.g., 500)
- Review limits and processing time
- Click "Submit Withdrawal Request"
- See success message

#### Step 4: View History
- Click "Requests" button on dashboard
- Opens Withdrawal History Screen
- See your withdrawal request with status

---

## Test Accounts

### Flutterwave Test Bank Account
```
Bank: Access Bank (044)
Account Number: 0690000031
Account Name: Forrest Green
Status: Success (will validate successfully)
```

### Flutterwave Test Bank Account (Failure)
```
Bank: Access Bank (044)
Account Number: 0690000032
Account Name: N/A
Status: Failure (will fail validation)
```

---

## Current Limitations (To Be Implemented)

### 1. Bank Account Storage
**Current**: Bank account is not saved to database  
**Next**: Add bank account storage to profiles or separate table

**Quick Fix**:
```dart
// In withdrawal_bank_setup_screen.dart, _saveAccount() method
// TODO: Save to database
await _client.from('profiles').update({
  'bank_code': _selectedBank!['code'],
  'bank_name': _selectedBank!['name'],
  'account_number': _accountNumberController.text,
  'account_name': _accountName,
}).eq('id', userId);
```

### 2. Bank Account Loading
**Current**: Uses mock data  
**Next**: Load from database

**Quick Fix**:
```dart
// In withdrawal_request_screen.dart, _loadData() method
// TODO: Load saved bank account from database
final response = await _client
    .from('profiles')
    .select('bank_code, bank_name, account_number, account_name')
    .eq('id', user.id)
    .single();

if (response['bank_code'] != null) {
  bankAccount = {
    'bank_code': response['bank_code'],
    'bank_name': response['bank_name'],
    'account_number': response['account_number'],
    'account_name': response['account_name'],
  };
}
```

### 3. Parent Consent Check
**Current**: Checks consent but doesn't enforce  
**Next**: Add parent consent flow

**Already Implemented**: The service checks consent status, just needs UI flow

---

## Next Steps (Priority Order)

### Phase 1: Database Integration (2 hours)

1. **Add Bank Account Fields to Profiles Table**
```sql
ALTER TABLE profiles
ADD COLUMN bank_code VARCHAR(10),
ADD COLUMN bank_name VARCHAR(100),
ADD COLUMN account_number VARCHAR(20),
ADD COLUMN account_name VARCHAR(100);
```

2. **Update Save Bank Account**
- Modify `withdrawal_bank_setup_screen.dart`
- Save to database instead of just returning

3. **Update Load Bank Account**
- Modify `withdrawal_request_screen.dart`
- Load from database instead of mock data

### Phase 2: Test End-to-End (1 hour)

1. **Test Bank Account Setup**
   - Add bank account
   - Validate account
   - Save to database
   - Verify saved

2. **Test Withdrawal Request**
   - Load saved bank account
   - Submit withdrawal request
   - Verify in database
   - Check status

3. **Test Withdrawal History**
   - View withdrawal requests
   - Check status badges
   - Cancel pending request
   - Refresh list

### Phase 3: Parent Consent Flow (2 hours)

1. **Check Consent Status**
   - Already implemented in service
   - Add UI to request consent

2. **Request Parent Consent**
   - Email to parent
   - Consent link
   - Approval flow

3. **Handle Consent Response**
   - Update status
   - Enable withdrawals

### Phase 4: Admin Dashboard (4 hours)

1. **Create Admin Withdrawal Screen**
   - List pending withdrawals
   - Student details
   - Approve/reject buttons

2. **Process Withdrawals**
   - Call `processWithdrawal()` method
   - Already implemented in service
   - Just needs UI

3. **Monitor Status**
   - Track processing
   - View completed
   - Handle failures

### Phase 5: Production Testing (1 week)

1. **Sandbox Testing**
   - Test with Flutterwave sandbox
   - Test all scenarios
   - Test webhook updates

2. **Pilot Program**
   - 10-20 students
   - Small amounts (₦100-500)
   - Monitor closely

3. **Full Launch**
   - Switch to LIVE keys
   - Enable for all users
   - Monitor and iterate

---

## Quick Commands

### Run App
```bash
flutter run
```

### Hot Reload
```
Press 'r' in terminal
```

### Check for Errors
```bash
flutter analyze
```

### Format Code
```bash
flutter format lib/
```

---

## File Locations

### New Screens
```
lib/screens/wallet/
├── withdrawal_bank_setup_screen.dart      (350 lines)
├── withdrawal_request_screen.dart         (450 lines)
└── withdrawal_history_screen.dart         (380 lines)
```

### Updated Files
```
lib/screens/wallet/
└── wallet_dashboard_screen.dart           (updated quick actions)
```

### Services
```
lib/services/
└── flutterwave_wallet_service.dart        (already exists)
```

### Database
```
Database: withdrawal_requests table        (already created)
Edge Functions: 4 functions                (already deployed)
```

---

## Testing Checklist

### UI Testing (No Backend Required)
- [x] Navigate to wallet dashboard
- [x] Click "Withdraw" button
- [x] See withdrawal request screen
- [x] Click "Add Bank Account"
- [x] See bank account setup screen
- [x] Select bank from dropdown
- [x] Enter account number
- [x] Click "Validate Account"
- [x] See loading indicator
- [x] See account name (or error)
- [x] Click "Save Bank Account"
- [x] Return to withdrawal screen
- [x] See saved bank account
- [x] Enter withdrawal amount
- [x] See limits info
- [x] Click "Submit Withdrawal Request"
- [x] See success message
- [x] Click "Requests" button
- [x] See withdrawal history screen
- [x] See withdrawal cards
- [x] See status badges

### Backend Integration Testing (Requires Database)
- [ ] Save bank account to database
- [ ] Load bank account from database
- [ ] Create withdrawal request in database
- [ ] Load withdrawal requests from database
- [ ] Cancel withdrawal request
- [ ] Update withdrawal status

### End-to-End Testing (Requires Full Setup)
- [ ] Complete withdrawal flow
- [ ] Parent approval
- [ ] Admin approval
- [ ] Flutterwave transfer
- [ ] Webhook update
- [ ] Status change to "Paid"
- [ ] Money in bank account

---

## Troubleshooting

### Issue: Banks Not Loading
**Cause**: Edge Function not deployed or API key issue  
**Fix**: Check Edge Function logs in Supabase Dashboard

### Issue: Account Validation Fails
**Cause**: Invalid account number or Flutterwave API issue  
**Fix**: Use test account 0690000031 (Access Bank)

### Issue: Withdrawal Request Fails
**Cause**: Database table not created or RLS policy issue  
**Fix**: Check `withdrawal_requests` table exists

### Issue: Bank Account Not Saved
**Cause**: Not implemented yet (returns data only)  
**Fix**: Implement database save (see Phase 1 above)

---

## Support

### Documentation
- `WITHDRAWAL_UI_SCREENS_COMPLETE.md` - Complete UI documentation
- `LEADWALLET_MVP_READY.md` - Backend infrastructure status
- `EDGE_FUNCTIONS_DEPLOYED.md` - Edge Functions deployment
- `FLUTTERWAVE_INTEGRATION_COMPLETE.md` - Full integration guide

### Dashboards
- **Supabase**: https://supabase.com/dashboard/project/hcvyumbkonrisrxbjnst
- **Flutterwave**: https://dashboard.flutterwave.com

### Test Data
- **Test Account**: 0690000031 (Access Bank)
- **Test Amount**: ₦500 - ₦10,000
- **Test Bank Code**: 044 (Access Bank)

---

## Timeline

### Completed ✅
- [x] Backend infrastructure (Day 1)
- [x] Edge Functions deployment (Day 1)
- [x] Flutter UI screens (Day 2)

### This Week ⏳
- [ ] Database integration (2 hours)
- [ ] End-to-end testing (1 hour)
- [ ] Parent consent flow (2 hours)
- [ ] Admin dashboard (4 hours)

### Next Week ⏳
- [ ] Sandbox testing (2 days)
- [ ] Pilot program (1 week)
- [ ] Production launch (ongoing)

---

## 🎉 Success!

The LeadWallet withdrawal feature UI is complete and ready for testing!

**Next Action**: Test the UI flow in the app, then implement database integration.

**Estimated Time to Full Functionality**: 3-5 days

---

**Happy Testing! 🚀**

# LeadWallet Investigation Report

## Executive Summary

LeadWallet is a **real-money digital wallet system** designed for students to earn, save, and manage actual Nigerian Naira (₦) through the My Leadership Quest platform. It's currently in **sandbox mode** with mock bank integration, ready for production bank API integration.

---

## 🎯 Purpose & Vision

### Primary Purpose
LeadWallet transforms virtual achievements into **real financial rewards** for students, teaching:
- Financial literacy through practical experience
- Savings habits with goal-based saving
- Reward for educational achievements
- Real-world money management skills

### Target Users
- **Students (13-19 years)**: Primary wallet holders
- **Parents**: Provide consent for wallet activation
- **School Administrators**: Approve reward disbursements
- **Challenge Sponsors**: Fund premium challenge rewards

---

## 🏗️ Current Architecture

### System Components

#### 1. **Wallet Service** (`wallet_service.dart`)
**Core Functions**:
- Balance management (credit/debit operations)
- Transaction history tracking
- Savings goals management
- Parent consent workflow
- Admin reward disbursements

**Key Methods**:
```dart
- getWalletBalance(userId) → double
- creditWallet() → Adds money to wallet
- debitWallet() → Removes money from wallet
- getTransactionHistory() → List of transactions
- createSavingsGoal() → Create savings target
- allocateToSavingsGoal() → Move money to savings
- requestWalletActivation() → Parent consent flow
```

#### 2. **Bank Integration Service** (`bank_integration_service.dart`)
**Purpose**: Interface with real bank APIs (currently mock/sandbox)

**Features**:
- Account creation and management
- Balance synchronization
- Transaction processing
- Sandbox mode for testing

**Status**: 🟡 Mock implementation ready, awaiting real bank API integration

#### 3. **Database Schema**

**Main Tables**:

**a) `profiles` table** (wallet fields):
```sql
- wallet_balance: NUMERIC (current balance in NGN)
- wallet_status: TEXT (inactive, pending_consent, active, frozen)
- wallet_activated_at: TIMESTAMPTZ
- bank_account_id: TEXT
- bank_provider: TEXT
- is_sandbox_mode: BOOLEAN
```

**b) `wallet_transactions` table**:
```sql
- id: UUID
- user_id: UUID
- amount: NUMERIC (positive = credit, negative = debit)
- balance_after: NUMERIC
- type: TEXT (reward, savings_deposit, savings_withdrawal, payout, adjustment)
- status: TEXT (pending, completed, failed, reversed)
- description: TEXT
- reference_type: TEXT
- reference_id: UUID
- approved_by: UUID
- bank_transaction_id: TEXT
- created_at: TIMESTAMPTZ
```

**c) `savings_goals` table**:
```sql
- id: UUID
- user_id: UUID
- title: TEXT
- target_amount: NUMERIC
- current_amount: NUMERIC
- icon: TEXT (emoji)
- status: TEXT (active, completed, cancelled)
- completed_at: TIMESTAMPTZ
```

**d) `wallet_consent` table**:
```sql
- id: UUID
- student_id: UUID
- parent_email: TEXT
- consent_type: TEXT (wallet_activation, payout_approval)
- consent_token: TEXT (unique)
- status: TEXT (pending, approved, rejected, expired)
- approved_at: TIMESTAMPTZ
- ip_address: TEXT
- expires_at: TIMESTAMPTZ (72 hours default)
```

**e) `reward_disbursements` table**:
```sql
- id: UUID
- student_id: UUID
- amount: NUMERIC
- reason: TEXT
- challenge_id: UUID (optional)
- status: TEXT (pending_approval, approved, processing, completed, failed, rejected)
- approved_by: UUID
- approved_at: TIMESTAMPTZ
- disbursed_at: TIMESTAMPTZ
- bank_reference: TEXT
```

**f) `wallet_audit_log` table**:
```sql
- id: UUID
- actor_id: UUID
- action: TEXT
- target_user_id: UUID
- amount: NUMERIC
- metadata: JSONB
- created_at: TIMESTAMPTZ
```

#### 4. **Database RPCs** (Secure Functions)

**a) `credit_wallet`**:
```sql
Parameters:
- p_user_id: UUID
- p_amount: NUMERIC
- p_description: TEXT
- p_type: TEXT
- p_reference_type: TEXT
- p_reference_id: UUID
- p_approved_by: UUID

Returns: {success: boolean, new_balance: numeric}
```

**b) `debit_wallet`**:
```sql
Parameters:
- p_user_id: UUID
- p_amount: NUMERIC
- p_description: TEXT
- p_type: TEXT
- p_reference_type: TEXT
- p_reference_id: UUID

Returns: {success: boolean, new_balance: numeric}
```

**c) `allocate_to_savings_goal`**:
```sql
Parameters:
- p_user_id: UUID
- p_goal_id: UUID
- p_amount: NUMERIC

Returns: {success: boolean}
```

**d) `sync_balance_from_bank`**:
```sql
Parameters:
- p_user_id: UUID
- p_bank_balance: NUMERIC

Returns: {success: boolean}
```

---

## 💰 How Students Earn Money

### Revenue Sources

1. **Challenge Completion**
   - Premium challenges offer real cash rewards
   - Sponsored by organizations/companies
   - Rewards range from ₦500 - ₦50,000+
   - Admin approval required before disbursement

2. **Achievement Milestones**
   - Completing X courses
   - Maintaining streaks
   - Reaching XP milestones
   - Badge achievements

3. **Community Contributions**
   - Creating popular courses
   - Helping other students
   - Content creation

4. **Monthly Competitions**
   - Top performers on leaderboard
   - School-wide competitions
   - Subject-specific contests

### Earning Flow
```
Student completes challenge
    ↓
Admin reviews and approves
    ↓
Reward disbursement created (pending_approval)
    ↓
Admin approves disbursement
    ↓
credit_wallet RPC called
    ↓
Money added to student's wallet
    ↓
Transaction recorded
    ↓
(Future) Synced to bank account
```

---

## 🏦 Current vs Future State

### Current State (Sandbox Mode)
- ✅ Full wallet UI implemented
- ✅ Transaction tracking working
- ✅ Savings goals functional
- ✅ Parent consent workflow ready
- ✅ Admin disbursement system ready
- ✅ Mock bank integration for testing
- ⚠️ No real money movement yet
- ⚠️ Sandbox mode active

### Future State (Production)
- 🔄 Real bank API integration
- 🔄 Actual money deposits to student accounts
- 🔄 Withdrawal to bank accounts
- 🔄 Parent consent email automation
- 🔄 Automated balance synchronization
- 🔄 Real-time transaction notifications

---

## 🔗 Flutterwave Integration Strategy

### Current Flutterwave Usage
**Purpose**: Subscription payments and coin purchases
- Users pay for premium subscriptions
- Users buy virtual coins
- Payment flows through Flutterwave
- Money goes to MLQ business account

### Proposed Flutterwave-Wallet Integration

#### Option 1: Flutterwave as Wallet Backend (Recommended)

**How It Works**:
1. Each student gets a **Flutterwave subaccount**
2. Rewards are transferred to their subaccount
3. Students can withdraw to their bank account
4. Flutterwave handles all banking complexity

**Implementation**:

**Step 1: Create Subaccounts**
```dart
// When wallet is activated
Future<bool> createFlutterwaveSubaccount(String userId) async {
  final user = await getUser(userId);
  
  final response = await http.post(
    Uri.parse('https://api.flutterwave.com/v3/subaccounts'),
    headers: {
      'Authorization': 'Bearer $FLW_SECRET_KEY',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'account_bank': user.bankCode,
      'account_number': user.accountNumber,
      'business_name': '${user.name} - MLQ Wallet',
      'business_email': user.email,
      'business_contact': user.phone,
      'business_mobile': user.phone,
      'country': 'NG',
      'split_type': 'flat', // or 'percentage'
      'split_value': 0, // MLQ takes 0% (or small fee)
    }),
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Save subaccount_id to database
    await saveSubaccountId(userId, data['data']['subaccount_id']);
    return true;
  }
  return false;
}
```

**Step 2: Credit Wallet via Transfer**
```dart
// When admin approves reward
Future<bool> creditWalletViaFlutterwave({
  required String userId,
  required double amount,
  required String description,
}) async {
  final subaccountId = await getSubaccountId(userId);
  
  final response = await http.post(
    Uri.parse('https://api.flutterwave.com/v3/transfers'),
    headers: {
      'Authorization': 'Bearer $FLW_SECRET_KEY',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'account_bank': 'flutterwave', // Internal transfer
      'account_number': subaccountId,
      'amount': amount,
      'narration': description,
      'currency': 'NGN',
      'reference': generateUniqueRef(),
      'callback_url': 'https://your-api.com/webhook/transfer',
      'debit_currency': 'NGN',
    }),
  );
  
  if (response.statusCode == 200) {
    // Update local database
    await creditWallet(
      userId: userId,
      amount: amount,
      description: description,
      type: 'reward',
    );
    return true;
  }
  return false;
}
```

**Step 3: Withdrawal to Bank**
```dart
// When student requests withdrawal
Future<bool> withdrawToBank({
  required String userId,
  required double amount,
}) async {
  final user = await getUser(userId);
  
  // Check parent consent for payout
  final consentStatus = await checkPayoutConsent(userId);
  if (consentStatus != 'approved') {
    return false; // Require parent approval
  }
  
  final response = await http.post(
    Uri.parse('https://api.flutterwave.com/v3/transfers'),
    headers: {
      'Authorization': 'Bearer $FLW_SECRET_KEY',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'account_bank': user.bankCode,
      'account_number': user.accountNumber,
      'amount': amount,
      'narration': 'MLQ Wallet Withdrawal',
      'currency': 'NGN',
      'reference': generateUniqueRef(),
      'callback_url': 'https://your-api.com/webhook/transfer',
      'debit_currency': 'NGN',
    }),
  );
  
  if (response.statusCode == 200) {
    // Debit local wallet
    await debitWallet(
      userId: userId,
      amount: amount,
      description: 'Withdrawal to bank',
      type: 'payout',
    );
    return true;
  }
  return false;
}
```

**Advantages**:
- ✅ Flutterwave handles all banking complexity
- ✅ Built-in fraud protection
- ✅ Automatic compliance with CBN regulations
- ✅ Real-time balance updates
- ✅ Easy withdrawals
- ✅ Transaction history from Flutterwave
- ✅ No need for separate bank API integration

**Costs**:
- Transfer fees: ₦10.75 per transfer (Flutterwave standard)
- Can be absorbed by MLQ or deducted from rewards

#### Option 2: Flutterwave for Payouts Only

**How It Works**:
1. Wallet balance stored in database
2. When student withdraws, use Flutterwave Transfer API
3. Simpler but requires manual balance management

**Implementation**:
```dart
// Withdrawal only
Future<bool> payoutViaFlutterwave({
  required String userId,
  required double amount,
}) async {
  // Check wallet balance
  final balance = await getWalletBalance(userId);
  if (balance < amount) return false;
  
  // Check parent consent
  final consent = await checkPayoutConsent(userId);
  if (consent != 'approved') return false;
  
  final user = await getUser(userId);
  
  // Initiate transfer
  final response = await http.post(
    Uri.parse('https://api.flutterwave.com/v3/transfers'),
    headers: {
      'Authorization': 'Bearer $FLW_SECRET_KEY',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'account_bank': user.bankCode,
      'account_number': user.accountNumber,
      'amount': amount,
      'narration': 'MLQ Reward Payout',
      'currency': 'NGN',
      'reference': generateUniqueRef(),
    }),
  );
  
  if (response.statusCode == 200) {
    // Debit wallet
    await debitWallet(
      userId: userId,
      amount: amount,
      description: 'Payout to ${user.bankName}',
      type: 'payout',
    );
    return true;
  }
  return false;
}
```

**Advantages**:
- ✅ Simpler implementation
- ✅ Full control over wallet logic
- ✅ Lower costs (only pay for withdrawals)

**Disadvantages**:
- ⚠️ Manual balance management
- ⚠️ No real-time bank sync
- ⚠️ More complex reconciliation

---

## 🔐 Security & Compliance

### Parent Consent System
**Why**: Nigerian law requires parental consent for minors' financial accounts

**Flow**:
1. Student requests wallet activation
2. System generates unique consent token
3. Email sent to parent with consent link
4. Parent clicks link, reviews terms
5. Parent approves/rejects
6. Wallet activated upon approval

**Current Status**: 
- ✅ Database schema ready
- ✅ Consent tracking implemented
- ⚠️ Email automation pending (Edge Function needed)

### Security Measures
- ✅ All money operations via secure RPCs
- ✅ Audit log for all transactions
- ✅ Parent consent required for activation
- ✅ Admin approval for large disbursements
- ✅ Transaction limits (can be configured)
- ✅ Fraud detection ready (via Flutterwave)

---

## 📊 Business Model

### Revenue for MLQ
1. **Platform Fee**: Small percentage of challenge rewards (e.g., 5-10%)
2. **Sponsored Challenges**: Companies pay to sponsor challenges
3. **Premium Subscriptions**: Separate from wallet
4. **Transaction Fees**: Optional small fee on withdrawals

### Revenue for Students
1. **Challenge Rewards**: ₦500 - ₦50,000+ per challenge
2. **Achievement Bonuses**: ₦100 - ₦5,000
3. **Monthly Competitions**: ₦10,000 - ₦100,000 prizes
4. **Content Creation**: ₦500 - ₦10,000 per approved course

---

## 🚀 Implementation Roadmap

### Phase 1: Flutterwave Integration (Current Priority)
**Timeline**: 2-3 weeks

**Tasks**:
1. ✅ Review current wallet implementation (Done)
2. 🔄 Set up Flutterwave subaccounts API
3. 🔄 Implement subaccount creation on wallet activation
4. 🔄 Implement reward transfer to subaccounts
5. 🔄 Implement withdrawal to bank accounts
6. 🔄 Add webhook handlers for transfer status
7. 🔄 Test in Flutterwave sandbox
8. 🔄 Update UI to show Flutterwave integration

**Code Changes Needed**:
- Create `flutterwave_wallet_service.dart`
- Add Edge Function: `flutterwave_create_subaccount`
- Add Edge Function: `flutterwave_transfer_funds`
- Add Edge Function: `flutterwave_webhook_handler`
- Update `wallet_service.dart` to use Flutterwave
- Add Flutterwave transaction tracking

### Phase 2: Parent Consent Automation
**Timeline**: 1 week

**Tasks**:
1. 🔄 Create Edge Function for consent emails
2. 🔄 Design consent email template
3. 🔄 Create consent approval web page
4. 🔄 Implement consent verification
5. 🔄 Add consent status notifications

### Phase 3: Production Launch
**Timeline**: 1-2 weeks

**Tasks**:
1. 🔄 Switch from sandbox to production mode
2. 🔄 Set up real Flutterwave account
3. 🔄 Configure production API keys
4. 🔄 Test with real small amounts
5. 🔄 Launch to pilot group
6. 🔄 Monitor and iterate

---

## 💡 Recommendations

### Immediate Actions

1. **Choose Integration Strategy**
   - **Recommended**: Option 1 (Flutterwave Subaccounts)
   - Reason: Simpler, more secure, better UX

2. **Set Up Flutterwave**
   - Create Flutterwave business account (if not already)
   - Get API keys (test and live)
   - Set up webhook URLs
   - Configure transfer settings

3. **Implement Core Functions**
   - Subaccount creation
   - Transfer to subaccounts
   - Withdrawal to banks
   - Webhook handling

4. **Test Thoroughly**
   - Use Flutterwave test mode
   - Test all flows with small amounts
   - Verify parent consent workflow
   - Test edge cases

5. **Launch Pilot**
   - Start with 10-20 students
   - Small reward amounts (₦100-500)
   - Monitor closely
   - Gather feedback

### Long-term Enhancements

1. **Savings Features**
   - Interest on savings goals
   - Automated savings (round-up purchases)
   - Group savings challenges

2. **Financial Education**
   - In-app financial literacy courses
   - Budgeting tools
   - Spending insights

3. **Advanced Features**
   - Peer-to-peer transfers
   - Bill payments
   - Airtime purchases
   - School fee payments

---

## 📝 Summary

**LeadWallet Status**: 
- ✅ Fully implemented UI and database
- ✅ Ready for Flutterwave integration
- ⚠️ Currently in sandbox mode
- ⚠️ Needs production bank API integration

**Flutterwave Integration**:
- **Best Approach**: Use Flutterwave Subaccounts
- **Timeline**: 2-3 weeks to production
- **Cost**: ~₦10.75 per transfer
- **Complexity**: Medium (well-documented API)

**Next Steps**:
1. Approve Flutterwave integration strategy
2. Set up Flutterwave business account
3. Implement subaccount creation
4. Implement transfer functions
5. Test in sandbox
6. Launch pilot program

---

**Report Date**: April 23, 2026  
**Status**: Ready for Flutterwave Integration  
**Priority**: High (enables real revenue for students)

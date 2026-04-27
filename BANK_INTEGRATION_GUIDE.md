# LeadWallet Bank Integration Guide

## Overview

This document provides technical guidance for integrating MLQ's LeadWallet with a banking partner API (Wema Bank, Sterling Bank, Kuda, Moniepoint, etc.).

**Current Status**: 🟡 Sandbox Mode (Mock Implementation)  
**Target**: 🎯 Production Bank Integration

---

## Architecture

### Current Architecture (Sandbox Mode)

```
┌─────────────────┐
│   MLQ Flutter   │
│      App        │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  BankIntegrationService         │
│  (Mock Implementation)          │
│  - verifyBVN() → Mock           │
│  - createAccount() → Mock       │
│  - depositFunds() → Database    │
│  - getBalance() → Database      │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────┐
│   Supabase DB   │
│   (PostgreSQL)  │
└─────────────────┘
```

### Target Architecture (Production)

```
┌─────────────────┐
│   MLQ Flutter   │
│      App        │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  BankIntegrationService         │
│  (Real Implementation)          │
└────────┬────────────────────────┘
         │
         ├──────────────┬──────────────┐
         ▼              ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Bank API   │  │ Supabase DB │  │  Webhooks   │
│  (REST/SDK) │  │   (Cache)   │  │  (Async)    │
└─────────────┘  └─────────────┘  └─────────────┘
```

---

## Integration Checklist

### Phase 1: Partnership & Legal (Business Team)
- [ ] Select bank partner (Wema, Sterling, Kuda, etc.)
- [ ] Sign partnership agreement
- [ ] Complete legal compliance review
- [ ] Obtain CBN approval (if required)
- [ ] Set up insurance for funds
- [ ] Complete NDPR compliance audit

### Phase 2: Technical Setup (Dev Team)
- [ ] Obtain API credentials (API key, secret, etc.)
- [ ] Set up sandbox/test environment
- [ ] Configure OAuth/authentication
- [ ] Set up webhook endpoints
- [ ] Configure SSL certificates
- [ ] Set up monitoring and alerting

### Phase 3: Implementation (Dev Team)
- [ ] Replace mock BVN verification
- [ ] Replace mock account creation
- [ ] Replace mock deposit function
- [ ] Replace mock balance inquiry
- [ ] Implement webhook handlers
- [ ] Add error handling and retries
- [ ] Implement transaction reconciliation
- [ ] Add idempotency for deposits

### Phase 4: Testing (QA Team)
- [ ] Test BVN verification flow
- [ ] Test account creation flow
- [ ] Test deposit transactions
- [ ] Test balance sync
- [ ] Test webhook handling
- [ ] Test error scenarios
- [ ] Load testing
- [ ] Security audit

### Phase 5: Migration (Dev + Ops Team)
- [ ] Run database migration
- [ ] Migrate existing users (if any)
- [ ] Switch from sandbox to production
- [ ] Monitor for issues
- [ ] Set up 24/7 support

---

## API Requirements

### 1. BVN Verification API

**Purpose**: Verify parent's identity using Bank Verification Number

**Required Endpoint**:
```
POST /api/v1/bvn/verify
```

**Request**:
```json
{
  "bvn": "12345678901",
  "phone_number": "+2348012345678",
  "date_of_birth": "1985-06-15" // Optional
}
```

**Response**:
```json
{
  "success": true,
  "verified": true,
  "data": {
    "full_name": "John Doe",
    "phone_number": "+2348012345678",
    "bvn": "12345678901",
    "verification_id": "VER_123456"
  }
}
```

**Implementation Location**: `lib/services/bank_integration_service.dart:verifyBVN()`

---

### 2. Guardian Sub-Account Creation API

**Purpose**: Create a guardian-linked sub-account for the student

**Required Endpoint**:
```
POST /api/v1/accounts/create-sub-account
```

**Request**:
```json
{
  "guardian_bvn": "12345678901",
  "guardian_name": "John Doe",
  "guardian_phone": "+2348012345678",
  "child_name": "Jane Doe",
  "child_dob": "2010-03-20",
  "account_type": "savings",
  "reference": "MLQ_USER_abc123"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "account_id": "ACCT_789012",
    "account_number": "2001234567",
    "account_name": "Jane Doe",
    "bank_code": "000",
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

**Implementation Location**: `lib/services/bank_integration_service.dart:createGuardianSubAccount()`

---

### 3. Balance Inquiry API

**Purpose**: Get current account balance

**Required Endpoint**:
```
GET /api/v1/accounts/{account_id}/balance
```

**Response**:
```json
{
  "success": true,
  "data": {
    "account_id": "ACCT_789012",
    "account_number": "2001234567",
    "balance": 1250.50,
    "currency": "NGN",
    "last_updated": "2024-01-15T14:30:00Z"
  }
}
```

**Implementation Location**: `lib/services/bank_integration_service.dart:getAccountBalance()`

---

### 4. Deposit/Transfer API

**Purpose**: Deposit reward money into student's account

**Required Endpoint**:
```
POST /api/v1/transfers/deposit
```

**Request**:
```json
{
  "to_account_id": "ACCT_789012",
  "amount": 500.00,
  "currency": "NGN",
  "narration": "Reward: Leadership Challenge Completed",
  "reference": "MLQ_REWARD_xyz789",
  "idempotency_key": "unique_key_123"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "transaction_id": "TXN_456789",
    "reference": "MLQ_REWARD_xyz789",
    "amount": 500.00,
    "status": "completed", // or "pending"
    "completed_at": "2024-01-15T14:35:00Z"
  }
}
```

**Implementation Location**: `lib/services/bank_integration_service.dart:depositFunds()`

---

### 5. Transaction History API

**Purpose**: Get transaction history for reconciliation

**Required Endpoint**:
```
GET /api/v1/accounts/{account_id}/transactions?limit=50&offset=0
```

**Response**:
```json
{
  "success": true,
  "data": {
    "transactions": [
      {
        "transaction_id": "TXN_456789",
        "type": "credit",
        "amount": 500.00,
        "balance_after": 1250.50,
        "narration": "Reward: Leadership Challenge Completed",
        "reference": "MLQ_REWARD_xyz789",
        "status": "completed",
        "created_at": "2024-01-15T14:35:00Z"
      }
    ],
    "pagination": {
      "total": 25,
      "limit": 50,
      "offset": 0
    }
  }
}
```

**Implementation Location**: `lib/services/bank_integration_service.dart:getTransactionHistory()`

---

## Webhook Integration

### Purpose
Receive async notifications from bank about transaction status changes.

### Webhook Endpoint (MLQ Side)
```
POST https://api.myleadershipquest.com/webhooks/bank
```

### Security
- Verify webhook signature using shared secret
- Validate timestamp to prevent replay attacks
- Use HTTPS only

### Event Types

#### 1. Transaction Completed
```json
{
  "event_type": "transaction.completed",
  "timestamp": "2024-01-15T14:35:00Z",
  "data": {
    "transaction_id": "TXN_456789",
    "account_id": "ACCT_789012",
    "amount": 500.00,
    "reference": "MLQ_REWARD_xyz789",
    "status": "completed"
  },
  "signature": "sha256_hash_here"
}
```

#### 2. Transaction Failed
```json
{
  "event_type": "transaction.failed",
  "timestamp": "2024-01-15T14:35:00Z",
  "data": {
    "transaction_id": "TXN_456789",
    "account_id": "ACCT_789012",
    "amount": 500.00,
    "reference": "MLQ_REWARD_xyz789",
    "status": "failed",
    "error_code": "INSUFFICIENT_FUNDS",
    "error_message": "Insufficient funds in source account"
  },
  "signature": "sha256_hash_here"
}
```

**Implementation Location**: `lib/services/bank_integration_service.dart:handleBankWebhook()`

---

## Error Handling

### Common Error Scenarios

| Error | Cause | Handling Strategy |
|-------|-------|-------------------|
| BVN verification failed | Invalid BVN or mismatch | Show error, allow retry |
| Account creation failed | Bank API error | Retry with exponential backoff |
| Deposit failed | Insufficient funds in master account | Alert admin, queue for retry |
| Balance inquiry timeout | Network issue | Use cached balance, retry in background |
| Webhook signature invalid | Security issue | Log and alert, do not process |

### Retry Logic

```dart
Future<T> retryWithBackoff<T>({
  required Future<T> Function() operation,
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  int attempt = 0;
  while (attempt < maxAttempts) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      if (attempt >= maxAttempts) rethrow;
      await Future.delayed(initialDelay * math.pow(2, attempt));
    }
  }
  throw Exception('Max retry attempts reached');
}
```

---

## Security Considerations

### 1. API Authentication
- Use OAuth 2.0 or API key + secret
- Store credentials in environment variables (never in code)
- Rotate keys regularly

### 2. Data Encryption
- All API calls over HTTPS/TLS 1.3
- Encrypt sensitive data at rest (BVN, account numbers)
- Use Supabase RLS for database security

### 3. PII Protection
- Never log BVN or full account numbers
- Mask sensitive data in logs (e.g., "123****901")
- Comply with NDPR data retention policies

### 4. Idempotency
- Use unique idempotency keys for deposits
- Prevent duplicate transactions
- Store idempotency keys for 24 hours

---

## Testing Strategy

### 1. Unit Tests
- Test each bank service method with mocks
- Test error handling
- Test retry logic

### 2. Integration Tests
- Test against bank's sandbox environment
- Test full user journey (BVN → Account → Deposit)
- Test webhook handling

### 3. Load Tests
- Simulate 1000 concurrent users
- Test API rate limits
- Test database performance

### 4. Security Tests
- Penetration testing
- Webhook signature validation
- SQL injection prevention

---

## Monitoring & Alerting

### Key Metrics to Monitor

1. **API Performance**
   - Response time (p50, p95, p99)
   - Error rate
   - Timeout rate

2. **Transaction Success Rate**
   - Successful deposits / Total attempts
   - Failed transactions by error type

3. **Balance Sync**
   - Time since last sync
   - Sync failures

4. **Webhook Processing**
   - Webhook delivery success rate
   - Processing latency

### Alerts to Set Up

- ⚠️ API error rate > 5%
- ⚠️ Deposit failure rate > 2%
- 🚨 Balance sync failed for > 1 hour
- 🚨 Webhook signature validation failed
- 🚨 Master account balance < ₦100,000

---

## Migration Plan

### Step 1: Database Migration
```bash
# Run migration SQL
psql -h your-db-host -U postgres -d mlq_db -f BANK_INTEGRATION_DATABASE_MIGRATION.sql
```

### Step 2: Update Environment Variables
```env
BANK_API_BASE_URL=https://api.bankpartner.com
BANK_API_KEY=your_api_key_here
BANK_API_SECRET=your_api_secret_here
BANK_WEBHOOK_SECRET=your_webhook_secret_here
BANK_PROVIDER=wema # or sterling, kuda, etc.
IS_SANDBOX_MODE=false # Set to false for production
```

### Step 3: Code Changes
1. Update `BankIntegrationService` methods to call real API
2. Remove mock implementations
3. Add real error handling
4. Implement webhook handlers

### Step 4: Testing
1. Test in bank's sandbox environment
2. Verify all flows work end-to-end
3. Run load tests
4. Security audit

### Step 5: Production Deployment
1. Deploy to production
2. Monitor closely for 48 hours
3. Have rollback plan ready
4. Provide 24/7 support

---

## Support & Troubleshooting

### Common Issues

**Issue**: BVN verification always fails  
**Solution**: Check API credentials, verify BVN format, check bank API status

**Issue**: Deposits not reflecting in account  
**Solution**: Check webhook processing, verify transaction ID, check bank transaction status

**Issue**: Balance out of sync  
**Solution**: Run manual sync, check last sync timestamp, verify no failed transactions

### Contact

- **Bank Partner Support**: support@bankpartner.com
- **MLQ Dev Team**: dev@myleadershipquest.com
- **Emergency Hotline**: +234-XXX-XXX-XXXX

---

## Appendix

### A. Bank Partner Comparison

| Feature | Wema Bank | Sterling Bank | Kuda | Moniepoint |
|---------|-----------|---------------|------|------------|
| API Quality | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Documentation | Good | Excellent | Excellent | Good |
| Sub-accounts | ✅ | ✅ | ✅ | ✅ |
| BVN Verification | ✅ | ✅ | ✅ | ✅ |
| Webhooks | ✅ | ✅ | ✅ | ✅ |
| Cost | Medium | Medium | Low | Low |
| Support | Good | Excellent | Excellent | Good |

### B. Useful Links

- [Wema Bank API Docs](https://developer.wemabank.com)
- [Sterling Bank API Docs](https://developer.sterling.ng)
- [Kuda API Docs](https://kudabank.gitbook.io/kudabank/)
- [Moniepoint API Docs](https://docs.moniepoint.com)
- [CBN Guidelines](https://www.cbn.gov.ng)
- [NDPR Compliance](https://ndpr.nitda.gov.ng)

---

**Document Version**: 1.0  
**Last Updated**: January 2024  
**Next Review**: When bank partnership is finalized

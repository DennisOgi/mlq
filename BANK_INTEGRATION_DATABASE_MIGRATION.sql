-- ============================================================================
-- LeadWallet Bank Integration - Database Migration
-- ============================================================================
-- This migration adds fields needed for bank partner integration
-- 
-- CURRENT STATUS: Sandbox mode (mock implementation)
-- WHEN READY: These fields will store real bank account details
-- ============================================================================

-- Add bank integration fields to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS bank_account_id TEXT,
ADD COLUMN IF NOT EXISTS bank_account_number TEXT,
ADD COLUMN IF NOT EXISTS bank_account_name TEXT,
ADD COLUMN IF NOT EXISTS bank_provider TEXT, -- 'wema', 'sterling', 'kuda', 'moniepoint', etc.
ADD COLUMN IF NOT EXISTS guardian_bvn_verified BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS account_setup_completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS is_sandbox_mode BOOLEAN DEFAULT true; -- Set to false in production

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_bank_account_id ON profiles(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_profiles_bank_provider ON profiles(bank_provider);
CREATE INDEX IF NOT EXISTS idx_profiles_sandbox_mode ON profiles(is_sandbox_mode);

-- Add comment to document the fields
COMMENT ON COLUMN profiles.bank_account_id IS 'Unique account ID from bank partner API';
COMMENT ON COLUMN profiles.bank_account_number IS 'Bank account number (10 digits)';
COMMENT ON COLUMN profiles.bank_account_name IS 'Account holder name (student name)';
COMMENT ON COLUMN profiles.bank_provider IS 'Bank partner identifier (wema, sterling, kuda, etc.)';
COMMENT ON COLUMN profiles.guardian_bvn_verified IS 'Whether parent BVN has been verified';
COMMENT ON COLUMN profiles.account_setup_completed_at IS 'Timestamp when bank account setup was completed';
COMMENT ON COLUMN profiles.is_sandbox_mode IS 'True for mock/test accounts, false for real bank accounts';

-- ============================================================================
-- Bank Webhook Events Table (for future use)
-- ============================================================================
-- This table will store webhook notifications from the bank partner
-- Useful for tracking async events like transaction confirmations

CREATE TABLE IF NOT EXISTS bank_webhook_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_type TEXT NOT NULL, -- 'transaction.completed', 'transaction.failed', etc.
  event_data JSONB NOT NULL, -- Full webhook payload
  account_id TEXT, -- Bank account ID
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  processed BOOLEAN DEFAULT false,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Indexes
  INDEX idx_webhook_events_user_id (user_id),
  INDEX idx_webhook_events_account_id (account_id),
  INDEX idx_webhook_events_processed (processed),
  INDEX idx_webhook_events_created_at (created_at)
);

COMMENT ON TABLE bank_webhook_events IS 'Stores webhook notifications from bank partner for audit and processing';

-- ============================================================================
-- Bank Transaction Sync Table (for reconciliation)
-- ============================================================================
-- This table helps reconcile transactions between bank and MLQ database

CREATE TABLE IF NOT EXISTS bank_transaction_sync (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  bank_transaction_id TEXT NOT NULL, -- Transaction ID from bank
  mlq_transaction_id UUID REFERENCES wallet_transactions(id),
  amount DECIMAL(10, 2) NOT NULL,
  transaction_type TEXT NOT NULL, -- 'credit', 'debit'
  bank_status TEXT NOT NULL, -- 'pending', 'completed', 'failed'
  mlq_status TEXT, -- Status in our system
  synced BOOLEAN DEFAULT false,
  sync_attempts INT DEFAULT 0,
  last_sync_attempt TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Indexes
  INDEX idx_bank_sync_user_id (user_id),
  INDEX idx_bank_sync_bank_tx_id (bank_transaction_id),
  INDEX idx_bank_sync_mlq_tx_id (mlq_transaction_id),
  INDEX idx_bank_sync_synced (synced),
  
  -- Unique constraint to prevent duplicate sync records
  UNIQUE(bank_transaction_id)
);

COMMENT ON TABLE bank_transaction_sync IS 'Reconciliation table for syncing transactions between bank and MLQ';

-- ============================================================================
-- Update wallet_transactions table
-- ============================================================================
-- Add bank-related fields to existing wallet_transactions table

ALTER TABLE wallet_transactions
ADD COLUMN IF NOT EXISTS bank_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS bank_reference TEXT,
ADD COLUMN IF NOT EXISTS bank_status TEXT; -- 'pending', 'completed', 'failed'

CREATE INDEX IF NOT EXISTS idx_wallet_tx_bank_id ON wallet_transactions(bank_transaction_id);

COMMENT ON COLUMN wallet_transactions.bank_transaction_id IS 'Transaction ID from bank partner API';
COMMENT ON COLUMN wallet_transactions.bank_reference IS 'Bank reference number for tracking';
COMMENT ON COLUMN wallet_transactions.bank_status IS 'Status from bank (pending, completed, failed)';

-- ============================================================================
-- RPC Function: Sync Balance from Bank
-- ============================================================================
-- This function will be used to sync balance from bank API to local database

CREATE OR REPLACE FUNCTION sync_balance_from_bank(
  p_user_id UUID,
  p_bank_balance DECIMAL(10, 2),
  p_last_synced TIMESTAMPTZ DEFAULT NOW()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance DECIMAL(10, 2);
  v_difference DECIMAL(10, 2);
BEGIN
  -- Get current balance in database
  SELECT wallet_balance INTO v_current_balance
  FROM profiles
  WHERE id = p_user_id;
  
  -- Calculate difference
  v_difference := p_bank_balance - v_current_balance;
  
  -- Update balance if different
  IF v_difference != 0 THEN
    UPDATE profiles
    SET 
      wallet_balance = p_bank_balance,
      updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Log the sync as a transaction
    INSERT INTO wallet_transactions (
      user_id,
      amount,
      balance_after,
      type,
      status,
      description,
      reference_type,
      created_at
    ) VALUES (
      p_user_id,
      v_difference,
      p_bank_balance,
      'adjustment',
      'completed',
      'Balance sync from bank',
      'bank_sync',
      NOW()
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'previous_balance', v_current_balance,
    'new_balance', p_bank_balance,
    'difference', v_difference,
    'synced_at', p_last_synced
  );
END;
$$;

COMMENT ON FUNCTION sync_balance_from_bank IS 'Syncs wallet balance from bank API to local database';

-- ============================================================================
-- View: Bank Integration Status
-- ============================================================================
-- Useful view for monitoring bank integration status

CREATE OR REPLACE VIEW bank_integration_status AS
SELECT 
  p.id as user_id,
  p.name as student_name,
  p.email,
  p.bank_account_id,
  p.bank_account_number,
  p.bank_provider,
  p.guardian_bvn_verified,
  p.account_setup_completed_at,
  p.is_sandbox_mode,
  p.wallet_balance,
  p.wallet_status,
  COUNT(wt.id) as transaction_count,
  MAX(wt.created_at) as last_transaction_at
FROM profiles p
LEFT JOIN wallet_transactions wt ON wt.user_id = p.id
WHERE p.bank_account_id IS NOT NULL
GROUP BY p.id;

COMMENT ON VIEW bank_integration_status IS 'Overview of bank integration status for all users';

-- ============================================================================
-- Grant Permissions
-- ============================================================================

-- Grant access to authenticated users
GRANT SELECT ON bank_integration_status TO authenticated;
GRANT SELECT, INSERT ON bank_webhook_events TO authenticated;
GRANT SELECT, INSERT, UPDATE ON bank_transaction_sync TO authenticated;

-- Grant execute permission on sync function
GRANT EXECUTE ON FUNCTION sync_balance_from_bank TO authenticated;

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- To apply this migration:
-- 1. Run this SQL in your Supabase SQL Editor
-- 2. Verify tables and columns were created
-- 3. Test with a sandbox account
-- 4. When bank partnership is ready, update is_sandbox_mode to false

SELECT 'Bank integration database migration completed successfully!' as status;

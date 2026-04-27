-- ============================================================================
-- LeadWallet MVP Database Migration
-- ============================================================================
-- This migration adds the withdrawal_requests table and supporting functions
-- for the MVP implementation using Internal Ledger + Flutterwave Transfer API
-- ============================================================================

-- ─── 1. CREATE WITHDRAWAL_REQUESTS TABLE ────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Amount in kobo (₦1 = 100 kobo) to avoid floating-point errors
    amount_kobo INTEGER NOT NULL CHECK (amount_kobo > 0),
    
    -- Bank account details
    bank_code TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    
    -- Status workflow
    status TEXT NOT NULL DEFAULT 'pending_parent_approval' CHECK (
        status IN (
            'pending_parent_approval',
            'pending_admin_approval',
            'approved',
            'processing',
            'paid',
            'failed',
            'rejected',
            'cancelled'
        )
    ),
    
    -- Flutterwave integration
    flutterwave_reference TEXT UNIQUE,
    flutterwave_transfer_id TEXT,
    
    -- Approval tracking
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMPTZ,
    
    -- Failure tracking
    failure_reason TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_student_id 
    ON public.withdrawal_requests(student_id);
    
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status 
    ON public.withdrawal_requests(status);
    
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_flw_reference 
    ON public.withdrawal_requests(flutterwave_reference);

-- Enable RLS
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own withdrawal requests"
    ON public.withdrawal_requests FOR SELECT
    USING (auth.uid() = student_id);

CREATE POLICY "Users can create their own withdrawal requests"
    ON public.withdrawal_requests FOR INSERT
    WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Users can update their own pending requests"
    ON public.withdrawal_requests FOR UPDATE
    USING (auth.uid() = student_id AND status = 'pending_parent_approval');

-- Admin policy (requires admin_users table)
CREATE POLICY "Admins can view all withdrawal requests"
    ON public.withdrawal_requests FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can update withdrawal requests"
    ON public.withdrawal_requests FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE user_id = auth.uid()
        )
    );

-- ─── 2. CREATE RPC: GET WALLET BALANCE IN KOBO ─────────────────────────────

CREATE OR REPLACE FUNCTION public.get_wallet_balance_kobo(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_balance_naira NUMERIC;
    v_balance_kobo INTEGER;
BEGIN
    -- Get current balance from profiles (in Naira)
    SELECT COALESCE(wallet_balance, 0)
    INTO v_balance_naira
    FROM public.profiles
    WHERE id = p_user_id;
    
    -- Convert to kobo (₦1 = 100 kobo)
    v_balance_kobo := ROUND(v_balance_naira * 100)::INTEGER;
    
    RETURN v_balance_kobo;
END;
$$;

-- ─── 3. CREATE RPC: GET AVAILABLE BALANCE (EXCLUDING PENDING WITHDRAWALS) ───

CREATE OR REPLACE FUNCTION public.get_available_balance_kobo(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wallet_balance_kobo INTEGER;
    v_pending_withdrawals_kobo INTEGER;
    v_available_kobo INTEGER;
BEGIN
    -- Get wallet balance in kobo
    v_wallet_balance_kobo := public.get_wallet_balance_kobo(p_user_id);
    
    -- Get sum of pending withdrawals
    SELECT COALESCE(SUM(amount_kobo), 0)
    INTO v_pending_withdrawals_kobo
    FROM public.withdrawal_requests
    WHERE student_id = p_user_id
    AND status IN ('pending_parent_approval', 'pending_admin_approval', 'approved', 'processing');
    
    -- Calculate available balance
    v_available_kobo := v_wallet_balance_kobo - v_pending_withdrawals_kobo;
    
    -- Ensure non-negative
    IF v_available_kobo < 0 THEN
        v_available_kobo := 0;
    END IF;
    
    RETURN v_available_kobo;
END;
$$;

-- ─── 4. CREATE RPC: VALIDATE WITHDRAWAL REQUEST ────────────────────────────

CREATE OR REPLACE FUNCTION public.validate_withdrawal_request(
    p_user_id UUID,
    p_amount_kobo INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_available_balance_kobo INTEGER;
    v_wallet_status TEXT;
    v_consent_status TEXT;
    v_result JSONB;
BEGIN
    -- Check wallet status
    SELECT wallet_status
    INTO v_wallet_status
    FROM public.profiles
    WHERE id = p_user_id;
    
    IF v_wallet_status != 'active' THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Wallet not active. Status: ' || COALESCE(v_wallet_status, 'unknown')
        );
    END IF;
    
    -- Check parent consent for payouts
    SELECT status
    INTO v_consent_status
    FROM public.wallet_consent
    WHERE student_id = p_user_id
    AND consent_type = 'payout_approval'
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_consent_status IS NULL OR v_consent_status != 'approved' THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Parent consent required for withdrawals'
        );
    END IF;
    
    -- Check available balance
    v_available_balance_kobo := public.get_available_balance_kobo(p_user_id);
    
    IF p_amount_kobo > v_available_balance_kobo THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Insufficient balance. Available: ₦' || (v_available_balance_kobo / 100.0)
        );
    END IF;
    
    -- Check minimum withdrawal (₦500 = 50,000 kobo)
    IF p_amount_kobo < 50000 THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Minimum withdrawal is ₦500'
        );
    END IF;
    
    -- Check maximum withdrawal per day (₦10,000 = 1,000,000 kobo)
    DECLARE
        v_today_withdrawals_kobo INTEGER;
    BEGIN
        SELECT COALESCE(SUM(amount_kobo), 0)
        INTO v_today_withdrawals_kobo
        FROM public.withdrawal_requests
        WHERE student_id = p_user_id
        AND created_at >= CURRENT_DATE
        AND status NOT IN ('rejected', 'cancelled', 'failed');
        
        IF (v_today_withdrawals_kobo + p_amount_kobo) > 1000000 THEN
            RETURN jsonb_build_object(
                'valid', false,
                'error', 'Daily withdrawal limit exceeded (₦10,000)'
            );
        END IF;
    END;
    
    -- All checks passed
    RETURN jsonb_build_object(
        'valid', true,
        'available_balance_kobo', v_available_balance_kobo
    );
END;
$$;

-- ─── 5. CREATE TRIGGER: UPDATE UPDATED_AT ──────────────────────────────────

CREATE OR REPLACE FUNCTION public.update_withdrawal_requests_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_withdrawal_requests_updated_at
    BEFORE UPDATE ON public.withdrawal_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.update_withdrawal_requests_updated_at();

-- ─── 6. CREATE TRIGGER: AUDIT LOG FOR WITHDRAWALS ──────────────────────────

CREATE OR REPLACE FUNCTION public.log_withdrawal_request_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.wallet_audit_log (
            actor_id,
            action,
            target_user_id,
            amount,
            metadata
        ) VALUES (
            NEW.student_id,
            'withdrawal_request_created',
            NEW.student_id,
            NEW.amount_kobo / 100.0,
            jsonb_build_object(
                'withdrawal_id', NEW.id,
                'bank_code', NEW.bank_code,
                'account_number', NEW.account_number
            )
        );
    ELSIF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
        INSERT INTO public.wallet_audit_log (
            actor_id,
            action,
            target_user_id,
            amount,
            metadata
        ) VALUES (
            COALESCE(NEW.approved_by, NEW.student_id),
            'withdrawal_status_changed',
            NEW.student_id,
            NEW.amount_kobo / 100.0,
            jsonb_build_object(
                'withdrawal_id', NEW.id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'flutterwave_reference', NEW.flutterwave_reference
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_log_withdrawal_request_changes
    AFTER INSERT OR UPDATE ON public.withdrawal_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.log_withdrawal_request_changes();

-- ─── 7. ADD HELPER VIEWS ───────────────────────────────────────────────────

-- View: Pending withdrawals for admin dashboard
CREATE OR REPLACE VIEW public.pending_withdrawals_admin AS
SELECT 
    wr.id,
    wr.student_id,
    p.name as student_name,
    p.school_name,
    wr.amount_kobo,
    ROUND(wr.amount_kobo / 100.0, 2) as amount_naira,
    wr.bank_code,
    wr.account_number,
    wr.account_name,
    wr.status,
    wr.created_at,
    wr.updated_at
FROM public.withdrawal_requests wr
JOIN public.profiles p ON p.id = wr.student_id
WHERE wr.status IN ('pending_admin_approval', 'approved')
ORDER BY wr.created_at ASC;

-- ─── 8. GRANT PERMISSIONS ──────────────────────────────────────────────────

-- Grant execute permissions on RPCs
GRANT EXECUTE ON FUNCTION public.get_wallet_balance_kobo(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_balance_kobo(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_withdrawal_request(UUID, INTEGER) TO authenticated;

-- Grant select on view to admins (handled by RLS)
GRANT SELECT ON public.pending_withdrawals_admin TO authenticated;

-- ─── 9. ADD COMMENTS ────────────────────────────────────────────────────────

COMMENT ON TABLE public.withdrawal_requests IS 
'Withdrawal requests for LeadWallet - tracks student requests to withdraw earnings to bank accounts';

COMMENT ON COLUMN public.withdrawal_requests.amount_kobo IS 
'Amount in kobo (₦1 = 100 kobo) to avoid floating-point errors';

COMMENT ON FUNCTION public.get_wallet_balance_kobo(UUID) IS 
'Returns wallet balance in kobo for a user';

COMMENT ON FUNCTION public.get_available_balance_kobo(UUID) IS 
'Returns available balance (wallet balance minus pending withdrawals) in kobo';

COMMENT ON FUNCTION public.validate_withdrawal_request(UUID, INTEGER) IS 
'Validates if a withdrawal request can be created (checks balance, limits, consent)';

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- Next Steps:
-- 1. Run this migration in Supabase SQL Editor
-- 2. Create Edge Functions for Flutterwave API
-- 3. Update Flutter services to use new withdrawal flow
-- 4. Test in Flutterwave sandbox mode
-- ============================================================================

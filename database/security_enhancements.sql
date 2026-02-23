-- Security enhancements for My Leadership Quest database
-- Prevents gaming and ensures data integrity

-- 1. Goal completions audit table
CREATE TABLE IF NOT EXISTS goal_completions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    goal_id UUID REFERENCES daily_goals(id) ON DELETE CASCADE,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Add completion tracking to daily_goals
ALTER TABLE daily_goals 
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS completion_ip INET,
ADD COLUMN IF NOT EXISTS attempts_count INTEGER DEFAULT 0;

-- 3. User activity monitoring
CREATE TABLE IF NOT EXISTS user_activity_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    metadata JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Rate limiting table
CREATE TABLE IF NOT EXISTS rate_limits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    count INTEGER DEFAULT 1,
    window_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, action_type, window_start)
);

-- 5. Suspicious activity tracking
CREATE TABLE IF NOT EXISTS suspicious_activities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    description TEXT,
    severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    metadata JSONB,
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Secure goal completion function
CREATE OR REPLACE FUNCTION complete_daily_goal(
    goal_id UUID,
    user_id UUID,
    xp_reward INTEGER,
    coin_reward DECIMAL,
    completed_at TIMESTAMP WITH TIME ZONE
) RETURNS JSONB AS $$
DECLARE
    goal_record daily_goals%ROWTYPE;
    completion_count INTEGER;
    result JSONB;
BEGIN
    -- 1. Validate goal ownership and status
    SELECT * INTO goal_record 
    FROM daily_goals 
    WHERE id = goal_id AND user_id = complete_daily_goal.user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Goal not found or access denied');
    END IF;
    
    IF goal_record.is_completed THEN
        RETURN jsonb_build_object('success', false, 'error', 'Goal already completed');
    END IF;
    
    -- 2. Check daily completion limits
    SELECT COUNT(*) INTO completion_count
    FROM goal_completions gc
    WHERE gc.user_id = complete_daily_goal.user_id
    AND DATE(gc.completed_at) = DATE(completed_at);
    
    IF completion_count >= 10 THEN
        -- Log suspicious activity
        INSERT INTO suspicious_activities (user_id, activity_type, description, severity)
        VALUES (complete_daily_goal.user_id, 'excessive_completions', 
                'User attempted to complete more than 10 goals in one day', 'medium');
        
        RETURN jsonb_build_object('success', false, 'error', 'Daily completion limit reached');
    END IF;
    
    -- 3. Validate completion timing (prevent future dating)
    IF DATE(goal_record.date) > DATE(completed_at) THEN
        INSERT INTO suspicious_activities (user_id, activity_type, description, severity)
        VALUES (complete_daily_goal.user_id, 'time_manipulation', 
                'User attempted to complete future goal', 'high');
        
        RETURN jsonb_build_object('success', false, 'error', 'Cannot complete future goals');
    END IF;
    
    -- 4. Begin atomic transaction
    BEGIN
        -- Update goal status
        UPDATE daily_goals 
        SET is_completed = true, 
            completed_at = complete_daily_goal.completed_at,
            attempts_count = attempts_count + 1
        WHERE id = goal_id;
        
        -- Add XP to user
        UPDATE profiles 
        SET xp = xp + xp_reward 
        WHERE id = complete_daily_goal.user_id;
        
        -- Add coins to user
        UPDATE profiles 
        SET coins = coins + coin_reward 
        WHERE id = complete_daily_goal.user_id;
        
        -- Log completion
        INSERT INTO goal_completions (user_id, goal_id, completed_at)
        VALUES (complete_daily_goal.user_id, goal_id, completed_at);
        
        -- Log activity
        INSERT INTO user_activity_log (user_id, action_type, resource_type, resource_id, metadata)
        VALUES (complete_daily_goal.user_id, 'complete', 'daily_goal', goal_id::TEXT, 
                jsonb_build_object('xp_reward', xp_reward, 'coin_reward', coin_reward));
        
        result := jsonb_build_object('success', true, 'xp_earned', xp_reward, 'coins_earned', coin_reward);
        
    EXCEPTION WHEN OTHERS THEN
        -- Log error
        INSERT INTO suspicious_activities (user_id, activity_type, description, severity)
        VALUES (complete_daily_goal.user_id, 'completion_error', 
                'Error during goal completion: ' || SQLERRM, 'medium');
        
        result := jsonb_build_object('success', false, 'error', 'Completion failed');
    END;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. User completion stats function
CREATE OR REPLACE FUNCTION get_user_completion_stats(user_id UUID)
RETURNS JSONB AS $$
DECLARE
    stats JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_completions', COUNT(*),
        'completions_today', COUNT(*) FILTER (WHERE DATE(completed_at) = CURRENT_DATE),
        'completions_this_week', COUNT(*) FILTER (WHERE completed_at >= DATE_TRUNC('week', CURRENT_DATE)),
        'average_per_day', ROUND(COUNT(*)::DECIMAL / GREATEST(1, DATE_PART('day', CURRENT_DATE - MIN(completed_at))), 2),
        'streak_days', (
            SELECT COUNT(DISTINCT DATE(completed_at))
            FROM goal_completions gc2
            WHERE gc2.user_id = get_user_completion_stats.user_id
            AND completed_at >= CURRENT_DATE - INTERVAL '30 days'
        ),
        'suspicious_activities', (
            SELECT COUNT(*)
            FROM suspicious_activities sa
            WHERE sa.user_id = get_user_completion_stats.user_id
            AND NOT resolved
        )
    ) INTO stats
    FROM goal_completions gc
    WHERE gc.user_id = get_user_completion_stats.user_id;
    
    RETURN COALESCE(stats, jsonb_build_object('total_completions', 0));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Rate limiting function
CREATE OR REPLACE FUNCTION check_rate_limit(
    user_id UUID,
    action_type TEXT,
    max_count INTEGER,
    window_minutes INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    current_count INTEGER;
    window_start TIMESTAMP WITH TIME ZONE;
BEGIN
    window_start := NOW() - (window_minutes || ' minutes')::INTERVAL;
    
    SELECT COALESCE(SUM(count), 0) INTO current_count
    FROM rate_limits
    WHERE rate_limits.user_id = check_rate_limit.user_id
    AND rate_limits.action_type = check_rate_limit.action_type
    AND rate_limits.window_start >= window_start;
    
    IF current_count >= max_count THEN
        -- Log rate limit violation
        INSERT INTO suspicious_activities (user_id, activity_type, description, severity)
        VALUES (check_rate_limit.user_id, 'rate_limit_exceeded', 
                'Rate limit exceeded for action: ' || action_type, 'medium');
        
        RETURN FALSE;
    END IF;
    
    -- Update rate limit counter
    INSERT INTO rate_limits (user_id, action_type, count, window_start)
    VALUES (check_rate_limit.user_id, action_type, 1, DATE_TRUNC('minute', NOW()))
    ON CONFLICT (user_id, action_type, window_start)
    DO UPDATE SET count = rate_limits.count + 1;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_goal_completions_user_date ON goal_completions(user_id, completed_at);
CREATE INDEX IF NOT EXISTS idx_user_activity_log_user_date ON user_activity_log(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_rate_limits_user_action ON rate_limits(user_id, action_type, window_start);
CREATE INDEX IF NOT EXISTS idx_suspicious_activities_user ON suspicious_activities(user_id, resolved, created_at);

-- 10. Row Level Security (RLS) policies
ALTER TABLE goal_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE suspicious_activities ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY "Users can view own completions" ON goal_completions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own activity" ON user_activity_log
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own rate limits" ON rate_limits
    FOR SELECT USING (auth.uid() = user_id);

-- Only admins can view suspicious activities
CREATE POLICY "Admins can view suspicious activities" ON suspicious_activities
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM admin_users 
            WHERE user_id = auth.uid()
        )
    );

-- 11. Cleanup old data (run periodically)
CREATE OR REPLACE FUNCTION cleanup_old_security_data()
RETURNS VOID AS $$
BEGIN
    -- Remove old rate limit entries (older than 24 hours)
    DELETE FROM rate_limits 
    WHERE window_start < NOW() - INTERVAL '24 hours';
    
    -- Remove old activity logs (older than 90 days)
    DELETE FROM user_activity_log 
    WHERE created_at < NOW() - INTERVAL '90 days';
    
    -- Archive old goal completions (older than 1 year)
    -- This could be moved to an archive table instead of deletion
    DELETE FROM goal_completions 
    WHERE completed_at < NOW() - INTERVAL '1 year';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

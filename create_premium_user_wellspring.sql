-- Create Premium Account for Dare-Ode Mololuwa from Wellspring College
-- Run this SQL in your Supabase SQL Editor

-- Step 1: Find Wellspring College organization ID
-- (You'll need to check if this exists first)
DO $$
DECLARE
    v_org_id UUID;
    v_user_id UUID;
    v_email TEXT := 'mololuwa.dareode@wellspringcollege.edu.ng';
    v_password TEXT := 'WellspringMLQ2024!'; -- Temporary password, user should change
    v_name TEXT := 'Dare-Ode Mololuwa';
BEGIN
    -- Find Wellspring College organization
    SELECT id INTO v_org_id
    FROM schools
    WHERE LOWER(name) LIKE '%wellspring%'
    LIMIT 1;

    -- If organization doesn't exist, create it
    IF v_org_id IS NULL THEN
        INSERT INTO schools (
            name,
            subscription_tier,
            subscription_expires_at,
            created_at,
            updated_at
        ) VALUES (
            'Wellspring College',
            'premium',
            (NOW() + INTERVAL '1 year'),
            NOW(),
            NOW()
        )
        RETURNING id INTO v_org_id;
        
        RAISE NOTICE 'Created Wellspring College organization: %', v_org_id;
    ELSE
        RAISE NOTICE 'Found existing Wellspring College: %', v_org_id;
    END IF;

    -- Create user in auth.users (Supabase Auth)
    -- Note: This requires admin privileges or use Supabase Dashboard
    -- For now, we'll prepare the profile assuming user will sign up

    -- Check if user already exists
    SELECT id INTO v_user_id
    FROM profiles
    WHERE email = v_email;

    IF v_user_id IS NULL THEN
        -- User needs to sign up first through the app
        -- We'll create a placeholder that will be updated on signup
        RAISE NOTICE 'User needs to sign up with email: %', v_email;
        RAISE NOTICE 'After signup, run the following to grant premium:';
        RAISE NOTICE 'UPDATE profiles SET school_id = ''%'', role = ''student'', is_premium = true WHERE email = ''%'';', v_org_id, v_email;
    ELSE
        -- Update existing user with premium access
        UPDATE profiles
        SET 
            school_id = v_org_id,
            school_name = 'Wellspring College',
            role = 'student',
            is_premium = true,
            premium_expires_at = (NOW() + INTERVAL '1 year'),
            updated_at = NOW()
        WHERE id = v_user_id;

        RAISE NOTICE 'Updated user % with premium access', v_user_id;
    END IF;

END $$;

-- Alternative: If you want to manually create the user after they sign up
-- Replace USER_ID_HERE with the actual user ID after signup

/*
UPDATE profiles
SET 
    school_id = (SELECT id FROM schools WHERE LOWER(name) LIKE '%wellspring%' LIMIT 1),
    school_name = 'Wellspring College',
    role = 'student',
    is_premium = true,
    premium_expires_at = (NOW() + INTERVAL '1 year'),
    updated_at = NOW()
WHERE email = 'mololuwa.dareode@wellspringcollege.edu.ng';
*/

-- Verify the setup
SELECT 
    p.id,
    p.name,
    p.email,
    p.school_name,
    p.role,
    p.is_premium,
    p.premium_expires_at,
    s.name as school_name_from_table,
    s.subscription_tier
FROM profiles p
LEFT JOIN schools s ON p.school_id = s.id
WHERE p.email = 'mololuwa.dareode@wellspringcollege.edu.ng';

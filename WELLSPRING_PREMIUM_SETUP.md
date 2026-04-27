# Create Premium Account for Dare-Ode Mololuwa - Wellspring College

## User Details
- **Name**: Dare-Ode Mololuwa
- **Email**: mololuwa.dareode@wellspringcollege.edu.ng
- **School**: Wellspring College
- **Account Type**: Premium Student

## Setup Steps

### Option 1: User Signs Up First (Recommended)

1. **Have the user sign up** in the My Leadership Quest app with:
   - Email: `mololuwa.dareode@wellspringcollege.edu.ng`
   - Password: (user chooses)
   - Name: Dare-Ode Mololuwa

2. **Run this SQL** in Supabase SQL Editor after signup:

```sql
-- Find or create Wellspring College
INSERT INTO schools (name, subscription_tier, subscription_expires_at, created_at, updated_at)
VALUES ('Wellspring College', 'premium', (NOW() + INTERVAL '1 year'), NOW(), NOW())
ON CONFLICT (name) DO NOTHING;

-- Grant premium access to the user
UPDATE profiles
SET 
    school_id = (SELECT id FROM schools WHERE name = 'Wellspring College' LIMIT 1),
    school_name = 'Wellspring College',
    role = 'student',
    is_premium = true,
    premium_expires_at = (NOW() + INTERVAL '1 year'),
    updated_at = NOW()
WHERE email = 'mololuwa.dareode@wellspringcollege.edu.ng';
```

3. **Verify** the setup:

```sql
SELECT 
    p.id,
    p.name,
    p.email,
    p.school_name,
    p.role,
    p.is_premium,
    p.premium_expires_at
FROM profiles p
WHERE p.email = 'mololuwa.dareode@wellspringcollege.edu.ng';
```

### Option 2: Create User via Supabase Dashboard

1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Click **"Add user"**
3. Fill in:
   - Email: `mololuwa.dareode@wellspringcollege.edu.ng`
   - Password: `WellspringMLQ2024!` (temporary - user should change)
   - Auto Confirm User: ✓ (checked)

4. After user is created, run the SQL from Option 1 Step 2

## What This Grants

✅ Premium account access (1 year)
✅ Access to all premium challenges
✅ School-specific features
✅ Premium mini-courses
✅ No ads/limitations

## Verification

After setup, the user should be able to:
- Log in with their email
- See "Premium" badge on their profile
- Access premium challenges without coin cost
- See "via School" badge indicating school membership

## Troubleshooting

**If user can't see premium features:**
1. Check `is_premium` is `true` in profiles table
2. Check `premium_expires_at` is in the future
3. Check `school_id` matches Wellspring College ID
4. Have user log out and log back in

**If school doesn't exist:**
Run this first:
```sql
INSERT INTO schools (name, subscription_tier, subscription_expires_at)
VALUES ('Wellspring College', 'premium', (NOW() + INTERVAL '1 year'))
RETURNING id;
```

## Contact Information

Email for account: `mololuwa.dareode@wellspringcollege.edu.ng`
Temporary password (if created via dashboard): `WellspringMLQ2024!`

**Important**: User should change password on first login!

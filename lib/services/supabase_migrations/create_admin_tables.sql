-- Create challenges table
CREATE TABLE IF NOT EXISTS challenges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  type SMALLINT NOT NULL, -- 0 for basic, 1 for premium
  real_world_prize TEXT,
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  participants_count INTEGER DEFAULT 0,
  organization_id TEXT NOT NULL,
  organization_name TEXT NOT NULL,
  organization_logo TEXT NOT NULL,
  criteria JSONB NOT NULL,
  timeline TEXT NOT NULL,
  is_team_challenge BOOLEAN NOT NULL DEFAULT false,
  coin_reward INTEGER NOT NULL,
  coin_cost INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create admin_users table to track which users have admin privileges
CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(user_id)
);

-- Create challenge_participants table to track which users have joined which challenges
CREATE TABLE IF NOT EXISTS challenge_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(challenge_id, user_id)
);

-- Create RLS policies

-- Enable RLS on all tables
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_participants ENABLE ROW LEVEL SECURITY;

-- Create policies for challenges table
-- Anyone can read active challenges
CREATE POLICY "Anyone can read active challenges" 
  ON challenges FOR SELECT 
  USING (is_active = true);

-- Only admins can create challenges
CREATE POLICY "Only admins can create challenges" 
  ON challenges FOR INSERT 
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Only admins can update challenges
CREATE POLICY "Only admins can update challenges" 
  ON challenges FOR UPDATE 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Only admins can delete challenges
CREATE POLICY "Only admins can delete challenges" 
  ON challenges FOR DELETE 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Create policies for admin_users table
-- Only admins can view admin_users
CREATE POLICY "Only admins can view admin_users" 
  ON admin_users FOR SELECT 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Only admins can create other admin users
CREATE POLICY "Only admins can create other admin users" 
  ON admin_users FOR INSERT 
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Only admins can delete admin users
CREATE POLICY "Only admins can delete admin users" 
  ON admin_users FOR DELETE 
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE admin_users.user_id = auth.uid()
    )
  );

-- Create policies for challenge_participants table
-- Users can view their own participation
CREATE POLICY "Users can view their own participation" 
  ON challenge_participants FOR SELECT 
  TO authenticated
  USING (user_id = auth.uid());

-- Users can join challenges
CREATE POLICY "Users can join challenges" 
  ON challenge_participants FOR INSERT 
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Users can leave challenges
CREATE POLICY "Users can leave challenges" 
  ON challenge_participants FOR DELETE 
  TO authenticated
  USING (user_id = auth.uid());

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update updated_at timestamp
CREATE TRIGGER update_challenges_updated_at
BEFORE UPDATE ON challenges
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS challenges_type_idx ON challenges(type);
CREATE INDEX IF NOT EXISTS challenges_organization_id_idx ON challenges(organization_id);
CREATE INDEX IF NOT EXISTS challenge_participants_challenge_id_idx ON challenge_participants(challenge_id);
CREATE INDEX IF NOT EXISTS challenge_participants_user_id_idx ON challenge_participants(user_id);

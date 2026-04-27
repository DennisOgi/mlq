# Feature Implementation Guide

## ✅ Completed: Core Models & Services

I've created the foundational models and services for all 4 features:

### 1. Smart Daily Check-in with Mood Tracking
- ✅ `mood_entry_model.dart` - Complete mood tracking data model
- ✅ `mood_tracking_service.dart` - Service with AI insights

### 2. Skill Tree / Leadership Path
- ✅ `skill_tree_model.dart` - Skill and progress models
- ✅ `skill_tree_service.dart` - 15+ predefined skills across 5 categories

### 3. Avatar Customization
- ✅ `avatar_item_model.dart` - Avatar items and user avatar model

## 📋 Next Steps: Database Setup

### Required Supabase Tables

```sql
-- Mood Entries Table
CREATE TABLE mood_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  mood TEXT NOT NULL,
  note TEXT,
  triggers TEXT[] DEFAULT '{}',
  is_morning BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mood_entries_user_id ON mood_entries(user_id);
CREATE INDEX idx_mood_entries_timestamp ON mood_entries(timestamp);

-- User Skill Progress Table
CREATE TABLE user_skill_progress (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  category_xp JSONB NOT NULL DEFAULT '{}',
  unlocked_skill_ids TEXT[] DEFAULT '{}',
  unlocked_abilities TEXT[] DEFAULT '{}',
  total_skill_points INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Avatar Items Table
CREATE TABLE avatar_items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  rarity TEXT NOT NULL,
  image_asset TEXT NOT NULL,
  coin_cost INTEGER NOT NULL,
  is_premium BOOLEAN DEFAULT FALSE,
  unlock_condition TEXT,
  is_seasonal_item BOOLEAN DEFAULT FALSE,
  available_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Avatar Table
CREATE TABLE user_avatars (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  selected_hair TEXT,
  selected_face TEXT,
  selected_outfit TEXT,
  selected_accessory TEXT,
  selected_background TEXT,
  owned_item_ids TEXT[] DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Teacher Dashboard: Class Analytics View
CREATE TABLE class_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES organizations(id),
  class_name TEXT NOT NULL,
  teacher_id UUID REFERENCES auth.users(id),
  student_ids UUID[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 🎨 UI Screens to Create

### 1. Mood Check-in Screen
**File**: `lib/screens/mood/mood_checkin_screen.dart`

**Features**:
- Morning/Evening toggle
- Emoji mood selector (10 moods)
- Trigger selection (chips)
- Optional note input
- AI-generated response
- Mood trends graph

### 2. Skill Tree Screen
**File**: `lib/screens/skills/skill_tree_screen.dart`

**Features**:
- 5 category tabs
- Visual skill tree with connections
- Locked/unlocked states
- Progress bars per category
- Skill detail modal
- Unlock animations

### 3. Avatar Customization Screen
**File**: `lib/screens/avatar/avatar_customization_screen.dart`

**Features**:
- Live avatar preview
- Category tabs (hair, face, outfit, etc.)
- Item grid with rarity indicators
- Coin cost display
- Purchase confirmation
- Seasonal items section

### 4. Teacher Dashboard Screen
**File**: `lib/screens/teacher/teacher_dashboard_screen.dart`

**Features**:
- Class selector dropdown
- Student list with progress
- Aggregate statistics
- Goal completion rates
- Mood trends (anonymized)
- Export reports button

## 🔗 Integration Points

### Update Existing Files:

1. **lib/models/models.dart**
```dart
export 'mood_entry_model.dart';
export 'skill_tree_model.dart';
export 'avatar_item_model.dart';
```

2. **lib/providers/user_provider.dart**
- Add skill XP tracking
- Add avatar state management

3. **lib/screens/home/home_screen.dart**
- Add mood check-in prompt
- Show skill progress widget
- Display avatar

4. **lib/services/badge_service.dart**
- Add badges for mood tracking streaks
- Add badges for skill unlocks

5. **Goal Completion Flow**
- Award skill XP based on goal category
- Update in `lib/providers/goal_provider.dart`

## 📱 Quick Implementation Priority

### Phase 1 (This Week)
1. Set up database tables
2. Create Mood Check-in Screen
3. Integrate mood prompts in home screen

### Phase 2 (Next Week)
4. Create Skill Tree Screen
5. Integrate skill XP awards
6. Add skill unlock notifications

### Phase 3 (Week 3)
7. Create Avatar Customization Screen
8. Add avatar items to database
9. Show avatars on leaderboard/profiles

### Phase 4 (Week 4)
10. Create Teacher Dashboard
11. Add class management features
12. Implement analytics queries

## 🎯 Would you like me to:

A) Create the UI screens (mood check-in, skill tree, avatar, teacher dashboard)
B) Set up the database migration scripts
C) Create the provider classes for state management
D) Implement the integration points in existing screens

Let me know which part you'd like me to tackle next!

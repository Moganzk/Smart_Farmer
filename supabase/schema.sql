-- ===========================================
-- Smart Farmer - Supabase Database Schema
-- ===========================================
-- Run this file in Supabase SQL Editor to set up the database.
-- This creates all tables, triggers, indexes, and functions.
-- 
-- Order of execution:
-- 1. schema.sql (this file)
-- 2. rls_policies.sql (Row Level Security)
-- ===========================================

-- ===========================================
-- EXTENSIONS
-- ===========================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ===========================================
-- HELPER FUNCTIONS
-- ===========================================

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- PROFILES TABLE
-- ===========================================
-- Stores user profile information.
-- id links to auth.users.id (Supabase Auth)

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone TEXT,
  email TEXT,
  name TEXT,
  location TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  profile_image_url TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  device_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Indexes for profiles
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_updated_at ON profiles(updated_at);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- SCANS TABLE
-- ===========================================
-- Stores crop scan records.
-- Each scan belongs to a user and may have one or more diagnoses.

CREATE TABLE IF NOT EXISTS scans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  image_path TEXT NOT NULL,
  image_server_url TEXT,
  crop_type TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  local_id TEXT, -- Client-generated UUID for mapping/debug
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Indexes for scans
CREATE INDEX IF NOT EXISTS idx_scans_user_id ON scans(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_updated_at ON scans(updated_at);
CREATE INDEX IF NOT EXISTS idx_scans_local_id ON scans(local_id);
CREATE INDEX IF NOT EXISTS idx_scans_scanned_at ON scans(scanned_at DESC);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_scans_updated_at ON scans;
CREATE TRIGGER update_scans_updated_at
  BEFORE UPDATE ON scans
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- DIAGNOSES TABLE
-- ===========================================
-- Stores disease diagnosis results for each scan.
-- Each diagnosis links to one scan.

CREATE TABLE IF NOT EXISTS diagnoses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  scan_id UUID NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  disease_name TEXT NOT NULL,
  confidence DOUBLE PRECISION NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  recommendations JSONB NOT NULL DEFAULT '[]'::jsonb,
  diagnosed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  local_id TEXT, -- Client-generated UUID for mapping/debug
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Indexes for diagnoses
CREATE INDEX IF NOT EXISTS idx_diagnoses_scan_id ON diagnoses(scan_id);
CREATE INDEX IF NOT EXISTS idx_diagnoses_user_id ON diagnoses(user_id);
CREATE INDEX IF NOT EXISTS idx_diagnoses_updated_at ON diagnoses(updated_at);
CREATE INDEX IF NOT EXISTS idx_diagnoses_local_id ON diagnoses(local_id);
CREATE INDEX IF NOT EXISTS idx_diagnoses_disease_name ON diagnoses(disease_name);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_diagnoses_updated_at ON diagnoses;
CREATE TRIGGER update_diagnoses_updated_at
  BEFORE UPDATE ON diagnoses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- TIPS TABLE
-- ===========================================
-- Stores farming tips and advisories.
-- Tips are pulled by all users (public read).
-- Only admins can create/update/delete tips.

CREATE TABLE IF NOT EXISTS tips (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  language TEXT NOT NULL DEFAULT 'en',
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL,
  image_url TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Indexes for tips
CREATE INDEX IF NOT EXISTS idx_tips_language ON tips(language);
CREATE INDEX IF NOT EXISTS idx_tips_category ON tips(category);
CREATE INDEX IF NOT EXISTS idx_tips_updated_at ON tips(updated_at);
CREATE INDEX IF NOT EXISTS idx_tips_published_at ON tips(published_at DESC);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_tips_updated_at ON tips;
CREATE TRIGGER update_tips_updated_at
  BEFORE UPDATE ON tips
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- NOTIFICATIONS TABLE
-- ===========================================
-- Stores per-user notifications.
-- Each notification belongs to one user.

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'system' CHECK (type IN ('system', 'tip', 'scan_result', 'reminder', 'promotion')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  read BOOLEAN NOT NULL DEFAULT FALSE,
  data JSONB,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_updated_at ON notifications(updated_at);
CREATE INDEX IF NOT EXISTS idx_notifications_received_at ON notifications(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(user_id, read) WHERE read = FALSE;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_notifications_updated_at ON notifications;
CREATE TRIGGER update_notifications_updated_at
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- HELPER: Create profile on user signup
-- ===========================================
-- Automatically creates a profile when a new user signs up via Supabase Auth.

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, phone, email, name)
  VALUES (
    NEW.id,
    NEW.phone,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ===========================================
-- STORAGE BUCKET (optional)
-- ===========================================
-- Uncomment to create a storage bucket for scan images
-- Run this separately in Supabase Dashboard > Storage

-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('scan-images', 'scan-images', false)
-- ON CONFLICT (id) DO NOTHING;

-- ===========================================
-- SEED DATA: Sample tips (for testing)
-- ===========================================
-- Uncomment to insert sample tips

-- INSERT INTO tips (language, title, content, category, published_at)
-- VALUES 
--   ('en', 'Water Management', 'Proper irrigation prevents both drought stress and root rot.', 'irrigation', NOW()),
--   ('en', 'Early Detection', 'Scan leaves at first sign of discoloration for accurate diagnosis.', 'disease_prevention', NOW()),
--   ('en', 'Crop Rotation', 'Rotating crops annually helps break disease cycles.', 'best_practices', NOW())
-- ON CONFLICT DO NOTHING;

-- ===========================================
-- VERIFICATION QUERIES (run to verify setup)
-- ===========================================
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
-- SELECT * FROM profiles LIMIT 5;
-- SELECT * FROM tips LIMIT 5;

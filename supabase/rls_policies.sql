-- ===========================================
-- Smart Farmer - Row Level Security (RLS) Policies
-- ===========================================
-- Run this file AFTER schema.sql in Supabase SQL Editor.
-- Enables RLS and creates policies for secure data access.
-- 
-- POLICY RULES:
-- - profiles: Users can read/update their own profile
-- - scans: Users can CRUD only their own scans
-- - diagnoses: Users can CRUD only their own diagnoses
-- - tips: Public read, admin-only write
-- - notifications: Users can CRUD only their own notifications
-- ===========================================

-- ===========================================
-- ENABLE RLS ON ALL TABLES
-- ===========================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE diagnoses ENABLE ROW LEVEL SECURITY;
ALTER TABLE tips ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- ===========================================
-- HELPER: Check if user is admin
-- ===========================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- PROFILES POLICIES
-- ===========================================
-- Users can read and update their own profile only

-- Drop existing policies (safe for re-run)
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- SELECT: Users can view their own profile
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- INSERT: Users can create their own profile (handled by trigger, but allow manual)
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- UPDATE: Users can update their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ===========================================
-- SCANS POLICIES
-- ===========================================
-- Users can only access their own scans

DROP POLICY IF EXISTS "Users can view own scans" ON scans;
DROP POLICY IF EXISTS "Users can insert own scans" ON scans;
DROP POLICY IF EXISTS "Users can update own scans" ON scans;
DROP POLICY IF EXISTS "Users can delete own scans" ON scans;

-- SELECT: Users can view their own scans
CREATE POLICY "Users can view own scans"
ON scans FOR SELECT
USING (auth.uid() = user_id);

-- INSERT: Users can create scans for themselves
CREATE POLICY "Users can insert own scans"
ON scans FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can update their own scans
CREATE POLICY "Users can update own scans"
ON scans FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- DELETE: Users can soft-delete their own scans
CREATE POLICY "Users can delete own scans"
ON scans FOR DELETE
USING (auth.uid() = user_id);

-- ===========================================
-- DIAGNOSES POLICIES
-- ===========================================
-- Users can only access their own diagnoses

DROP POLICY IF EXISTS "Users can view own diagnoses" ON diagnoses;
DROP POLICY IF EXISTS "Users can insert own diagnoses" ON diagnoses;
DROP POLICY IF EXISTS "Users can update own diagnoses" ON diagnoses;
DROP POLICY IF EXISTS "Users can delete own diagnoses" ON diagnoses;

-- SELECT: Users can view their own diagnoses
CREATE POLICY "Users can view own diagnoses"
ON diagnoses FOR SELECT
USING (auth.uid() = user_id);

-- INSERT: Users can create diagnoses for themselves
CREATE POLICY "Users can insert own diagnoses"
ON diagnoses FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- UPDATE: Users can update their own diagnoses
CREATE POLICY "Users can update own diagnoses"
ON diagnoses FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- DELETE: Users can soft-delete their own diagnoses
CREATE POLICY "Users can delete own diagnoses"
ON diagnoses FOR DELETE
USING (auth.uid() = user_id);

-- ===========================================
-- TIPS POLICIES
-- ===========================================
-- Public read, admin-only write

DROP POLICY IF EXISTS "Anyone can view published tips" ON tips;
DROP POLICY IF EXISTS "Admins can insert tips" ON tips;
DROP POLICY IF EXISTS "Admins can update tips" ON tips;
DROP POLICY IF EXISTS "Admins can delete tips" ON tips;

-- SELECT: Anyone can view published tips (no auth required)
CREATE POLICY "Anyone can view published tips"
ON tips FOR SELECT
USING (
  deleted_at IS NULL 
  AND (published_at IS NULL OR published_at <= NOW())
);

-- INSERT: Only admins can create tips
CREATE POLICY "Admins can insert tips"
ON tips FOR INSERT
WITH CHECK (is_admin());

-- UPDATE: Only admins can update tips
CREATE POLICY "Admins can update tips"
ON tips FOR UPDATE
USING (is_admin())
WITH CHECK (is_admin());

-- DELETE: Only admins can delete tips
CREATE POLICY "Admins can delete tips"
ON tips FOR DELETE
USING (is_admin());

-- ===========================================
-- NOTIFICATIONS POLICIES
-- ===========================================
-- Users can only access their own notifications

DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
DROP POLICY IF EXISTS "Admins can insert notifications for any user" ON notifications;

-- SELECT: Users can view their own notifications
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
USING (auth.uid() = user_id);

-- INSERT: Users can create notifications for themselves
CREATE POLICY "Users can insert own notifications"
ON notifications FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- INSERT: Admins can create notifications for any user (for system notifications)
CREATE POLICY "Admins can insert notifications for any user"
ON notifications FOR INSERT
WITH CHECK (is_admin());

-- UPDATE: Users can update their own notifications (e.g., mark as read)
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- DELETE: Users can delete their own notifications
CREATE POLICY "Users can delete own notifications"
ON notifications FOR DELETE
USING (auth.uid() = user_id);

-- ===========================================
-- STORAGE POLICIES (if using Supabase Storage)
-- ===========================================
-- Uncomment if you created the scan-images bucket

-- -- Users can upload their own scan images
-- CREATE POLICY "Users can upload scan images"
-- ON storage.objects FOR INSERT
-- WITH CHECK (
--   bucket_id = 'scan-images' 
--   AND auth.uid()::text = (storage.foldername(name))[1]
-- );

-- -- Users can view their own scan images
-- CREATE POLICY "Users can view own scan images"
-- ON storage.objects FOR SELECT
-- USING (
--   bucket_id = 'scan-images' 
--   AND auth.uid()::text = (storage.foldername(name))[1]
-- );

-- -- Users can delete their own scan images
-- CREATE POLICY "Users can delete own scan images"
-- ON storage.objects FOR DELETE
-- USING (
--   bucket_id = 'scan-images' 
--   AND auth.uid()::text = (storage.foldername(name))[1]
-- );

-- ===========================================
-- VERIFICATION QUERIES
-- ===========================================
-- Run these to verify RLS is properly configured:

-- Check RLS is enabled:
-- SELECT tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE schemaname = 'public';

-- List all policies:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies 
-- WHERE schemaname = 'public';

-- ===========================================
-- SUMMARY
-- ===========================================
-- Table          | SELECT      | INSERT      | UPDATE      | DELETE
-- --------------|-------------|-------------|-------------|-------------
-- profiles      | own only    | own only    | own only    | N/A
-- scans         | own only    | own only    | own only    | own only
-- diagnoses     | own only    | own only    | own only    | own only
-- tips          | public      | admin only  | admin only  | admin only
-- notifications | own only    | own/admin   | own only    | own only

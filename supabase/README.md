# Supabase Database Setup

This folder contains SQL migration files for setting up the Smart Farmer Supabase database.

## Quick Start

1. **Create a Supabase Project**
   - Go to [supabase.com](https://supabase.com) and create a new project
   - Note your project URL and anon key

2. **Run the SQL Files**
   - Go to Supabase Dashboard → SQL Editor
   - Run `schema.sql` first (creates tables, indexes, triggers)
   - Run `rls_policies.sql` second (enables Row Level Security)

3. **Configure EAS Secrets**
   ```bash
   # Set your Supabase credentials for EAS builds
   eas secret:create --scope project --name EXPO_PUBLIC_SUPABASE_URL --value "https://your-project.supabase.co"
   eas secret:create --scope project --name EXPO_PUBLIC_SUPABASE_ANON_KEY --value "your-anon-key"
   ```

4. **Enable Phone Auth (Optional)**
   - Go to Authentication → Providers → Phone
   - Enable phone auth and configure Twilio (for SMS OTP)
   - Or use email magic links instead

## Files

| File | Description |
|------|-------------|
| `schema.sql` | Database tables, indexes, triggers, and functions |
| `rls_policies.sql` | Row Level Security policies for all tables |

## Tables

| Table | Description | RLS |
|-------|-------------|-----|
| `profiles` | User profiles (linked to auth.users) | Own only |
| `scans` | Crop scan records with images | Own only |
| `diagnoses` | Disease diagnosis results | Own only |
| `tips` | Farming tips and advisories | Public read, admin write |
| `notifications` | Per-user notifications | Own only |

## Sync Architecture

```
┌─────────────────────┐         ┌─────────────────────┐
│   Mobile Device     │         │     Supabase        │
│   (SQLite - SoT)    │ ──────▶ │   (Sync Target)     │
├─────────────────────┤  push   ├─────────────────────┤
│ scans               │ ──────▶ │ scans               │
│ diagnoses           │ ──────▶ │ diagnoses           │
├─────────────────────┤         ├─────────────────────┤
│ tips                │ ◀────── │ tips                │
│ notifications       │ ◀────── │ notifications       │
└─────────────────────┘  pull   └─────────────────────┘
```

- **Push (client → server)**: scans, diagnoses
- **Pull (server → client)**: tips, notifications
- **Source of Truth**: SQLite on mobile device (offline-first)

## RLS Policy Summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| profiles | Own | Own | Own | - |
| scans | Own | Own | Own | Own |
| diagnoses | Own | Own | Own | Own |
| tips | Public | Admin | Admin | Admin |
| notifications | Own | Own/Admin | Own | Own |

## Testing

After running the migrations:

```sql
-- Verify tables exist
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Verify RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';

-- List all policies
SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public';
```

## Seed Data (Development)

Uncomment the seed data section at the bottom of `schema.sql` to insert sample tips for testing.

## Notes

- All timestamps use `TIMESTAMPTZ` (timezone-aware)
- Soft deletes via `deleted_at` column (tombstones)
- `updated_at` auto-updated via triggers
- `local_id` column stores client-generated UUID for mapping
- Profile created automatically on user signup via trigger

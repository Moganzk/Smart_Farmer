# Smart Farmer – AI Agent Instructions

**Offline-first crop disease detection app.** Mobile device is source of truth. Backend (Supabase) is for sync only.

## Architecture Overview

```
smart_farmer/          # React Native (Expo) mobile app - PRIMARY
├── db/                # SQLite database layer (source of truth)
│   ├── database.ts    # Schema, initDb(), getDatabase()
│   └── syncQueue.ts   # enqueueSync(), markSynced(), markFailed()
├── contexts/          # React contexts (AuthContext with AsyncStorage)
├── navigation/        # React Navigation (Root → Auth/Main/Scan stacks)
├── screens/           # auth/, main/, scan/ subdirectories
├── utils/             # logger.ts, deviceId.ts, supabase.ts
└── page.tsx           # Next.js admin dashboard (SEPARATE stack)

smart_farmer.tests/    # All tests (Jest + better-sqlite3)
docs/                  # Documentation only
```

## Non-Negotiable Rules

1. **SQLite first, always**: Every write goes to local DB before network. Use `enqueueSync()` after inserts.
2. **Never block on network**: UI success = local write success. Sync is background-only.
3. **Dual-stack separation**: `react-native` imports = mobile app. `next/*` imports = admin dashboard. Never mix.
4. **Mobile uses anon key only**: Never use `service_role` in client code.
5. **No localhost/tunnels**: Testing via `eas build` on physical devices only.

## Data Write Pattern (REQUIRED)

```typescript
// Example from screens/scan/ProcessingScreen.tsx
const db = getDatabase();
await db.runAsync('INSERT INTO scans (...) VALUES (...)', [...]);
enqueueSync('scans', localId, 'insert');  // Always enqueue after local write
```

## SQLite Schema Fields (every syncable table)

```typescript
local_id: TEXT PRIMARY KEY       // UUID, client-generated
server_id: TEXT                  // Nullable, set after sync
sync_status: 'pending'|'synced'|'failed'
updated_at: TEXT                 // ISO timestamp
deleted_at: TEXT                 // Tombstone (soft delete)
device_id: TEXT
version: INTEGER
```

Tables: `users`, `scans`, `diagnoses`, `tips`, `notifications`, `sync_queue`

## Key APIs

| Module | Function | Purpose |
|--------|----------|---------|
| `db/database.ts` | `initDb()` | Call on app startup |
| `db/database.ts` | `getDatabase()` | Get SQLite instance (sync methods: `runSync`, `getAllSync`) |
| `db/syncQueue.ts` | `enqueueSync(table, localId, op)` | Queue for background sync |
| `db/syncQueue.ts` | `markSynced(table, localId)` | After successful sync |
| `db/syncQueue.ts` | `markFailed(table, localId, error)` | On sync failure (increments retry) |
| `utils/logger.ts` | `logger.info/warn/error()` | Centralized logging (never console.log) |
| `contexts/AuthContext.tsx` | `useAuth()` | Auth state + AsyncStorage persistence |

## Navigation Structure

```
RootNavigator
├── SplashScreen
├── AuthNavigator (Login → OTP → ProfileSetup)
└── MainNavigator (Bottom Tabs)
    ├── Home
    ├── History
    ├── Tips
    └── Settings
        └── ScanNavigator (Scan → Preview → Processing → Results)
```

## Commands

```bash
# Run tests (from smart_farmer.tests/)
cd smart_farmer.tests && npm test

# Build for device (NO expo start, NO localhost)
cd smart_farmer && eas build --profile development --platform android

# Local build (faster, requires Android SDK)
eas build --profile development --platform android --local
```

## Testing Requirements

- **Location**: `smart_farmer.tests/` only (never inside smart_farmer/)
- **SQLite tests**: Use `better-sqlite3` mock (see `testDb.ts`, `setup.ts`)
- **Coverage**: Happy path + offline scenario for sync features
- **Mocks**: `mocks/react-native.js`, `mocks/react-navigation.js`

## Before Writing Code

1. **Search** existing patterns in `db/`, `screens/`, `utils/`
2. **Check** if feature touches sync → must use `enqueueSync()` pattern
3. **Verify** correct stack (mobile vs admin via imports)
4. **Add tests** in `smart_farmer.tests/`
5. **Use logger** from `utils/logger.ts` (never `console.log`)

## Decision Checklist

- [ ] Does this work offline?
- [ ] Is SQLite the first write?
- [ ] Called `enqueueSync()` after database write?
- [ ] Am I in the correct stack (mobile vs admin)?
- [ ] Using `logger` instead of `console.log`?
- [ ] Tests added in `smart_farmer.tests/`?

If any answer is "no", redesign before implementing.

## File Patterns to Follow

- **Screen with DB write**: `screens/scan/ProcessingScreen.tsx`
- **Auth flow**: `contexts/AuthContext.tsx`
- **Sync queue operations**: `db/syncQueue.ts`
- **SQLite schema**: `db/database.ts`
- **Integration tests**: `smart_farmer.tests/scanIntegration.test.ts`

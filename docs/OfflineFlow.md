# Offline Scan → History Flow

This document describes the offline scan workflow implemented in Tasks 9, 10, 12, and 13.

## Overview

The app supports a complete offline loop with bidirectional sync:

```
User takes photo → Processing → SQLite Write → History Display
                              ↓
                    scans table + diagnoses table
                              ↓
                    sync_queue (intent recorded)
                              ↓
                    syncWorker.runSyncOnce() → Supabase (push)
                              ↑
                    pullSync.runPullOnce() ← Supabase (pull tips/notifications)
```

**All operations work in airplane mode.** SQLite is the source of truth.

> ✅ **Task 10**: Sync queue records intent when data is written.
> ✅ **Task 12**: Sync worker pushes data to Supabase when called.
> ✅ **Task 13**: Pull sync fetches tips/notifications from Supabase with merge rules.

## Flow Diagram

```
┌─────────────────┐     ┌───────────────────┐     ┌─────────────────┐
│   ScanScreen    │────▶│ ProcessingScreen  │────▶│  ResultsScreen  │
│  (take photo)   │     │  (write to DB)    │     │ (show diagnosis)│
└─────────────────┘     └───────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌──────────────┐
                        │   SQLite     │
                        │ scans table  │◄──────┐
                        │diagnoses tbl │       │
                        └──────────────┘       │
                               │               │
                               ▼               │
                        ┌──────────────┐       │
                        │ sync_queue   │       │
                        │ (intent only)│       │
                        └──────────────┘       │
                               │               │
                               ▼               │
                        ┌──────────────┐       │
                        │ syncWorker   │       │
                        │runSyncOnce() │       │
                        └──────────────┘       │
                               │               │
                               ▼               │
                        ┌──────────────┐       │
                        │  Supabase    │       │
                        │ (when online)│       │
                        └──────────────┘       │
                                               │
                        ┌──────────────┐       │
                        │HistoryScreen │───────┘
                        │ (read from   │
                        │   SQLite)    │
                        └──────────────┘
```

## Components

### Scan Service (`db/scanService.ts`)

Pure SQLite operations for scan workflows.
**Now includes sync queue intent recording (Task 10).**

| Function | Purpose |
|----------|---------|
| `createScan(input)` | Insert scan record + queue sync intent |
| `createDiagnosis(input)` | Insert diagnosis + queue sync intent |
| `performScan(userId, imagePath, cropType)` | Full workflow: scan + mock detection + diagnosis |
| `getScanHistory(userId, limit)` | Get scans with diagnoses, newest first |
| `getScanById(localId)` | Get single scan with diagnosis |
| `mockDetectDisease()` | Returns static mock detection result |

### Screen Updates

#### ProcessingScreen
- Calls `performScan()` from scan service
- No network calls
- Creates scan + diagnosis records
- **Records sync intent to sync_queue**
- Navigates to Results with `scanLocalId`

#### HistoryScreen  
- Uses `getScanHistory()` on screen focus
- Displays: disease name, confidence bar, severity badge, date
- Auto-refreshes when navigating back from scan
- Shows "Offline data" indicator

#### ResultsScreen
- Uses `getScanById()` to load result
- Displays disease name, severity, confidence, recommendations
- Parses recommendations JSON array

## Sync Queue Intent (Task 10)

When offline data is written, the app records **intent to sync** in the `sync_queue` table.

### When Sync Intent is Recorded

| Action | Table | Operation | Queue Entry |
|--------|-------|-----------|-------------|
| Create scan | `scans` | `insert` | ✅ Yes |
| Create diagnosis | `diagnoses` | `insert` | ✅ Yes |
| Soft-delete scan | `scans` | `delete` | 🔜 Future |
| Update scan | `scans` | `update` | 🔜 Future |

### What Gets Queued

Each `sync_queue` entry contains:

```sql
table_name TEXT      -- 'scans' or 'diagnoses'
local_id TEXT        -- UUID of the record
operation TEXT       -- 'insert', 'update', or 'delete'
retry_count INTEGER  -- Always 0 for new entries
created_at TEXT      -- ISO timestamp
```

### Example Flow

```
1. User takes photo
2. createScan() inserts into scans table
3. enqueueSync('scans', localId, 'insert')  ← Sync intent recorded
4. createDiagnosis() inserts into diagnoses table
5. enqueueSync('diagnoses', localId, 'insert')  ← Sync intent recorded
6. User sees results (from SQLite)
7. sync_queue now has 2 entries waiting for future sync
```

### Error Handling

Sync queue writes are **non-blocking**:

```typescript
try {
  enqueueSync('scans', localId, 'insert');
  logger.info('Scan queued for sync', { localId });
} catch (error) {
  // Log but don't fail - user flow continues
  logger.error('Failed to queue scan for sync (non-blocking)', { localId, error });
}
```

If queue insertion fails, the user can still:
- See their scan results
- View scan in history
- Use the app normally

The record will be picked up by a future full-sync mechanism.

## Sync Worker (Task 12)

The sync worker pushes local data to Supabase. It is **PUSH ONLY** - no pulling from server.

### Sync Worker API (`db/syncWorker.ts`)

| Function | Purpose |
|----------|---------|
| `runSyncOnce(limit?, maxRetries?, client?)` | Process pending queue entries (main entry point) |
| `processSyncEntry(entry, client)` | Process single queue entry |
| `pushInsert(tableName, localId, client)` | Push insert operation to Supabase |
| `pushDelete(tableName, localId, client)` | Push soft delete to Supabase |
| `hasPendingSync()` | Check if there are pending items |
| `mapScanToServer(scan)` | Map local scan to server schema |
| `mapDiagnosisToServer(diagnosis)` | Map local diagnosis to server schema |

### How Sync Works

```
1. Call runSyncOnce()
2. Worker fetches pending items from sync_queue (oldest first)
3. For each entry:
   - Fetch local record from SQLite
   - Map fields to server schema
   - Push to Supabase (insert or update)
   - On success: markSynced() - updates sync_status, server_id, removes from queue
   - On failure: markFailed() - increments retry_count, stores error
4. Return summary with success/failure counts
```

### Schema Mapping

Local fields are mapped to server schema:

| Local Field | Server Field | Notes |
|-------------|--------------|-------|
| `local_id` | `id` | Used as server primary key |
| `user_local_id` | `user_id` | For scans |
| `scan_local_id` | `scan_id` | For diagnoses |
| `scanned_at` | `created_at` | For scans |
| `diagnosed_at` | `created_at` | For diagnoses |

### Retry Logic

- Entries start with `retry_count = 0`
- On failure, `retry_count` is incremented
- Entries with `retry_count >= maxRetries` are skipped
- Default `maxRetries = 5`

### Usage Example

```typescript
import { runSyncOnce, hasPendingSync } from '../db/syncWorker';

// Check if sync needed
if (hasPendingSync()) {
  // Trigger sync (call when online)
  const result = await runSyncOnce();
  
  console.log(`Processed: ${result.processed}`);
  console.log(`Succeeded: ${result.succeeded}`);
  console.log(`Failed: ${result.failed}`);
}

// With custom limits
const result = await runSyncOnce(
  100,  // limit: max 100 entries
  3     // maxRetries: skip entries with 3+ failures
);
```

### Soft Deletes

When syncing a delete operation:
1. Worker fetches the local record with `deleted_at` timestamp
2. Pushes UPDATE to server with `deleted_at`, `updated_at`, `version`
3. Server record is tombstoned (not hard deleted)

## Database Schema

### scans table
```sql
local_id TEXT PRIMARY KEY      -- UUID, client-generated
user_local_id TEXT             -- FK to user
image_path TEXT                -- Local file path
crop_type TEXT                 -- Optional crop type
scanned_at TEXT                -- ISO timestamp
sync_status TEXT DEFAULT 'pending'
device_id TEXT
-- ... other sync fields
```

### diagnoses table
```sql
local_id TEXT PRIMARY KEY
scan_local_id TEXT             -- FK to scans.local_id
disease_name TEXT
confidence REAL                -- 0.0 - 1.0
severity TEXT                  -- 'low' | 'medium' | 'high'
recommendations TEXT           -- JSON array string
diagnosed_at TEXT
sync_status TEXT DEFAULT 'pending'
-- ... other sync fields
```

### sync_queue table
```sql
id INTEGER PRIMARY KEY         -- Auto-increment
table_name TEXT               -- 'scans', 'diagnoses', etc.
local_id TEXT                 -- FK to record's local_id
operation TEXT                -- 'insert' | 'update' | 'delete'
payload TEXT                  -- Optional JSON snapshot
retry_count INTEGER DEFAULT 0 -- Incremented on failure
last_error TEXT               -- Error message from last attempt
created_at TEXT               -- When queued
last_attempted_at TEXT        -- When last sync attempted
```

## What is Mocked vs Real

| Component | Status | Notes |
|-----------|--------|-------|
| Camera capture | **REAL** | Uses expo-camera |
| Image storage | **REAL** | Saved to local file system |
| SQLite writes | **REAL** | Full offline database |
| Sync queue writes | **REAL** | Records intent to sync (Task 10) |
| Sync worker (push) | **REAL** | Push-only, manual trigger (Task 12) |
| Pull sync (down) | **REAL** | Tips/notifications, manual trigger (Task 13) |
| Disease detection | **MOCKED** | Returns static "Late Blight" |
| ML inference | **NOT IMPLEMENTED** | Future task |
| Supabase sync | **REAL** | Push + Pull, when triggered manually |
| Background timer | **NOT IMPLEMENTED** | No automatic polling |
| Network calls | **CONDITIONAL** | Only when sync is triggered |

### Mock Detection Result

The `mockDetectDisease()` function returns:

```typescript
{
  diseaseName: 'Late Blight',
  confidence: 0.87,
  severity: 'medium',
  recommendations: [
    'Remove and destroy infected plant parts',
    'Apply copper-based fungicide',
    'Improve air circulation around plants',
    'Avoid overhead watering',
    'Monitor nearby plants for signs of infection',
  ],
}
```

## Testing

### Integration Tests

Path: `smart_farmer.tests/integration/offlineFlow.test.ts`

Test cases:
1. ✅ Create scan with proper fields
2. ✅ Create scan with optional fields null
3. ✅ Generate unique local_id for each scan
4. ✅ Create diagnosis linked to scan
5. ✅ Full scan workflow creates both records
6. ✅ Get scan by ID returns joined data
7. ✅ History returns scans for user
8. ✅ History excludes other users' scans
9. ✅ History ordered by newest first
10. ✅ History respects limit parameter
11. ✅ Soft-deleted scans excluded
12. ✅ Scans with deleted diagnoses excluded
13. ✅ Referential integrity maintained
14. ✅ sync_status = 'pending' for new records
15. ✅ Recommendations preserved as valid JSON

### Sync Intent Tests (Task 10)

Path: `smart_farmer.tests/integration/syncIntent.test.ts`

Test cases:
1. ✅ Creating scan inserts sync_queue entry
2. ✅ retry_count defaults to 0
3. ✅ created_at timestamp is set
4. ✅ last_error is null for new entries
5. ✅ Creating diagnosis inserts sync_queue entry
6. ✅ performScan creates 2 queue entries (scan + diagnosis)
7. ✅ Multiple scans accumulate queue entries
8. ✅ Queue entries have correct table_name and local_id
9. ✅ Entries persist across DB operations
10. ✅ sync_status remains 'pending' (no actual sync)
11. ✅ server_id remains null (no actual sync)

### Sync Worker Tests (Task 12)

Path: `smart_farmer.tests/integration/syncWorker.test.ts`

Test cases:
1. ✅ Return empty result when queue is empty
2. ✅ Process pending scan insert
3. ✅ Process pending diagnosis insert
4. ✅ Process entries in FIFO order
5. ✅ Map scan fields correctly to server schema
6. ✅ Map diagnosis fields correctly to server schema
7. ✅ Mark record as failed on Supabase error
8. ✅ Increment retry_count on each failure
9. ✅ Skip entries that exceed maxRetries
10. ✅ Continue processing after individual failure
11. ✅ Push soft delete to server
12. ✅ Respect limit parameter
13. ✅ Handle missing local record gracefully
14. ✅ Handle unsupported table gracefully
15. ✅ Handle null fields in scan
16. ✅ Set server_id on successful sync
17. ✅ Sync scan and diagnosis in correct order
18. ✅ Allow retry after transient failure

Run tests:
```bash
cd smart_farmer.tests
npm run test:integration    # Integration tests only (88 tests)
npm run test:all            # All tests (188 tests)
```

## Known Limitations

1. **No real ML inference** - Disease detection is mocked
2. **No automatic sync** - Sync must be triggered manually via `runSyncOnce()` / `runPullOnce()`
3. **No background timer** - No periodic polling for sync
4. **Single mock result** - Every scan returns "Late Blight"
5. **No image analysis** - Captured image is not processed
6. **No crop type detection** - Must be manually selected (future feature)
7. **No connectivity checks** - App doesn't detect online/offline state

## Pull Sync (Task 13)

The pull sync (downsync) fetches server updates and merges into SQLite with deterministic conflict resolution.

### Pull Sync API (`db/pullSync.ts`)

| Function | Purpose |
|----------|---------|
| `runPullOnce(limit?, deviceId?, client?)` | Main entry point - pulls tips + notifications |
| `pullTips(since, limit, deviceId, client)` | Fetch and merge tips from server |
| `pullNotifications(since, limit, deviceId, client)` | Fetch and merge notifications from server |
| `mergeTip(serverRecord, deviceId)` | Apply merge rules for a single tip |
| `mergeNotification(serverRecord, deviceId)` | Apply merge rules for a single notification |
| `getLastPullAt(tableName)` | Get last sync checkpoint for a table |
| `setLastPullAt(tableName, timestamp)` | Store sync checkpoint |

### Tables in Scope

Pull sync currently supports:
- **tips** - Agricultural tips from server
- **notifications** - User notifications

Tables NOT pulled (user-generated, push-only):
- scans
- diagnoses
- users

### Merge Rules (Deterministic)

When a server record arrives, the following rules are applied **in order**:

| Rule | Condition | Action |
|------|-----------|--------|
| **RULE 1** | Local record does NOT exist | INSERT with `sync_status='synced'` |
| **RULE 2** | Local exists AND `sync_status='pending'` | SKIP (don't overwrite pending local changes) |
| **RULE 3** | Local exists AND `local.updated_at >= server.updated_at` | SKIP (local is same or newer) |
| **RULE 4** | Server is newer AND local is synced | UPDATE local with server data |
| **RULE 5** | `server.deleted_at` is set | Apply tombstone to local record |

### Checkpoint Storage (`sync_meta` table)

Pull sync uses a separate table to track last sync timestamps:

```sql
CREATE TABLE IF NOT EXISTS sync_meta (
  table_name TEXT PRIMARY KEY,
  last_pull_at TEXT,           -- ISO timestamp of last successful pull
  last_push_at TEXT,           -- Reserved for future use
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

On each pull:
1. Read `last_pull_at` for the table
2. Fetch server records WHERE `updated_at > last_pull_at`
3. Merge each record
4. Update `last_pull_at` to the max `updated_at` seen

### Usage Example

```typescript
import { runPullOnce, getLastPullAt } from '../db/pullSync';

// Trigger pull sync (call when online)
const result = await runPullOnce();

console.log(`Tips: ${result.tips.processed} processed, ${result.tips.inserted} new`);
console.log(`Notifications: ${result.notifications.processed} processed`);

// Check last sync time
const lastSync = getLastPullAt('tips');
console.log(`Last pulled tips at: ${lastSync}`);

// With custom parameters
const result2 = await runPullOnce(
  100,           // limit: max 100 records per table
  deviceId,      // deviceId: for new record attribution
  customClient   // optional: custom Supabase client (for testing)
);
```

### Pull Sync Result

```typescript
interface PullResult {
  tips: TablePullResult;
  notifications: TablePullResult;
  lastPullAt: string;  // When this pull completed
}

interface TablePullResult {
  processed: number;      // Total server records processed
  inserted: number;       // New records inserted
  updated: number;        // Existing records updated
  deleted: number;        // Records tombstoned
  skipped_pending: number;    // Skipped due to pending local changes
  skipped_local_newer: number; // Skipped because local is newer
  errors: number;         // Failed merges
}
```

### Pull Sync Tests (Task 13)

Path: `smart_farmer.tests/integration/pullSync.test.ts`

Test cases (19 total):
1. ✅ Return empty results when server returns no data
2. ✅ Insert new tip when local does not exist (RULE 1)
3. ✅ Insert new notification when local does not exist
4. ✅ Skip pending tip (don't overwrite local pending changes) (RULE 2)
5. ✅ Skip when local tip is newer than server (RULE 3)
6. ✅ Overwrite local tip when server is newer (RULE 4)
7. ✅ Apply tombstone when server has deleted_at (RULE 5)
8. ✅ Skip pending notification (RULE 2)
9. ✅ Update synced notification when server is newer (RULE 4)
10. ✅ Store and retrieve lastSync checkpoint
11. ✅ Update lastSync after successful pull
12. ✅ Use lastSync for incremental pulls
13. ✅ Handle Supabase error gracefully
14. ✅ Process multiple tips in single pull
15. ✅ Handle mixed operations (insert + skip + update)

Run tests:
```bash
cd smart_farmer.tests
npm run test:integration    # Integration tests (88 tests)
npm run test:all            # All tests (188 tests)
```

## Future Tasks

- [ ] Implement ML model for disease detection
- [x] ~~Add sync queue integration~~ ✅ Done (Task 10 - intent only)
- [x] ~~Implement sync worker~~ ✅ Done (Task 12 - push only)
- [x] ~~Add pull sync (server → local)~~ ✅ Done (Task 13 - tips/notifications)
- [ ] Add background sync timer/scheduler
- [ ] Add retry logic with exponential backoff
- [ ] Add network connectivity detection
- [ ] Add crop type detection/selection
- [ ] Implement scan history detail view with image
- [ ] Add ability to delete/archive scans

## Usage Example

```typescript
import { performScan, getScanHistory } from '../db/scanService';

// After capturing image
const scanLocalId = await performScan(
  user.local_id,
  '/path/to/captured/image.jpg',
  'Tomato'  // optional crop type
);
// This automatically:
// 1. Creates scan record in SQLite
// 2. Creates diagnosis record in SQLite
// 3. Queues both for future sync (sync_queue)

// Navigate to results
navigation.replace('Results', { scanId: scanLocalId });

// On History screen
const history = getScanHistory(user.local_id, 50);
// Returns array of ScanWithDiagnosis objects

// Check pending sync items (for debugging)
// SELECT * FROM sync_queue WHERE retry_count = 0
```

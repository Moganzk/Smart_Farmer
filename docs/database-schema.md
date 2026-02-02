# SQLite Database Schema

This document describes the local SQLite database structure for the Smart Farmer mobile app.

## Overview

The mobile app uses SQLite as the **source of truth** for all data. This ensures full offline functionality. Data syncs to Supabase in the background when connectivity is available.

## Sync Metadata

Every syncable table includes these fields:

| Field | Type | Description |
|-------|------|-------------|
| `local_id` | TEXT (UUID) | Primary key, generated client-side |
| `server_id` | TEXT | Supabase record ID, null until synced |
| `sync_status` | TEXT | `pending` \| `synced` \| `failed` |
| `updated_at` | TEXT | ISO 8601 timestamp of last modification |
| `deleted_at` | TEXT | Tombstone timestamp (soft delete) |
| `device_id` | TEXT | Device that created/modified the record |
| `version` | INTEGER | Increments on each update (conflict resolution) |

## Tables

### users
Stores farmer profiles.

| Field | Type | Required |
|-------|------|----------|
| phone_number | TEXT | Yes |
| name | TEXT | No |
| language | TEXT | Yes (default: 'en') |
| profile_image_path | TEXT | No |
| created_at | TEXT | Yes |

### scans
Crop disease scan records.

| Field | Type | Required |
|-------|------|----------|
| user_local_id | TEXT (FK) | Yes |
| image_path | TEXT | Yes |
| image_server_url | TEXT | No |
| crop_type | TEXT | No |
| scanned_at | TEXT | Yes |
| latitude | REAL | No |
| longitude | REAL | No |

### diagnoses
AI diagnosis results for scans.

| Field | Type | Required |
|-------|------|----------|
| scan_local_id | TEXT (FK) | Yes |
| disease_name | TEXT | Yes |
| confidence | REAL | Yes (0.0-1.0) |
| severity | TEXT | No |
| recommendations | TEXT (JSON) | Yes |
| diagnosed_at | TEXT | Yes |

### tips
Farming tips and advisories.

| Field | Type | Required |
|-------|------|----------|
| title | TEXT | Yes |
| content | TEXT | Yes |
| category | TEXT | Yes |
| language | TEXT | Yes |
| image_url | TEXT | No |
| published_at | TEXT | Yes |

### notifications
In-app notifications.

| Field | Type | Required |
|-------|------|----------|
| user_local_id | TEXT (FK) | Yes |
| type | TEXT | Yes |
| title | TEXT | Yes |
| body | TEXT | Yes |
| read | INTEGER | Yes (0/1) |
| data | TEXT (JSON) | No |
| received_at | TEXT | Yes |

### sync_queue
Tracks pending sync operations.

| Field | Type | Description |
|-------|------|-------------|
| id | INTEGER | Auto-increment PK |
| table_name | TEXT | Source table |
| local_id | TEXT | Record ID |
| operation | TEXT | `insert` \| `update` \| `delete` |
| payload | TEXT (JSON) | Snapshot of record |
| retry_count | INTEGER | Failure count |
| last_error | TEXT | Last error message |
| created_at | TEXT | Queue time |
| last_attempted_at | TEXT | Last sync attempt |

## Indexes

Each table has indexes on:
- `sync_status` — for finding unsynced records
- `updated_at` — for ordering and conflict resolution

Foreign key tables also index their FK columns.

## Usage

```typescript
import { initDb, createSyncFields, enqueueSync } from '@/db';

// App startup
await initDb();

// Creating a record
const fields = await createSyncFields();
db.runSync(`INSERT INTO scans (...) VALUES (...)`, [...]);
enqueueSync('scans', fields.local_id, 'insert');

// Soft delete (tombstone)
softDelete('scans', localId);
```

## Sync Flow

1. **Write locally** → SQLite INSERT/UPDATE
2. **Queue for sync** → `enqueueSync(table, id, operation)`
3. **Background sync** → When online, process queue
4. **Mark result** → `markSynced()` or `markFailed()`

See [smart_farmer/db/syncQueue.ts](../smart_farmer/db/syncQueue.ts) for implementation.

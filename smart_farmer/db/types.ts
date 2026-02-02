/**
 * Smart Farmer - Database Types
 * Defines types for SQLite local database with sync metadata
 */

// Sync status for all syncable records
export type SyncStatus = 'pending' | 'synced' | 'failed';

// Sync queue operations
export type SyncOperation = 'insert' | 'update' | 'delete';

// Base fields required on all syncable tables
export interface SyncableRecord {
  local_id: string;        // UUID, primary key
  server_id: string | null; // Supabase record ID, null until synced
  sync_status: SyncStatus;
  updated_at: string;       // ISO 8601 timestamp
  deleted_at: string | null; // Tombstone timestamp, null if not deleted
  device_id: string;
  version: number;          // Incrementing version for conflict resolution
}

// User record
export interface User extends SyncableRecord {
  phone_number: string;
  name: string | null;
  language: string;         // 'en' | 'sw' (Kiswahili)
  profile_image_path: string | null;
  created_at: string;
}

// Scan record - crop disease scan
export interface Scan extends SyncableRecord {
  user_local_id: string;    // FK to users.local_id
  image_path: string;       // Local file path
  image_server_url: string | null; // Supabase storage URL after upload
  crop_type: string | null;
  scanned_at: string;       // ISO timestamp of scan
  latitude: number | null;
  longitude: number | null;
}

// Diagnosis record - result of disease detection
export interface Diagnosis extends SyncableRecord {
  scan_local_id: string;    // FK to scans.local_id
  disease_name: string;
  confidence: number;       // 0.0 - 1.0
  severity: string | null;  // 'low' | 'medium' | 'high'
  recommendations: string;  // JSON string array of recommendations
  diagnosed_at: string;
}

// Tip record - farming tips/advisories
export interface Tip extends SyncableRecord {
  title: string;
  content: string;
  category: string;         // e.g., 'prevention', 'treatment', 'general'
  language: string;
  image_url: string | null;
  published_at: string;
}

// Notification record
export interface Notification extends SyncableRecord {
  user_local_id: string;    // FK to users.local_id
  type: string;             // 'disease_alert' | 'advisory' | 'tip' | 'system'
  title: string;
  body: string;
  read: boolean;
  data: string | null;      // JSON payload for deep linking
  received_at: string;
}

// Sync queue entry
export interface SyncQueueEntry {
  id: number;               // Auto-increment PK
  table_name: string;
  local_id: string;
  operation: SyncOperation;
  payload: string | null;   // JSON snapshot of record at queue time
  retry_count: number;
  last_error: string | null;
  created_at: string;
  last_attempted_at: string | null;
}

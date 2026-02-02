/**
 * Smart Farmer - Test Database Module
 * 
 * Node.js compatible version of the database module for testing.
 * Uses better-sqlite3 which has the same API patterns as expo-sqlite.
 */

import Database from 'better-sqlite3';
import type { SyncStatus, SyncOperation, SyncQueueEntry } from '../smart_farmer/db/types';

// Test database instance
let db: Database.Database | null = null;

// Mock device ID for testing
const TEST_DEVICE_ID = 'test-device-id-12345';

/**
 * Get or create the test database (in-memory)
 */
export function getDatabase(): Database.Database {
  if (!db) {
    db = new Database(':memory:');
  }
  return db;
}

/**
 * Reset database for fresh test
 */
export function resetDatabase(): void {
  if (db) {
    db.close();
  }
  db = new Database(':memory:');
}

/**
 * Initialize database with all tables.
 * Safe to call multiple times (idempotent).
 */
export function initDb(): void {
  const database = getDatabase();

  // Enable foreign keys
  database.pragma('foreign_keys = ON');

  // Create users table
  database.exec(`
    CREATE TABLE IF NOT EXISTS users (
      local_id TEXT PRIMARY KEY NOT NULL,
      server_id TEXT,
      sync_status TEXT NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'failed')),
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      device_id TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      phone_number TEXT NOT NULL,
      name TEXT,
      language TEXT NOT NULL DEFAULT 'en',
      profile_image_path TEXT,
      created_at TEXT NOT NULL
    );
  `);

  // Create scans table
  database.exec(`
    CREATE TABLE IF NOT EXISTS scans (
      local_id TEXT PRIMARY KEY NOT NULL,
      server_id TEXT,
      sync_status TEXT NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'failed')),
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      device_id TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      user_local_id TEXT NOT NULL,
      image_path TEXT NOT NULL,
      image_server_url TEXT,
      crop_type TEXT,
      scanned_at TEXT NOT NULL,
      latitude REAL,
      longitude REAL,
      FOREIGN KEY (user_local_id) REFERENCES users(local_id)
    );
  `);

  // Create diagnoses table
  database.exec(`
    CREATE TABLE IF NOT EXISTS diagnoses (
      local_id TEXT PRIMARY KEY NOT NULL,
      server_id TEXT,
      sync_status TEXT NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'failed')),
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      device_id TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      scan_local_id TEXT NOT NULL,
      disease_name TEXT NOT NULL,
      confidence REAL NOT NULL,
      severity TEXT,
      recommendations TEXT NOT NULL,
      diagnosed_at TEXT NOT NULL,
      FOREIGN KEY (scan_local_id) REFERENCES scans(local_id)
    );
  `);

  // Create tips table
  database.exec(`
    CREATE TABLE IF NOT EXISTS tips (
      local_id TEXT PRIMARY KEY NOT NULL,
      server_id TEXT,
      sync_status TEXT NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'failed')),
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      device_id TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      category TEXT NOT NULL,
      language TEXT NOT NULL,
      image_url TEXT,
      published_at TEXT NOT NULL
    );
  `);

  // Create notifications table
  database.exec(`
    CREATE TABLE IF NOT EXISTS notifications (
      local_id TEXT PRIMARY KEY NOT NULL,
      server_id TEXT,
      sync_status TEXT NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'failed')),
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      device_id TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      user_local_id TEXT NOT NULL,
      type TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      read INTEGER NOT NULL DEFAULT 0,
      data TEXT,
      received_at TEXT NOT NULL,
      FOREIGN KEY (user_local_id) REFERENCES users(local_id)
    );
  `);

  // Create sync_queue table
  database.exec(`
    CREATE TABLE IF NOT EXISTS sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      local_id TEXT NOT NULL,
      operation TEXT NOT NULL CHECK (operation IN ('insert', 'update', 'delete')),
      payload TEXT,
      retry_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at TEXT NOT NULL,
      last_attempted_at TEXT,
      UNIQUE(table_name, local_id, operation)
    );
  `);

  // Create indexes
  database.exec(`
    CREATE INDEX IF NOT EXISTS idx_users_sync_status ON users(sync_status);
    CREATE INDEX IF NOT EXISTS idx_users_updated_at ON users(updated_at);
    CREATE INDEX IF NOT EXISTS idx_scans_sync_status ON scans(sync_status);
    CREATE INDEX IF NOT EXISTS idx_scans_updated_at ON scans(updated_at);
    CREATE INDEX IF NOT EXISTS idx_diagnoses_sync_status ON diagnoses(sync_status);
    CREATE INDEX IF NOT EXISTS idx_tips_sync_status ON tips(sync_status);
    CREATE INDEX IF NOT EXISTS idx_notifications_sync_status ON notifications(sync_status);
    CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(retry_count, created_at);
  `);
}

/**
 * Generate a UUID v4
 */
export function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * Get current ISO timestamp
 */
export function getISOTimestamp(): string {
  return new Date().toISOString();
}

/**
 * Get device ID (mocked for testing)
 */
export function getDeviceId(): string {
  return TEST_DEVICE_ID;
}

/**
 * Create default sync fields for a new record
 */
export function createSyncFields(): {
  local_id: string;
  server_id: null;
  sync_status: SyncStatus;
  updated_at: string;
  deleted_at: null;
  device_id: string;
  version: number;
} {
  return {
    local_id: generateUUID(),
    server_id: null,
    sync_status: 'pending',
    updated_at: getISOTimestamp(),
    deleted_at: null,
    device_id: getDeviceId(),
    version: 1,
  };
}

/**
 * Check if a table exists
 */
export function tableExists(tableName: string): boolean {
  const database = getDatabase();
  const result = database.prepare(
    `SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name=?`
  ).get(tableName) as { count: number } | undefined;
  return result ? result.count > 0 : false;
}

/**
 * Close the database
 */
export function closeDb(): void {
  if (db) {
    db.close();
    db = null;
  }
}

// ============ Sync Queue Functions ============

/**
 * Add a record to the sync queue
 */
export function enqueueSync(
  tableName: string,
  localId: string,
  operation: SyncOperation,
  payload?: Record<string, unknown>
): void {
  const database = getDatabase();
  const now = getISOTimestamp();
  const payloadJson = payload ? JSON.stringify(payload) : null;

  database.prepare(
    `INSERT INTO sync_queue (table_name, local_id, operation, payload, retry_count, created_at)
     VALUES (?, ?, ?, ?, 0, ?)
     ON CONFLICT(table_name, local_id, operation) 
     DO UPDATE SET payload = excluded.payload, retry_count = 0, last_error = NULL, created_at = excluded.created_at`
  ).run(tableName, localId, operation, payloadJson, now);
}

/**
 * Mark a record as successfully synced
 */
export function markSynced(
  tableName: string,
  localId: string,
  serverId?: string
): void {
  const database = getDatabase();
  const now = getISOTimestamp();

  if (serverId) {
    database.prepare(
      `UPDATE ${tableName} SET sync_status = 'synced', server_id = ?, updated_at = ? WHERE local_id = ?`
    ).run(serverId, now, localId);
  } else {
    database.prepare(
      `UPDATE ${tableName} SET sync_status = 'synced', updated_at = ? WHERE local_id = ?`
    ).run(now, localId);
  }

  database.prepare(
    `DELETE FROM sync_queue WHERE table_name = ? AND local_id = ?`
  ).run(tableName, localId);
}

/**
 * Mark a sync attempt as failed
 */
export function markFailed(
  tableName: string,
  localId: string,
  error?: string
): void {
  const database = getDatabase();
  const now = getISOTimestamp();
  const errorMessage = error || 'Unknown error';

  database.prepare(
    `UPDATE ${tableName} SET sync_status = 'failed' WHERE local_id = ?`
  ).run(localId);

  database.prepare(
    `UPDATE sync_queue 
     SET retry_count = retry_count + 1, last_error = ?, last_attempted_at = ?
     WHERE table_name = ? AND local_id = ?`
  ).run(errorMessage, now, tableName, localId);
}

/**
 * Get pending items from the sync queue
 */
export function getPendingQueue(
  limit: number = 50,
  maxRetries: number = 5
): SyncQueueEntry[] {
  const database = getDatabase();
  
  const results = database.prepare(
    `SELECT id, table_name, local_id, operation, payload, retry_count, last_error, created_at, last_attempted_at
     FROM sync_queue
     WHERE retry_count < ?
     ORDER BY created_at ASC
     LIMIT ?`
  ).all(maxRetries, limit) as SyncQueueEntry[];

  return results || [];
}

/**
 * Soft delete a record
 */
export function softDelete(tableName: string, localId: string): void {
  const database = getDatabase();
  const now = getISOTimestamp();

  database.prepare(
    `UPDATE ${tableName} 
     SET deleted_at = ?, sync_status = 'pending', version = version + 1, updated_at = ?
     WHERE local_id = ? AND deleted_at IS NULL`
  ).run(now, now, localId);

  enqueueSync(tableName, localId, 'delete');
}

/**
 * Get count of pending sync items
 */
export function getPendingCount(): number {
  const database = getDatabase();
  const result = database.prepare(
    `SELECT COUNT(*) as count FROM sync_queue`
  ).get() as { count: number } | undefined;
  return result?.count || 0;
}

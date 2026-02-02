/**
 * Smart Farmer - SQLite Database Module
 * 
 * Offline-first local database using expo-sqlite.
 * This is the SOURCE OF TRUTH for the mobile app.
 * All writes happen here FIRST, then sync to Supabase.
 */

import * as SQLite from 'expo-sqlite';
import { getDeviceId } from '../utils/deviceId';
import type { SyncStatus } from './types';

// Database instance - singleton
let db: SQLite.SQLiteDatabase | null = null;

// Database name
const DB_NAME = 'smart_farmer.db';

/**
 * Get or create the database instance
 */
export function getDatabase(): SQLite.SQLiteDatabase {
  if (!db) {
    db = SQLite.openDatabaseSync(DB_NAME);
  }
  return db;
}

/**
 * Initialize database with all tables.
 * Safe to call multiple times (idempotent).
 * Call this on app startup.
 */
export async function initDb(): Promise<void> {
  const database = getDatabase();

  // Enable foreign keys
  database.execSync('PRAGMA foreign_keys = ON;');

  // Create users table
  database.execSync(`
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
  database.execSync(`
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
  database.execSync(`
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
  database.execSync(`
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
  database.execSync(`
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
  database.execSync(`
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

  // Create indexes for efficient sync queries
  database.execSync(`
    CREATE INDEX IF NOT EXISTS idx_users_sync_status ON users(sync_status);
    CREATE INDEX IF NOT EXISTS idx_users_updated_at ON users(updated_at);
    CREATE INDEX IF NOT EXISTS idx_scans_sync_status ON scans(sync_status);
    CREATE INDEX IF NOT EXISTS idx_scans_updated_at ON scans(updated_at);
    CREATE INDEX IF NOT EXISTS idx_scans_user ON scans(user_local_id);
    CREATE INDEX IF NOT EXISTS idx_diagnoses_sync_status ON diagnoses(sync_status);
    CREATE INDEX IF NOT EXISTS idx_diagnoses_updated_at ON diagnoses(updated_at);
    CREATE INDEX IF NOT EXISTS idx_diagnoses_scan ON diagnoses(scan_local_id);
    CREATE INDEX IF NOT EXISTS idx_tips_sync_status ON tips(sync_status);
    CREATE INDEX IF NOT EXISTS idx_tips_updated_at ON tips(updated_at);
    CREATE INDEX IF NOT EXISTS idx_notifications_sync_status ON notifications(sync_status);
    CREATE INDEX IF NOT EXISTS idx_notifications_updated_at ON notifications(updated_at);
    CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_local_id);
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
 * Create default sync fields for a new record
 */
export async function createSyncFields(): Promise<{
  local_id: string;
  server_id: null;
  sync_status: SyncStatus;
  updated_at: string;
  deleted_at: null;
  device_id: string;
  version: number;
}> {
  return {
    local_id: generateUUID(),
    server_id: null,
    sync_status: 'pending',
    updated_at: getISOTimestamp(),
    deleted_at: null,
    device_id: await getDeviceId(),
    version: 1,
  };
}

/**
 * Close the database connection
 * Call this when app is terminating
 */
export function closeDb(): void {
  if (db) {
    db.closeSync();
    db = null;
  }
}

/**
 * Get table names that support sync
 */
export function getSyncableTables(): string[] {
  return ['users', 'scans', 'diagnoses', 'tips', 'notifications'];
}

/**
 * Check if a table exists
 */
export function tableExists(tableName: string): boolean {
  const database = getDatabase();
  const result = database.getFirstSync<{ count: number }>(
    `SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name=?`,
    [tableName]
  );
  return result ? result.count > 0 : false;
}

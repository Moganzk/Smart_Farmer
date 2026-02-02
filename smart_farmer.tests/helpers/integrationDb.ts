/**
 * Smart Farmer - Integration Test Database Helper
 * 
 * This module provides a real SQLite database for integration tests.
 * Uses better-sqlite3 which is Node.js compatible with the same API
 * patterns as expo-sqlite.
 * 
 * USAGE:
 * - Import this module in integration tests (*.integration.test.ts)
 * - Call resetDatabase() in beforeEach() for test isolation
 * - Use getDatabase() to access the SQLite instance
 * 
 * DO NOT use this in unit tests - use mocks instead.
 */

import Database from 'better-sqlite3';

// Test database instance (in-memory)
let db: Database.Database | null = null;

// Test device ID constant
export const TEST_DEVICE_ID = 'integration-test-device-001';

/**
 * Get the test database instance.
 * Creates a new in-memory database if none exists.
 */
export function getTestDb(): Database.Database {
  if (!db) {
    db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
  }
  return db;
}

/**
 * Reset the database completely.
 * Call this in beforeEach() to ensure test isolation.
 */
export function resetTestDb(): void {
  if (db) {
    db.close();
  }
  db = new Database(':memory:');
  db.pragma('foreign_keys = ON');
}

/**
 * Close the database connection.
 * Call this in afterAll() for cleanup.
 */
export function closeTestDb(): void {
  if (db) {
    db.close();
    db = null;
  }
}

/**
 * Initialize all tables in the test database.
 * Mirrors the schema from smart_farmer/db/database.ts
 */
export function initTestDb(): void {
  const database = getTestDb();

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
      longitude REAL
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
      diagnosed_at TEXT NOT NULL
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
      received_at TEXT NOT NULL
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
    CREATE INDEX IF NOT EXISTS idx_scans_sync_status ON scans(sync_status);
    CREATE INDEX IF NOT EXISTS idx_diagnoses_sync_status ON diagnoses(sync_status);
    CREATE INDEX IF NOT EXISTS idx_tips_sync_status ON tips(sync_status);
    CREATE INDEX IF NOT EXISTS idx_notifications_sync_status ON notifications(sync_status);
    CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(retry_count, created_at);
  `);
}

// ============ Utility Functions ============

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

// ============ Sync Queue Functions ============

/**
 * Add a record to the sync queue
 */
export function enqueueSync(
  tableName: string,
  localId: string,
  operation: 'insert' | 'update' | 'delete',
  payload?: Record<string, unknown>
): void {
  const database = getTestDb();
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
  const database = getTestDb();
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
  const database = getTestDb();
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
): Array<{
  id: number;
  table_name: string;
  local_id: string;
  operation: string;
  payload: string | null;
  retry_count: number;
  last_error: string | null;
  created_at: string;
  last_attempted_at: string | null;
}> {
  const database = getTestDb();
  
  return database.prepare(
    `SELECT id, table_name, local_id, operation, payload, retry_count, last_error, created_at, last_attempted_at
     FROM sync_queue
     WHERE retry_count < ?
     ORDER BY created_at ASC
     LIMIT ?`
  ).all(maxRetries, limit) as any[];
}

/** Sync queue entry type for testing */
export interface SyncQueueEntry {
  id: number;
  table_name: string;
  local_id: string;
  operation: string;
  payload: string | null;
  retry_count: number;
  last_error: string | null;
  created_at: string;
  last_attempted_at: string | null;
}

/**
 * Get sync queue entry by local_id
 * Useful for verifying a specific record was queued
 */
export function getSyncQueueEntryByLocalId(localId: string): SyncQueueEntry | null {
  const database = getTestDb();
  
  const row = database.prepare(
    `SELECT id, table_name, local_id, operation, payload, retry_count, last_error, created_at, last_attempted_at
     FROM sync_queue
     WHERE local_id = ?`
  ).get(localId) as SyncQueueEntry | undefined;

  return row || null;
}

/**
 * Get all sync queue entries for a table
 */
export function getSyncQueueEntriesByTable(tableName: string): SyncQueueEntry[] {
  const database = getTestDb();
  
  return database.prepare(
    `SELECT id, table_name, local_id, operation, payload, retry_count, last_error, created_at, last_attempted_at
     FROM sync_queue
     WHERE table_name = ?
     ORDER BY created_at ASC`
  ).all(tableName) as SyncQueueEntry[];
}

/**
 * Get total count of sync queue entries
 */
export function getSyncQueueCount(): number {
  const database = getTestDb();
  const row = database.prepare('SELECT COUNT(*) as count FROM sync_queue').get() as { count: number };
  return row.count;
}

/**
 * Clear all data from a table (for test cleanup)
 */
export function clearTable(tableName: string): void {
  const database = getTestDb();
  database.exec(`DELETE FROM ${tableName}`);
}

/**
 * Clear all tables (for full reset without recreating schema)
 */
export function clearAllTables(): void {
  const tables = ['sync_queue', 'notifications', 'diagnoses', 'scans', 'tips', 'users'];
  for (const table of tables) {
    clearTable(table);
  }
}

// ============ Scan Service Functions (mirror of db/scanService.ts) ============

/** Input for creating a new scan */
export interface CreateScanInput {
  userLocalId: string;
  imagePath: string;
  cropType?: string;
  latitude?: number;
  longitude?: number;
}

/** Input for creating a diagnosis */
export interface CreateDiagnosisInput {
  scanLocalId: string;
  diseaseName: string;
  confidence: number;
  severity?: 'low' | 'medium' | 'high';
  recommendations: string[];
}

/** Scan with joined diagnosis for history display */
export interface ScanWithDiagnosis {
  local_id: string;
  image_path: string;
  crop_type: string | null;
  scanned_at: string;
  disease_name: string;
  confidence: number;
  severity: string | null;
  recommendations: string;
}

/**
 * Create a new scan record in test database.
 * Mirrors createScan from db/scanService.ts
 * Now includes sync_queue write to mirror production behavior.
 */
export function createScan(input: CreateScanInput): string {
  const db = getTestDb();
  const localId = generateUUID();
  const now = getISOTimestamp();

  db.prepare(
    `INSERT INTO scans (
      local_id, server_id, sync_status, updated_at, deleted_at,
      device_id, version, user_local_id, image_path, image_server_url,
      crop_type, scanned_at, latitude, longitude
    ) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, ?, NULL, ?, ?, ?, ?)`
  ).run(
    localId,
    now,
    TEST_DEVICE_ID,
    input.userLocalId,
    input.imagePath,
    input.cropType || null,
    now,
    input.latitude || null,
    input.longitude || null
  );

  // Record sync intent (mirrors production scanService)
  enqueueSync('scans', localId, 'insert');

  return localId;
}

/**
 * Create a diagnosis record in test database.
 * Mirrors createDiagnosis from db/scanService.ts
 * Now includes sync_queue write to mirror production behavior.
 */
export function createDiagnosis(input: CreateDiagnosisInput): string {
  const db = getTestDb();
  const localId = generateUUID();
  const now = getISOTimestamp();
  const recommendationsJson = JSON.stringify(input.recommendations);

  db.prepare(
    `INSERT INTO diagnoses (
      local_id, server_id, sync_status, updated_at, deleted_at,
      device_id, version, scan_local_id, disease_name, confidence,
      severity, recommendations, diagnosed_at
    ) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, ?, ?, ?, ?, ?)`
  ).run(
    localId,
    now,
    TEST_DEVICE_ID,
    input.scanLocalId,
    input.diseaseName,
    input.confidence,
    input.severity || null,
    recommendationsJson,
    now
  );

  // Record sync intent (mirrors production scanService)
  enqueueSync('diagnoses', localId, 'insert');

  return localId;
}

/**
 * Get scan history for a user.
 * Mirrors getScanHistory from db/scanService.ts
 */
export function getScanHistory(
  userLocalId: string,
  limit: number = 50
): ScanWithDiagnosis[] {
  const db = getTestDb();
  
  return db.prepare(
    `SELECT 
      s.local_id,
      s.image_path,
      s.crop_type,
      s.scanned_at,
      d.disease_name,
      d.confidence,
      d.severity,
      d.recommendations
    FROM scans s
    INNER JOIN diagnoses d ON d.scan_local_id = s.local_id
    WHERE s.user_local_id = ?
      AND s.deleted_at IS NULL
      AND d.deleted_at IS NULL
    ORDER BY s.scanned_at DESC
    LIMIT ?`
  ).all(userLocalId, limit) as ScanWithDiagnosis[];
}

/**
 * Get a single scan by local_id with diagnosis.
 * Mirrors getScanById from db/scanService.ts
 */
export function getScanById(localId: string): ScanWithDiagnosis | null {
  const db = getTestDb();
  
  const row = db.prepare(
    `SELECT 
      s.local_id,
      s.image_path,
      s.crop_type,
      s.scanned_at,
      d.disease_name,
      d.confidence,
      d.severity,
      d.recommendations
    FROM scans s
    INNER JOIN diagnoses d ON d.scan_local_id = s.local_id
    WHERE s.local_id = ?
      AND s.deleted_at IS NULL
      AND d.deleted_at IS NULL`
  ).get(localId) as ScanWithDiagnosis | undefined;

  return row || null;
}

/**
 * Perform a full scan workflow in test environment.
 * Mirrors performScan from db/scanService.ts
 */
export function performScan(
  userLocalId: string,
  imagePath: string,
  cropType?: string
): string {
  // 1. Create scan record
  const scanLocalId = createScan({
    userLocalId,
    imagePath,
    cropType,
  });

  // 2. Create diagnosis with mock detection
  createDiagnosis({
    scanLocalId,
    diseaseName: 'Late Blight',
    confidence: 0.87,
    severity: 'medium',
    recommendations: [
      'Remove and destroy infected plant parts',
      'Apply copper-based fungicide',
      'Improve air circulation around plants',
    ],
  });

  return scanLocalId;
}

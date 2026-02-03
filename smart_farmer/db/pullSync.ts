/**
 * Smart Farmer - Pull Sync (Downsync) Module
 * 
 * Fetches server updates and merges into local SQLite.
 * PULL ONLY - does not push local changes to server.
 * 
 * This module:
 * - Fetches records updated since last sync
 * - Merges into SQLite using deterministic rules
 * - Respects deleted_at tombstones
 * - Never overwrites pending local changes
 * 
 * NO BACKGROUND TIMERS - manual trigger only via runPullOnce()
 */

import { getDatabase, getISOTimestamp, generateUUID } from './database';
import type { Tip, Notification, SyncStatus } from './types';
import { logger } from '../utils/logger';
import { supabase, getCurrentUserId, isSupabaseConfigured } from '../utils/supabase';

// ============ Types ============

/** Supabase client interface for dependency injection (testing) */
export interface PullSupabaseClient {
  from: (table: string) => {
    select: (columns?: string) => {
      gt: (column: string, value: string) => {
        order: (column: string, options?: { ascending?: boolean }) => {
          limit: (count: number) => Promise<{ data: any[] | null; error: any }>;
        };
        eq: (column: string, value: string) => {
          order: (column: string, options?: { ascending?: boolean }) => {
            limit: (count: number) => Promise<{ data: any[] | null; error: any }>;
          };
        };
      };
      eq: (column: string, value: string) => {
        order: (column: string, options?: { ascending?: boolean }) => {
          limit: (count: number) => Promise<{ data: any[] | null; error: any }>;
        };
        gt: (column: string, value: string) => {
          order: (column: string, options?: { ascending?: boolean }) => {
            limit: (count: number) => Promise<{ data: any[] | null; error: any }>;
          };
        };
      };
      order: (column: string, options?: { ascending?: boolean }) => {
        limit: (count: number) => Promise<{ data: any[] | null; error: any }>;
      };
    };
  };
}

/** Result of merging a single record */
export interface MergeResult {
  action: 'inserted' | 'updated' | 'skipped_pending' | 'skipped_local_newer' | 'deleted' | 'error';
  localId: string;
  serverId: string;
  error?: string;
}

/** Result of a pull sync operation */
export interface PullSyncResult {
  table: string;
  fetched: number;
  inserted: number;
  updated: number;
  deleted: number;
  skipped: number;
  errors: number;
  results: MergeResult[];
}

/** Result of running pull sync once */
export interface PullRunResult {
  tables: string[];
  results: PullSyncResult[];
  totalFetched: number;
  totalInserted: number;
  totalUpdated: number;
  totalDeleted: number;
  totalSkipped: number;
  totalErrors: number;
}

/** Server record shape (common fields) */
interface ServerRecord {
  id: string;
  updated_at: string;
  deleted_at: string | null;
  [key: string]: unknown;
}

// ============ Sync Checkpoint Storage ============

/**
 * Initialize the sync_meta table for storing sync checkpoints.
 * Called automatically on first use.
 */
export function initSyncMetaTable(): void {
  const db = getDatabase();
  db.execSync(`
    CREATE TABLE IF NOT EXISTS sync_meta (
      table_name TEXT PRIMARY KEY NOT NULL,
      last_pull_at TEXT,
      last_push_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);
}

/**
 * Get the last pull sync timestamp for a table.
 * Returns null if never synced.
 */
export function getLastPullAt(tableName: string): string | null {
  const db = getDatabase();
  initSyncMetaTable();
  
  const row = db.getFirstSync<{ last_pull_at: string | null }>(
    `SELECT last_pull_at FROM sync_meta WHERE table_name = ?`,
    [tableName]
  );
  
  return row?.last_pull_at || null;
}

/**
 * Set the last pull sync timestamp for a table.
 */
export function setLastPullAt(tableName: string, timestamp: string): void {
  const db = getDatabase();
  initSyncMetaTable();
  
  const now = getISOTimestamp();
  
  db.runSync(
    `INSERT INTO sync_meta (table_name, last_pull_at, created_at, updated_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(table_name) DO UPDATE SET last_pull_at = ?, updated_at = ?`,
    [tableName, timestamp, now, now, timestamp, now]
  );
}

/**
 * Get all sync checkpoints.
 */
export function getAllSyncCheckpoints(): Array<{ table_name: string; last_pull_at: string | null }> {
  const db = getDatabase();
  initSyncMetaTable();
  
  return db.getAllSync<{ table_name: string; last_pull_at: string | null }>(
    `SELECT table_name, last_pull_at FROM sync_meta`
  );
}

// ============ Local Record Access ============

/**
 * Get a local record by server ID (id field maps to local_id or server_id).
 * For tips/notifications, we use server's `id` as our `local_id`.
 */
function getLocalRecordByServerId(tableName: string, serverId: string): {
  local_id: string;
  sync_status: string;
  updated_at: string;
  deleted_at: string | null;
} | null {
  const db = getDatabase();
  
  // First check by server_id
  let row = db.getFirstSync<{
    local_id: string;
    sync_status: string;
    updated_at: string;
    deleted_at: string | null;
  }>(
    `SELECT local_id, sync_status, updated_at, deleted_at
     FROM ${tableName} WHERE server_id = ?`,
    [serverId]
  );
  
  if (row) return row;
  
  // Also check by local_id (for server-originating records where local_id = server id)
  row = db.getFirstSync<{
    local_id: string;
    sync_status: string;
    updated_at: string;
    deleted_at: string | null;
  }>(
    `SELECT local_id, sync_status, updated_at, deleted_at
     FROM ${tableName} WHERE local_id = ?`,
    [serverId]
  );
  
  return row || null;
}

// ============ Merge Logic ============

/**
 * Merge a server tip record into local SQLite.
 * 
 * MERGE RULES:
 * 1. If local record does not exist → insert with sync_status='synced'
 * 2. If local exists AND sync_status='pending' → skip (don't overwrite pending)
 * 3. If local exists AND local.updated_at >= server.updated_at → skip (local is same or newer)
 * 4. If server.updated_at > local.updated_at AND local is synced → overwrite local
 * 5. If server.deleted_at is set → set local.deleted_at (tombstone)
 */
export function mergeTip(serverRecord: ServerRecord, deviceId: string): MergeResult {
  const db = getDatabase();
  const serverId = serverRecord.id;
  const serverUpdatedAt = serverRecord.updated_at;
  const serverDeletedAt = serverRecord.deleted_at;
  
  try {
    const local = getLocalRecordByServerId('tips', serverId);
    
    if (!local) {
      // RULE 1: Insert new record
      const localId = serverId; // Use server ID as local ID for server-originating records
      const now = getISOTimestamp();
      
      db.runSync(
        `INSERT INTO tips (
          local_id, server_id, sync_status, updated_at, deleted_at,
          device_id, version, title, content, category, language, image_url, published_at
        ) VALUES (?, ?, 'synced', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          localId,
          serverId,
          serverUpdatedAt,
          serverDeletedAt,
          deviceId,
          serverRecord.version || 1,
          serverRecord.title,
          serverRecord.content,
          serverRecord.category,
          serverRecord.language || 'en',
          serverRecord.image_url || null,
          serverRecord.published_at || now,
        ]
      );
      
      logger.info('Pull sync: inserted tip', { serverId });
      return { action: 'inserted', localId, serverId };
    }
    
    // RULE 2: Don't overwrite pending local changes
    if (local.sync_status === 'pending') {
      logger.debug('Pull sync: skipped pending tip', { serverId });
      return { action: 'skipped_pending', localId: local.local_id, serverId };
    }
    
    // RULE 3: Don't overwrite if local is same or newer
    if (local.updated_at >= serverUpdatedAt) {
      logger.debug('Pull sync: skipped local newer tip', { serverId });
      return { action: 'skipped_local_newer', localId: local.local_id, serverId };
    }
    
    // RULE 5: Handle tombstone
    if (serverDeletedAt && !local.deleted_at) {
      db.runSync(
        `UPDATE tips SET deleted_at = ?, updated_at = ?, sync_status = 'synced'
         WHERE local_id = ?`,
        [serverDeletedAt, serverUpdatedAt, local.local_id]
      );
      logger.info('Pull sync: deleted tip (tombstone)', { serverId });
      return { action: 'deleted', localId: local.local_id, serverId };
    }
    
    // RULE 4: Overwrite local with server data
    db.runSync(
      `UPDATE tips SET
        server_id = ?,
        sync_status = 'synced',
        updated_at = ?,
        deleted_at = ?,
        version = ?,
        title = ?,
        content = ?,
        category = ?,
        language = ?,
        image_url = ?,
        published_at = ?
       WHERE local_id = ?`,
      [
        serverId,
        serverUpdatedAt,
        serverDeletedAt,
        serverRecord.version || 1,
        serverRecord.title,
        serverRecord.content,
        serverRecord.category,
        serverRecord.language || 'en',
        serverRecord.image_url || null,
        serverRecord.published_at,
        local.local_id,
      ]
    );
    
    logger.info('Pull sync: updated tip', { serverId });
    return { action: 'updated', localId: local.local_id, serverId };
    
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : 'Unknown error';
    logger.error('Pull sync: error merging tip', { serverId, error: errorMsg });
    return { action: 'error', localId: serverId, serverId, error: errorMsg };
  }
}

/**
 * Merge a server notification record into local SQLite.
 * Same merge rules as tips.
 */
export function mergeNotification(serverRecord: ServerRecord, deviceId: string): MergeResult {
  const db = getDatabase();
  const serverId = serverRecord.id;
  const serverUpdatedAt = serverRecord.updated_at;
  const serverDeletedAt = serverRecord.deleted_at;
  
  try {
    const local = getLocalRecordByServerId('notifications', serverId);
    
    if (!local) {
      // RULE 1: Insert new record
      const localId = serverId;
      const now = getISOTimestamp();
      
      db.runSync(
        `INSERT INTO notifications (
          local_id, server_id, sync_status, updated_at, deleted_at,
          device_id, version, user_local_id, type, title, body, read, data, received_at
        ) VALUES (?, ?, 'synced', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          localId,
          serverId,
          serverUpdatedAt,
          serverDeletedAt,
          deviceId,
          serverRecord.version || 1,
          serverRecord.user_id || serverRecord.user_local_id || 'unknown',
          serverRecord.type || 'system',
          serverRecord.title,
          serverRecord.body,
          serverRecord.read ? 1 : 0,
          serverRecord.data || null,
          serverRecord.received_at || serverRecord.created_at || now,
        ]
      );
      
      logger.info('Pull sync: inserted notification', { serverId });
      return { action: 'inserted', localId, serverId };
    }
    
    // RULE 2: Don't overwrite pending
    if (local.sync_status === 'pending') {
      logger.debug('Pull sync: skipped pending notification', { serverId });
      return { action: 'skipped_pending', localId: local.local_id, serverId };
    }
    
    // RULE 3: Don't overwrite if local is same or newer
    if (local.updated_at >= serverUpdatedAt) {
      logger.debug('Pull sync: skipped local newer notification', { serverId });
      return { action: 'skipped_local_newer', localId: local.local_id, serverId };
    }
    
    // RULE 5: Handle tombstone
    if (serverDeletedAt && !local.deleted_at) {
      db.runSync(
        `UPDATE notifications SET deleted_at = ?, updated_at = ?, sync_status = 'synced'
         WHERE local_id = ?`,
        [serverDeletedAt, serverUpdatedAt, local.local_id]
      );
      logger.info('Pull sync: deleted notification (tombstone)', { serverId });
      return { action: 'deleted', localId: local.local_id, serverId };
    }
    
    // RULE 4: Overwrite local with server data
    db.runSync(
      `UPDATE notifications SET
        server_id = ?,
        sync_status = 'synced',
        updated_at = ?,
        deleted_at = ?,
        version = ?,
        user_local_id = ?,
        type = ?,
        title = ?,
        body = ?,
        read = ?,
        data = ?,
        received_at = ?
       WHERE local_id = ?`,
      [
        serverId,
        serverUpdatedAt,
        serverDeletedAt,
        serverRecord.version || 1,
        serverRecord.user_id || serverRecord.user_local_id,
        serverRecord.type,
        serverRecord.title,
        serverRecord.body,
        serverRecord.read ? 1 : 0,
        serverRecord.data || null,
        serverRecord.received_at || serverRecord.created_at,
        local.local_id,
      ]
    );
    
    logger.info('Pull sync: updated notification', { serverId });
    return { action: 'updated', localId: local.local_id, serverId };
    
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : 'Unknown error';
    logger.error('Pull sync: error merging notification', { serverId, error: errorMsg });
    return { action: 'error', localId: serverId, serverId, error: errorMsg };
  }
}

// ============ Fetch from Server ============

/**
 * Fetch records from server updated since lastSync.
 * If lastSync is null, fetches all records.
 */
async function fetchServerRecords(
  tableName: string,
  lastSyncAt: string | null,
  limit: number,
  client: PullSupabaseClient
): Promise<{ data: ServerRecord[] | null; error: any }> {
  try {
    if (lastSyncAt) {
      // Fetch records updated since lastSync
      return await client
        .from(tableName)
        .select('*')
        .gt('updated_at', lastSyncAt)
        .order('updated_at', { ascending: true })
        .limit(limit);
    } else {
      // Fetch all records (initial sync)
      return await client
        .from(tableName)
        .select('*')
        .order('updated_at', { ascending: true })
        .limit(limit);
    }
  } catch (error) {
    return { data: null, error };
  }
}

/**
 * Fetch records from server for a specific user.
 * Used for user-scoped tables like notifications.
 * If userId is not provided, relies on RLS to filter.
 */
async function fetchServerRecordsForUser(
  tableName: string,
  lastSyncAt: string | null,
  limit: number,
  client: PullSupabaseClient,
  userId?: string
): Promise<{ data: ServerRecord[] | null; error: any }> {
  logger.debug('Fetching server records', { 
    table: tableName, 
    lastSyncAt, 
    userId: userId ? `${userId.substring(0, 8)}...` : 'none (RLS only)',
    limit 
  });
  
  try {
    // Note: RLS policies will enforce user filtering even if userId is not provided
    // The eq('user_id', userId) is an explicit filter for clarity
    if (lastSyncAt && userId) {
      logger.debug('Pull sync: filtering by user_id + lastSyncAt', { table: tableName });
      // Fetch user's records updated since lastSync
      return await client
        .from(tableName)
        .select('*')
        .eq('user_id', userId)
        .gt('updated_at', lastSyncAt)
        .order('updated_at', { ascending: true })
        .limit(limit);
    } else if (lastSyncAt) {
      logger.debug('Pull sync: filtering by lastSyncAt only (RLS enforced)', { table: tableName });
      // Fetch records updated since lastSync (RLS will filter by user)
      return await client
        .from(tableName)
        .select('*')
        .gt('updated_at', lastSyncAt)
        .order('updated_at', { ascending: true })
        .limit(limit);
    } else if (userId) {
      logger.debug('Pull sync: initial sync with user_id filter', { table: tableName });
      // Initial sync for specific user
      return await client
        .from(tableName)
        .select('*')
        .eq('user_id', userId)
        .order('updated_at', { ascending: true })
        .limit(limit);
    } else {
      logger.debug('Pull sync: initial sync without user_id (RLS enforced)', { table: tableName });
      // Initial sync (RLS will filter by user)
      return await client
        .from(tableName)
        .select('*')
        .order('updated_at', { ascending: true })
        .limit(limit);
    }
  } catch (error) {
    logger.error('Pull sync: fetch error', { table: tableName, error });
    return { data: null, error };
  }
}

// ============ Pull Sync Operations ============

/**
 * Pull sync tips from server.
 */
export async function pullTips(
  limit: number = 100,
  deviceId: string = 'default-device',
  client: PullSupabaseClient = supabase
): Promise<PullSyncResult> {
  const tableName = 'tips';
  logger.info('Pull sync starting', { table: tableName });
  
  const lastSyncAt = getLastPullAt(tableName);
  const { data, error } = await fetchServerRecords(tableName, lastSyncAt, limit, client);
  
  if (error) {
    logger.error('Pull sync: fetch error', { table: tableName, error: error.message });
    return {
      table: tableName,
      fetched: 0,
      inserted: 0,
      updated: 0,
      deleted: 0,
      skipped: 0,
      errors: 1,
      results: [{ action: 'error', localId: '', serverId: '', error: error.message }],
    };
  }
  
  if (!data || data.length === 0) {
    logger.info('Pull sync: no new records', { table: tableName });
    return {
      table: tableName,
      fetched: 0,
      inserted: 0,
      updated: 0,
      deleted: 0,
      skipped: 0,
      errors: 0,
      results: [],
    };
  }
  
  const results: MergeResult[] = [];
  let inserted = 0, updated = 0, deleted = 0, skipped = 0, errors = 0;
  let maxUpdatedAt = lastSyncAt || '';
  
  for (const record of data) {
    const result = mergeTip(record as ServerRecord, deviceId);
    results.push(result);
    
    switch (result.action) {
      case 'inserted': inserted++; break;
      case 'updated': updated++; break;
      case 'deleted': deleted++; break;
      case 'skipped_pending':
      case 'skipped_local_newer': skipped++; break;
      case 'error': errors++; break;
    }
    
    // Track max updated_at for checkpoint
    if (record.updated_at > maxUpdatedAt) {
      maxUpdatedAt = record.updated_at;
    }
  }
  
  // Update checkpoint
  if (maxUpdatedAt && maxUpdatedAt > (lastSyncAt || '')) {
    setLastPullAt(tableName, maxUpdatedAt);
  }
  
  logger.info('Pull sync completed', {
    table: tableName,
    fetched: data.length,
    inserted,
    updated,
    deleted,
    skipped,
    errors,
  });
  
  return {
    table: tableName,
    fetched: data.length,
    inserted,
    updated,
    deleted,
    skipped,
    errors,
    results,
  };
}

/**
 * Pull sync notifications from server.
 * Filters by user_id to only pull the current user's notifications (RLS enforced).
 * 
 * @param limit - Maximum records to fetch
 * @param deviceId - Device ID for new records
 * @param client - Supabase client (injectable for testing)
 * @param userId - Optional user ID override (for testing)
 */
export async function pullNotifications(
  limit: number = 100,
  deviceId: string = 'default-device',
  client: PullSupabaseClient = supabase,
  userId?: string
): Promise<PullSyncResult> {
  const tableName = 'notifications';
  logger.info('Pull sync starting', { table: tableName });
  
  // Get current user ID for filtering (RLS will also enforce this)
  const authUserId = userId || await getCurrentUserId();
  if (!authUserId && !userId) {
    logger.warn('pullNotifications: No authenticated user, notifications will be filtered by RLS');
  }
  
  const lastSyncAt = getLastPullAt(tableName);
  const { data, error } = await fetchServerRecordsForUser(
    tableName, 
    lastSyncAt, 
    limit, 
    client,
    authUserId || undefined
  );
  
  if (error) {
    logger.error('Pull sync: fetch error', { table: tableName, error: error.message });
    return {
      table: tableName,
      fetched: 0,
      inserted: 0,
      updated: 0,
      deleted: 0,
      skipped: 0,
      errors: 1,
      results: [{ action: 'error', localId: '', serverId: '', error: error.message }],
    };
  }
  
  if (!data || data.length === 0) {
    logger.info('Pull sync: no new records', { table: tableName });
    return {
      table: tableName,
      fetched: 0,
      inserted: 0,
      updated: 0,
      deleted: 0,
      skipped: 0,
      errors: 0,
      results: [],
    };
  }
  
  const results: MergeResult[] = [];
  let inserted = 0, updated = 0, deleted = 0, skipped = 0, errors = 0;
  let maxUpdatedAt = lastSyncAt || '';
  
  for (const record of data) {
    const result = mergeNotification(record as ServerRecord, deviceId);
    results.push(result);
    
    switch (result.action) {
      case 'inserted': inserted++; break;
      case 'updated': updated++; break;
      case 'deleted': deleted++; break;
      case 'skipped_pending':
      case 'skipped_local_newer': skipped++; break;
      case 'error': errors++; break;
    }
    
    if (record.updated_at > maxUpdatedAt) {
      maxUpdatedAt = record.updated_at;
    }
  }
  
  if (maxUpdatedAt && maxUpdatedAt > (lastSyncAt || '')) {
    setLastPullAt(tableName, maxUpdatedAt);
  }
  
  logger.info('Pull sync completed', {
    table: tableName,
    fetched: data.length,
    inserted,
    updated,
    deleted,
    skipped,
    errors,
  });
  
  return {
    table: tableName,
    fetched: data.length,
    inserted,
    updated,
    deleted,
    skipped,
    errors,
    results,
  };
}

// ============ Main Pull Runner ============

/**
 * Run pull sync once for all supported tables (tips, notifications).
 * Call this manually to trigger a pull sync cycle.
 * 
 * DOES NOT block UI. NO background timers.
 * 
 * @param limit - Maximum records to fetch per table (default 100)
 * @param deviceId - Device ID for new records
 * @param client - Supabase client (injectable for testing)
 * @returns PullRunResult with summary statistics
 */
export async function runPullOnce(
  limit: number = 100,
  deviceId: string = 'default-device',
  client: PullSupabaseClient = supabase
): Promise<PullRunResult> {
  logger.info('Starting pull sync run');
  
  const tables = ['tips', 'notifications'];
  const results: PullSyncResult[] = [];
  
  // Pull tips
  const tipsResult = await pullTips(limit, deviceId, client);
  results.push(tipsResult);
  
  // Pull notifications
  const notificationsResult = await pullNotifications(limit, deviceId, client);
  results.push(notificationsResult);
  
  // Aggregate stats
  const totalFetched = results.reduce((sum, r) => sum + r.fetched, 0);
  const totalInserted = results.reduce((sum, r) => sum + r.inserted, 0);
  const totalUpdated = results.reduce((sum, r) => sum + r.updated, 0);
  const totalDeleted = results.reduce((sum, r) => sum + r.deleted, 0);
  const totalSkipped = results.reduce((sum, r) => sum + r.skipped, 0);
  const totalErrors = results.reduce((sum, r) => sum + r.errors, 0);
  
  logger.info('Pull sync run completed', {
    tables,
    totalFetched,
    totalInserted,
    totalUpdated,
    totalDeleted,
    totalSkipped,
    totalErrors,
  });
  
  return {
    tables,
    results,
    totalFetched,
    totalInserted,
    totalUpdated,
    totalDeleted,
    totalSkipped,
    totalErrors,
  };
}

/**
 * Clear sync checkpoint for a table (for testing or reset).
 */
export function clearSyncCheckpoint(tableName: string): void {
  const db = getDatabase();
  initSyncMetaTable();
  db.runSync(`DELETE FROM sync_meta WHERE table_name = ?`, [tableName]);
}

/**
 * Clear all sync checkpoints (for testing or full reset).
 */
export function clearAllSyncCheckpoints(): void {
  const db = getDatabase();
  initSyncMetaTable();
  db.runSync(`DELETE FROM sync_meta`);
}

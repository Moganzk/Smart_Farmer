/**
 * Smart Farmer - Sync Queue Module
 * 
 * Manages the queue of records waiting to be synced to Supabase.
 * Offline-first: all local operations succeed immediately, sync happens in background.
 */

import { getDatabase, getISOTimestamp } from './database';
import type { SyncOperation, SyncQueueEntry, SyncStatus } from './types';

/**
 * Add a record to the sync queue.
 * Called after any local insert/update/delete.
 * 
 * @param tableName - Name of the table (users, scans, etc.)
 * @param localId - The local_id of the record
 * @param operation - 'insert' | 'update' | 'delete'
 * @param payload - Optional JSON snapshot of the record
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

  // Use INSERT OR REPLACE to handle re-queuing the same record
  // This ensures we don't have duplicate queue entries
  database.runSync(
    `INSERT INTO sync_queue (table_name, local_id, operation, payload, retry_count, created_at)
     VALUES (?, ?, ?, ?, 0, ?)
     ON CONFLICT(table_name, local_id, operation) 
     DO UPDATE SET payload = excluded.payload, retry_count = 0, last_error = NULL, created_at = excluded.created_at`,
    [tableName, localId, operation, payloadJson, now]
  );
}

/**
 * Mark a record as successfully synced.
 * Updates the record's sync_status and optionally sets the server_id.
 * Removes the entry from the sync queue.
 * 
 * @param tableName - Name of the table
 * @param localId - The local_id of the record
 * @param serverId - Optional server-assigned ID from Supabase
 */
export function markSynced(
  tableName: string,
  localId: string,
  serverId?: string
): void {
  const database = getDatabase();
  const now = getISOTimestamp();

  // Update the record's sync status
  if (serverId) {
    database.runSync(
      `UPDATE ${tableName} SET sync_status = 'synced', server_id = ?, updated_at = ? WHERE local_id = ?`,
      [serverId, now, localId]
    );
  } else {
    database.runSync(
      `UPDATE ${tableName} SET sync_status = 'synced', updated_at = ? WHERE local_id = ?`,
      [now, localId]
    );
  }

  // Remove from sync queue
  database.runSync(
    `DELETE FROM sync_queue WHERE table_name = ? AND local_id = ?`,
    [tableName, localId]
  );
}

/**
 * Mark a sync attempt as failed.
 * Increments retry count and stores error message.
 * Updates record's sync_status to 'failed'.
 * 
 * @param tableName - Name of the table
 * @param localId - The local_id of the record
 * @param error - Optional error message
 */
export function markFailed(
  tableName: string,
  localId: string,
  error?: string
): void {
  const database = getDatabase();
  const now = getISOTimestamp();
  const errorMessage = error || 'Unknown error';

  // Update the record's sync status
  database.runSync(
    `UPDATE ${tableName} SET sync_status = 'failed' WHERE local_id = ?`,
    [localId]
  );

  // Update sync queue with retry info
  database.runSync(
    `UPDATE sync_queue 
     SET retry_count = retry_count + 1, last_error = ?, last_attempted_at = ?
     WHERE table_name = ? AND local_id = ?`,
    [errorMessage, now, tableName, localId]
  );
}

/**
 * Get pending items from the sync queue.
 * Returns items ordered by creation time, oldest first.
 * Excludes items that have exceeded max retries or were recently attempted.
 * 
 * @param limit - Maximum number of items to return (default 50)
 * @param maxRetries - Skip items with more retries than this (default 5)
 * @returns Array of sync queue entries
 */
export function getPendingQueue(
  limit: number = 50,
  maxRetries: number = 5
): SyncQueueEntry[] {
  const database = getDatabase();
  
  const results = database.getAllSync<SyncQueueEntry>(
    `SELECT id, table_name, local_id, operation, payload, retry_count, last_error, created_at, last_attempted_at
     FROM sync_queue
     WHERE retry_count < ?
     ORDER BY created_at ASC
     LIMIT ?`,
    [maxRetries, limit]
  );

  return results || [];
}

/**
 * Soft delete a record by setting deleted_at timestamp.
 * Also enqueues a delete operation for sync.
 * 
 * @param tableName - Name of the table
 * @param localId - The local_id of the record
 */
export function softDelete(tableName: string, localId: string): void {
  const database = getDatabase();
  const now = getISOTimestamp();

  // Set tombstone
  database.runSync(
    `UPDATE ${tableName} 
     SET deleted_at = ?, sync_status = 'pending', version = version + 1, updated_at = ?
     WHERE local_id = ? AND deleted_at IS NULL`,
    [now, now, localId]
  );

  // Queue for sync
  enqueueSync(tableName, localId, 'delete');
}

/**
 * Get count of pending sync items
 */
export function getPendingCount(): number {
  const database = getDatabase();
  const result = database.getFirstSync<{ count: number }>(
    `SELECT COUNT(*) as count FROM sync_queue`
  );
  return result?.count || 0;
}

/**
 * Get count of failed sync items
 */
export function getFailedCount(): number {
  const database = getDatabase();
  const result = database.getFirstSync<{ count: number }>(
    `SELECT COUNT(*) as count FROM sync_queue WHERE retry_count >= 5`
  );
  return result?.count || 0;
}

/**
 * Clear all completed syncs from queue (cleanup utility)
 * This removes entries that somehow weren't cleaned up
 */
export function cleanupSyncedItems(): number {
  const database = getDatabase();
  
  // For each syncable table, remove queue entries where record is already synced
  const tables = ['users', 'scans', 'diagnoses', 'tips', 'notifications'];
  let totalCleaned = 0;

  for (const table of tables) {
    const result = database.runSync(
      `DELETE FROM sync_queue 
       WHERE table_name = ? 
       AND local_id IN (SELECT local_id FROM ${table} WHERE sync_status = 'synced')`,
      [table]
    );
    totalCleaned += result.changes;
  }

  return totalCleaned;
}

/**
 * Reset failed items for retry (manual intervention)
 * Resets retry count so items will be picked up again
 */
export function resetFailedItems(): number {
  const database = getDatabase();
  const result = database.runSync(
    `UPDATE sync_queue SET retry_count = 0, last_error = NULL WHERE retry_count >= 5`
  );
  
  // Also reset the sync_status on the records
  const tables = ['users', 'scans', 'diagnoses', 'tips', 'notifications'];
  for (const table of tables) {
    database.runSync(
      `UPDATE ${table} SET sync_status = 'pending' WHERE sync_status = 'failed'`
    );
  }

  return result.changes;
}

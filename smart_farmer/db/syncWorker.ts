/**
 * Smart Farmer - Sync Worker
 * 
 * Background sync worker that pushes local data to Supabase.
 * PUSH ONLY - does not pull/downsync from server.
 * 
 * This worker:
 * - Reads pending entries from sync_queue
 * - Pushes corresponding records to Supabase
 * - Marks records as synced on success
 * - Increments retry_count on failure
 * 
 * NEVER blocks UI flows. Failures are recoverable.
 */

import { getDatabase, getISOTimestamp } from './database';
import { getPendingQueue, markSynced, markFailed } from './syncQueue';
import type { SyncQueueEntry, SyncOperation, Scan, Diagnosis } from './types';
import { logger } from '../utils/logger';
import { supabase } from '../utils/supabase';

// ============ Types ============

/** Result of a single sync operation */
export interface SyncResult {
  success: boolean;
  localId: string;
  serverId?: string;
  error?: string;
}

/** Result of running sync once */
export interface SyncRunResult {
  processed: number;
  succeeded: number;
  failed: number;
  results: SyncResult[];
}

/** Supabase client interface for dependency injection (testing) */
export interface SupabaseClient {
  from: (table: string) => {
    insert: (data: Record<string, unknown>) => Promise<{ data: any; error: any }>;
    update: (data: Record<string, unknown>) => {
      eq: (column: string, value: string) => Promise<{ data: any; error: any }>;
    };
    delete: () => {
      eq: (column: string, value: string) => Promise<{ data: any; error: any }>;
    };
  };
}

// ============ Schema Mappers ============

/**
 * Map local scan record to Supabase schema.
 * Handles field name differences and required transformations.
 */
export function mapScanToServer(scan: Scan): Record<string, unknown> {
  return {
    // Use local_id as the primary key on server
    id: scan.local_id,
    device_id: scan.device_id,
    user_id: scan.user_local_id, // Server uses user_id, not user_local_id
    image_path: scan.image_path,
    image_server_url: scan.image_server_url,
    crop_type: scan.crop_type,
    scanned_at: scan.scanned_at,
    latitude: scan.latitude,
    longitude: scan.longitude,
    deleted_at: scan.deleted_at,
    version: scan.version,
    created_at: scan.scanned_at, // Use scanned_at as created_at
    updated_at: scan.updated_at,
  };
}

/**
 * Map local diagnosis record to Supabase schema.
 */
export function mapDiagnosisToServer(diagnosis: Diagnosis): Record<string, unknown> {
  return {
    // Use local_id as the primary key on server
    id: diagnosis.local_id,
    device_id: diagnosis.device_id,
    scan_id: diagnosis.scan_local_id, // Server uses scan_id, not scan_local_id
    disease_name: diagnosis.disease_name,
    confidence: diagnosis.confidence,
    severity: diagnosis.severity,
    recommendations: diagnosis.recommendations, // Already JSON string
    diagnosed_at: diagnosis.diagnosed_at,
    deleted_at: diagnosis.deleted_at,
    version: diagnosis.version,
    created_at: diagnosis.diagnosed_at, // Use diagnosed_at as created_at
    updated_at: diagnosis.updated_at,
  };
}

// ============ Record Fetchers ============

/**
 * Get a scan record by local_id from SQLite.
 */
export function getLocalScan(localId: string): Scan | null {
  const db = getDatabase();
  const row = db.getFirstSync<Scan>(
    `SELECT local_id, server_id, sync_status, updated_at, deleted_at,
            device_id, version, user_local_id, image_path, image_server_url,
            crop_type, scanned_at, latitude, longitude
     FROM scans WHERE local_id = ?`,
    [localId]
  );
  return row || null;
}

/**
 * Get a diagnosis record by local_id from SQLite.
 */
export function getLocalDiagnosis(localId: string): Diagnosis | null {
  const db = getDatabase();
  const row = db.getFirstSync<Diagnosis>(
    `SELECT local_id, server_id, sync_status, updated_at, deleted_at,
            device_id, version, scan_local_id, disease_name, confidence,
            severity, recommendations, diagnosed_at
     FROM diagnoses WHERE local_id = ?`,
    [localId]
  );
  return row || null;
}

// ============ Sync Operations ============

/**
 * Push an insert operation to Supabase.
 * 
 * @param tableName - The table to insert into
 * @param localId - The local_id of the record
 * @param client - Supabase client (injectable for testing)
 * @returns SyncResult with success status
 */
export async function pushInsert(
  tableName: string,
  localId: string,
  client: SupabaseClient = supabase
): Promise<SyncResult> {
  try {
    // Fetch local record
    let record: Scan | Diagnosis | null = null;
    let serverData: Record<string, unknown>;

    if (tableName === 'scans') {
      record = getLocalScan(localId);
      if (!record) {
        return { success: false, localId, error: 'Local scan record not found' };
      }
      serverData = mapScanToServer(record);
    } else if (tableName === 'diagnoses') {
      record = getLocalDiagnosis(localId);
      if (!record) {
        return { success: false, localId, error: 'Local diagnosis record not found' };
      }
      serverData = mapDiagnosisToServer(record);
    } else {
      return { success: false, localId, error: `Unsupported table: ${tableName}` };
    }

    // Push to Supabase
    const { data, error } = await client.from(tableName).insert(serverData);

    if (error) {
      logger.error('Supabase insert failed', { tableName, localId, error: error.message });
      return { success: false, localId, error: error.message };
    }

    // Success - return the server ID (we use local_id as server ID)
    const serverId = localId;
    logger.info('Sync insert succeeded', { tableName, localId, serverId });
    return { success: true, localId, serverId };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logger.error('Sync insert exception', { tableName, localId, error: errorMessage });
    return { success: false, localId, error: errorMessage };
  }
}

/**
 * Push a delete operation to Supabase.
 * For soft deletes, we update the deleted_at field on the server.
 * 
 * @param tableName - The table to update
 * @param localId - The local_id of the record
 * @param client - Supabase client (injectable for testing)
 * @returns SyncResult with success status
 */
export async function pushDelete(
  tableName: string,
  localId: string,
  client: SupabaseClient = supabase
): Promise<SyncResult> {
  try {
    // Fetch local record to get the deleted_at timestamp
    let record: Scan | Diagnosis | null = null;

    if (tableName === 'scans') {
      record = getLocalScan(localId);
    } else if (tableName === 'diagnoses') {
      record = getLocalDiagnosis(localId);
    } else {
      return { success: false, localId, error: `Unsupported table: ${tableName}` };
    }

    if (!record) {
      return { success: false, localId, error: 'Local record not found' };
    }

    // Update deleted_at on server (soft delete)
    const { error } = await client
      .from(tableName)
      .update({ 
        deleted_at: record.deleted_at,
        updated_at: record.updated_at,
        version: record.version,
      })
      .eq('id', localId);

    if (error) {
      logger.error('Supabase delete failed', { tableName, localId, error: error.message });
      return { success: false, localId, error: error.message };
    }

    logger.info('Sync delete succeeded', { tableName, localId });
    return { success: true, localId, serverId: localId };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logger.error('Sync delete exception', { tableName, localId, error: errorMessage });
    return { success: false, localId, error: errorMessage };
  }
}

// ============ Entry Processor ============

/**
 * Process a single sync queue entry.
 * Routes to the appropriate sync operation based on operation type.
 * 
 * @param entry - The sync queue entry to process
 * @param client - Supabase client (injectable for testing)
 * @returns SyncResult with success status
 */
export async function processSyncEntry(
  entry: SyncQueueEntry,
  client: SupabaseClient = supabase
): Promise<SyncResult> {
  const { table_name, local_id, operation } = entry;

  logger.info('Processing sync entry', { table_name, local_id, operation });

  let result: SyncResult;

  switch (operation) {
    case 'insert':
      result = await pushInsert(table_name, local_id, client);
      break;
    case 'delete':
      result = await pushDelete(table_name, local_id, client);
      break;
    case 'update':
      // Update is similar to insert - upsert the full record
      result = await pushInsert(table_name, local_id, client);
      break;
    default:
      result = { success: false, localId: local_id, error: `Unknown operation: ${operation}` };
  }

  // Update local state based on result
  if (result.success) {
    markSynced(table_name, local_id, result.serverId);
  } else {
    markFailed(table_name, local_id, result.error);
  }

  return result;
}

// ============ Main Sync Runner ============

/**
 * Run sync once - processes all pending queue entries.
 * Call this manually to trigger a sync cycle.
 * 
 * DOES NOT block UI. DOES NOT retry failed items automatically.
 * 
 * @param limit - Maximum entries to process (default 50)
 * @param maxRetries - Skip entries with more retries (default 5)
 * @param client - Supabase client (injectable for testing)
 * @returns SyncRunResult with summary statistics
 */
export async function runSyncOnce(
  limit: number = 50,
  maxRetries: number = 5,
  client: SupabaseClient = supabase
): Promise<SyncRunResult> {
  logger.info('Starting sync run', { limit, maxRetries });

  const pending = getPendingQueue(limit, maxRetries);
  
  if (pending.length === 0) {
    logger.info('No pending items to sync');
    return { processed: 0, succeeded: 0, failed: 0, results: [] };
  }

  logger.info('Found pending sync items', { count: pending.length });

  const results: SyncResult[] = [];
  let succeeded = 0;
  let failed = 0;

  // Process entries sequentially to maintain order
  for (const entry of pending) {
    try {
      const result = await processSyncEntry(entry, client);
      results.push(result);

      if (result.success) {
        succeeded++;
      } else {
        failed++;
      }
    } catch (error) {
      // Catch any unexpected errors to prevent sync from crashing
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      logger.error('Unexpected error processing sync entry', { 
        entry: entry.local_id, 
        error: errorMessage 
      });
      
      results.push({ 
        success: false, 
        localId: entry.local_id, 
        error: errorMessage 
      });
      failed++;

      // Mark as failed in queue
      markFailed(entry.table_name, entry.local_id, errorMessage);
    }
  }

  logger.info('Sync run completed', { 
    processed: pending.length, 
    succeeded, 
    failed 
  });

  return {
    processed: pending.length,
    succeeded,
    failed,
    results,
  };
}

/**
 * Check if there are pending items to sync.
 * Useful for UI indicators (future feature).
 */
export function hasPendingSync(): boolean {
  const pending = getPendingQueue(1);
  return pending.length > 0;
}

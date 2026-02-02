/**
 * Smart Farmer - Database Module Index
 * 
 * Re-exports all database functionality for clean imports.
 */

// Core database
export {
  initDb,
  getDatabase,
  closeDb,
  generateUUID,
  getISOTimestamp,
  createSyncFields,
  getSyncableTables,
  tableExists,
} from './database';

// Types
export type {
  SyncStatus,
  SyncOperation,
  SyncableRecord,
  User,
  Scan,
  Diagnosis,
  Tip,
  Notification,
  SyncQueueEntry,
} from './types';

// Sync queue operations
export {
  enqueueSync,
  markSynced,
  markFailed,
  getPendingQueue,
  softDelete,
  getPendingCount,
  getFailedCount,
  cleanupSyncedItems,
  resetFailedItems,
} from './syncQueue';

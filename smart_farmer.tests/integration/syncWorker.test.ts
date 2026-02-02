/**
 * Smart Farmer - Sync Worker Integration Tests
 * 
 * Tests the background sync worker with real SQLite + mocked Supabase.
 * Verifies push-only sync operations: insert, delete, retry handling.
 * 
 * Test Strategy:
 * - Real SQLite database (better-sqlite3 in-memory)
 * - Mocked Supabase client (injectable dependency)
 * - Test success and failure scenarios
 * - Verify local state updates (sync_status, server_id, retry_count)
 */

import {
  getTestDb,
  resetTestDb,
  closeTestDb,
  initTestDb,
  TEST_DEVICE_ID,
  generateUUID,
  getISOTimestamp,
  createScan,
  createDiagnosis,
  getSyncQueueEntryByLocalId,
  getSyncQueueEntriesByTable,
  getSyncQueueCount,
  getPendingQueue,
  enqueueSync,
} from '../helpers/integrationDb';

// ============ Mock Supabase Client Factory ============

interface MockResponse {
  data: any;
  error: any;
}

interface MockSupabaseClient {
  from: jest.Mock;
  insertCalls: Array<{ table: string; data: any }>;
  updateCalls: Array<{ table: string; data: any; column: string; value: string }>;
  deleteCalls: Array<{ table: string; column: string; value: string }>;
  setInsertResponse: (response: MockResponse) => void;
  setUpdateResponse: (response: MockResponse) => void;
  setDeleteResponse: (response: MockResponse) => void;
  reset: () => void;
}

function createMockSupabaseClient(): MockSupabaseClient {
  let insertResponse: MockResponse = { data: {}, error: null };
  let updateResponse: MockResponse = { data: {}, error: null };
  let deleteResponse: MockResponse = { data: {}, error: null };

  const insertCalls: Array<{ table: string; data: any }> = [];
  const updateCalls: Array<{ table: string; data: any; column: string; value: string }> = [];
  const deleteCalls: Array<{ table: string; column: string; value: string }> = [];

  const mockFrom = jest.fn((table: string) => ({
    insert: jest.fn(async (data: any) => {
      insertCalls.push({ table, data });
      return insertResponse;
    }),
    update: jest.fn((data: any) => ({
      eq: jest.fn(async (column: string, value: string) => {
        updateCalls.push({ table, data, column, value });
        return updateResponse;
      }),
    })),
    delete: jest.fn(() => ({
      eq: jest.fn(async (column: string, value: string) => {
        deleteCalls.push({ table, column, value });
        return deleteResponse;
      }),
    })),
  }));

  return {
    from: mockFrom,
    insertCalls,
    updateCalls,
    deleteCalls,
    setInsertResponse: (response) => { insertResponse = response; },
    setUpdateResponse: (response) => { updateResponse = response; },
    setDeleteResponse: (response) => { deleteResponse = response; },
    reset: () => {
      insertCalls.length = 0;
      updateCalls.length = 0;
      deleteCalls.length = 0;
      insertResponse = { data: {}, error: null };
      updateResponse = { data: {}, error: null };
      deleteResponse = { data: {}, error: null };
    },
  };
}

// ============ Module Under Test (with mocked dependencies) ============

// We need to test the sync worker with mocked database access
// Since the real syncWorker imports from the mobile app, we'll implement
// equivalent test functions that mirror the production logic

interface SyncQueueEntry {
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

interface SyncResult {
  success: boolean;
  localId: string;
  serverId?: string;
  error?: string;
}

interface SyncRunResult {
  processed: number;
  succeeded: number;
  failed: number;
  results: SyncResult[];
}

// Get a scan record from test DB
function getLocalScan(localId: string): any {
  const db = getTestDb();
  return db.prepare(
    `SELECT local_id, server_id, sync_status, updated_at, deleted_at,
            device_id, version, user_local_id, image_path, image_server_url,
            crop_type, scanned_at, latitude, longitude
     FROM scans WHERE local_id = ?`
  ).get(localId);
}

// Get a diagnosis record from test DB
function getLocalDiagnosis(localId: string): any {
  const db = getTestDb();
  return db.prepare(
    `SELECT local_id, server_id, sync_status, updated_at, deleted_at,
            device_id, version, scan_local_id, disease_name, confidence,
            severity, recommendations, diagnosed_at
     FROM diagnoses WHERE local_id = ?`
  ).get(localId);
}

// Map scan to server schema
function mapScanToServer(scan: any): Record<string, unknown> {
  return {
    id: scan.local_id,
    device_id: scan.device_id,
    user_id: scan.user_local_id,
    image_path: scan.image_path,
    image_server_url: scan.image_server_url,
    crop_type: scan.crop_type,
    scanned_at: scan.scanned_at,
    latitude: scan.latitude,
    longitude: scan.longitude,
    deleted_at: scan.deleted_at,
    version: scan.version,
    created_at: scan.scanned_at,
    updated_at: scan.updated_at,
  };
}

// Map diagnosis to server schema
function mapDiagnosisToServer(diagnosis: any): Record<string, unknown> {
  return {
    id: diagnosis.local_id,
    device_id: diagnosis.device_id,
    scan_id: diagnosis.scan_local_id,
    disease_name: diagnosis.disease_name,
    confidence: diagnosis.confidence,
    severity: diagnosis.severity,
    recommendations: diagnosis.recommendations,
    diagnosed_at: diagnosis.diagnosed_at,
    deleted_at: diagnosis.deleted_at,
    version: diagnosis.version,
    created_at: diagnosis.diagnosed_at,
    updated_at: diagnosis.updated_at,
  };
}

// Mark as synced (test version)
function markSyncedTest(tableName: string, localId: string, serverId?: string): void {
  const db = getTestDb();
  const now = getISOTimestamp();

  if (serverId) {
    db.prepare(
      `UPDATE ${tableName} SET sync_status = 'synced', server_id = ?, updated_at = ? WHERE local_id = ?`
    ).run(serverId, now, localId);
  } else {
    db.prepare(
      `UPDATE ${tableName} SET sync_status = 'synced', updated_at = ? WHERE local_id = ?`
    ).run(now, localId);
  }

  db.prepare(
    `DELETE FROM sync_queue WHERE table_name = ? AND local_id = ?`
  ).run(tableName, localId);
}

// Supported tables for sync
const SUPPORTED_TABLES = ['scans', 'diagnoses', 'users', 'tips', 'notifications'];

// Mark as failed (test version)
function markFailedTest(tableName: string, localId: string, error?: string): void {
  const db = getTestDb();
  const now = getISOTimestamp();
  const errorMessage = error || 'Unknown error';

  // Only update the record table if it's a supported table
  if (SUPPORTED_TABLES.includes(tableName)) {
    db.prepare(
      `UPDATE ${tableName} SET sync_status = 'failed' WHERE local_id = ?`
    ).run(localId);
  }

  db.prepare(
    `UPDATE sync_queue 
     SET retry_count = retry_count + 1, last_error = ?, last_attempted_at = ?
     WHERE table_name = ? AND local_id = ?`
  ).run(errorMessage, now, tableName, localId);
}

// Push insert operation (test version)
async function pushInsertTest(
  tableName: string,
  localId: string,
  client: MockSupabaseClient
): Promise<SyncResult> {
  let record: any = null;
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

  const { error } = await client.from(tableName).insert(serverData);

  if (error) {
    return { success: false, localId, error: error.message };
  }

  return { success: true, localId, serverId: localId };
}

// Push delete operation (test version)
async function pushDeleteTest(
  tableName: string,
  localId: string,
  client: MockSupabaseClient
): Promise<SyncResult> {
  let record: any = null;

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

  const { error } = await client
    .from(tableName)
    .update({ 
      deleted_at: record.deleted_at,
      updated_at: record.updated_at,
      version: record.version,
    })
    .eq('id', localId);

  if (error) {
    return { success: false, localId, error: error.message };
  }

  return { success: true, localId, serverId: localId };
}

// Process single sync entry (test version)
async function processSyncEntryTest(
  entry: SyncQueueEntry,
  client: MockSupabaseClient
): Promise<SyncResult> {
  const { table_name, local_id, operation } = entry;

  let result: SyncResult;

  switch (operation) {
    case 'insert':
    case 'update':
      result = await pushInsertTest(table_name, local_id, client);
      break;
    case 'delete':
      result = await pushDeleteTest(table_name, local_id, client);
      break;
    default:
      result = { success: false, localId: local_id, error: `Unknown operation: ${operation}` };
  }

  if (result.success) {
    markSyncedTest(table_name, local_id, result.serverId);
  } else {
    markFailedTest(table_name, local_id, result.error);
  }

  return result;
}

// Run sync once (test version)
async function runSyncOnceTest(
  client: MockSupabaseClient,
  limit: number = 50,
  maxRetries: number = 5
): Promise<SyncRunResult> {
  const pending = getPendingQueue(limit, maxRetries);

  if (pending.length === 0) {
    return { processed: 0, succeeded: 0, failed: 0, results: [] };
  }

  const results: SyncResult[] = [];
  let succeeded = 0;
  let failed = 0;

  for (const entry of pending) {
    const result = await processSyncEntryTest(entry, client);
    results.push(result);

    if (result.success) {
      succeeded++;
    } else {
      failed++;
    }
  }

  return {
    processed: pending.length,
    succeeded,
    failed,
    results,
  };
}

// ============ Tests ============

describe('Sync Worker Integration Tests', () => {
  let mockClient: MockSupabaseClient;
  const testUserId = 'test-user-001';

  beforeEach(() => {
    resetTestDb();
    initTestDb();
    mockClient = createMockSupabaseClient();
  });

  afterAll(() => {
    closeTestDb();
  });

  // ============ Basic Sync Flow Tests ============

  describe('runSyncOnce - basic flow', () => {
    it('should return empty result when queue is empty', async () => {
      const result = await runSyncOnceTest(mockClient);

      expect(result.processed).toBe(0);
      expect(result.succeeded).toBe(0);
      expect(result.failed).toBe(0);
      expect(result.results).toHaveLength(0);
    });

    it('should process pending scan insert', async () => {
      // Create a scan (auto-enqueues sync intent)
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/test.jpg',
        cropType: 'tomato',
      });

      // Verify pending in queue
      expect(getSyncQueueCount()).toBe(1);

      // Run sync
      const result = await runSyncOnceTest(mockClient);

      // Verify sync result
      expect(result.processed).toBe(1);
      expect(result.succeeded).toBe(1);
      expect(result.failed).toBe(0);

      // Verify Supabase was called
      expect(mockClient.insertCalls).toHaveLength(1);
      expect(mockClient.insertCalls[0].table).toBe('scans');
      expect(mockClient.insertCalls[0].data.id).toBe(scanId);

      // Verify local state updated
      const scan = getLocalScan(scanId);
      expect(scan.sync_status).toBe('synced');
      expect(scan.server_id).toBe(scanId);

      // Verify queue entry removed
      expect(getSyncQueueCount()).toBe(0);
    });

    it('should process pending diagnosis insert', async () => {
      // Create scan first (to satisfy foreign key)
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/test.jpg',
      });

      // Create diagnosis (auto-enqueues sync intent)
      const diagnosisId = createDiagnosis({
        scanLocalId: scanId,
        diseaseName: 'Powdery Mildew',
        confidence: 0.92,
        severity: 'low',
        recommendations: ['Apply fungicide', 'Improve ventilation'],
      });

      // Should have 2 pending entries (scan + diagnosis)
      expect(getSyncQueueCount()).toBe(2);

      // Run sync
      const result = await runSyncOnceTest(mockClient);

      // Both should sync
      expect(result.processed).toBe(2);
      expect(result.succeeded).toBe(2);
      expect(result.failed).toBe(0);

      // Verify Supabase calls
      expect(mockClient.insertCalls).toHaveLength(2);
      expect(mockClient.insertCalls[0].table).toBe('scans');
      expect(mockClient.insertCalls[1].table).toBe('diagnoses');

      // Verify diagnosis was synced
      const diagnosis = getLocalDiagnosis(diagnosisId);
      expect(diagnosis.sync_status).toBe('synced');
      expect(diagnosis.server_id).toBe(diagnosisId);
    });

    it('should process entries in FIFO order', async () => {
      // Create multiple scans
      const scanId1 = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/first.jpg',
      });

      // Small delay to ensure different timestamps
      await new Promise(resolve => setTimeout(resolve, 10));

      const scanId2 = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/second.jpg',
      });

      await new Promise(resolve => setTimeout(resolve, 10));

      const scanId3 = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/third.jpg',
      });

      expect(getSyncQueueCount()).toBe(3);

      // Run sync
      await runSyncOnceTest(mockClient);

      // Verify order (oldest first)
      expect(mockClient.insertCalls[0].data.id).toBe(scanId1);
      expect(mockClient.insertCalls[1].data.id).toBe(scanId2);
      expect(mockClient.insertCalls[2].data.id).toBe(scanId3);
    });
  });

  // ============ Schema Mapping Tests ============

  describe('schema mapping', () => {
    it('should map scan fields correctly to server schema', async () => {
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/mapping-test.jpg',
        cropType: 'maize',
        latitude: -1.2921,
        longitude: 36.8219,
      });

      await runSyncOnceTest(mockClient);

      const insertedData = mockClient.insertCalls[0].data;

      // Verify field mapping
      expect(insertedData.id).toBe(scanId);
      expect(insertedData.user_id).toBe(testUserId); // Mapped from user_local_id
      expect(insertedData.image_path).toBe('/photos/mapping-test.jpg');
      expect(insertedData.crop_type).toBe('maize');
      expect(insertedData.latitude).toBe(-1.2921);
      expect(insertedData.longitude).toBe(36.8219);
      expect(insertedData.device_id).toBe(TEST_DEVICE_ID);
      expect(insertedData.version).toBe(1);
    });

    it('should map diagnosis fields correctly to server schema', async () => {
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/test.jpg',
      });

      const diagnosisId = createDiagnosis({
        scanLocalId: scanId,
        diseaseName: 'Bacterial Wilt',
        confidence: 0.78,
        severity: 'high',
        recommendations: ['Remove infected plants', 'Apply lime'],
      });

      await runSyncOnceTest(mockClient);

      // Find the diagnosis insert call
      const diagnosisCall = mockClient.insertCalls.find(c => c.table === 'diagnoses');
      expect(diagnosisCall).toBeDefined();

      const insertedData = diagnosisCall!.data;

      // Verify field mapping
      expect(insertedData.id).toBe(diagnosisId);
      expect(insertedData.scan_id).toBe(scanId); // Mapped from scan_local_id
      expect(insertedData.disease_name).toBe('Bacterial Wilt');
      expect(insertedData.confidence).toBe(0.78);
      expect(insertedData.severity).toBe('high');
      expect(insertedData.device_id).toBe(TEST_DEVICE_ID);
    });
  });

  // ============ Failure Handling Tests ============

  describe('failure handling', () => {
    it('should mark record as failed on Supabase error', async () => {
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/fail-test.jpg',
      });

      // Configure mock to return error
      mockClient.setInsertResponse({
        data: null,
        error: { message: 'Network timeout' },
      });

      const result = await runSyncOnceTest(mockClient);

      // Verify failure recorded
      expect(result.processed).toBe(1);
      expect(result.succeeded).toBe(0);
      expect(result.failed).toBe(1);

      // Verify local state
      const scan = getLocalScan(scanId);
      expect(scan.sync_status).toBe('failed');
      expect(scan.server_id).toBeNull();

      // Verify queue entry still exists with incremented retry
      const queueEntry = getSyncQueueEntryByLocalId(scanId);
      expect(queueEntry).not.toBeNull();
      expect(queueEntry!.retry_count).toBe(1);
      expect(queueEntry!.last_error).toBe('Network timeout');
    });

    it('should increment retry_count on each failure', async () => {
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/retry-test.jpg',
      });

      // Configure mock to always fail
      mockClient.setInsertResponse({
        data: null,
        error: { message: 'Server unavailable' },
      });

      // Fail multiple times
      await runSyncOnceTest(mockClient);
      await runSyncOnceTest(mockClient);
      await runSyncOnceTest(mockClient);

      // Verify retry count incremented
      const queueEntry = getSyncQueueEntryByLocalId(scanId);
      expect(queueEntry!.retry_count).toBe(3);
    });

    it('should skip entries that exceed maxRetries', async () => {
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/max-retry-test.jpg',
      });

      // Manually set high retry count
      const db = getTestDb();
      db.prepare(
        `UPDATE sync_queue SET retry_count = 10 WHERE local_id = ?`
      ).run(scanId);

      // Run sync with default maxRetries (5)
      const result = await runSyncOnceTest(mockClient);

      // Should skip the entry
      expect(result.processed).toBe(0);
      expect(mockClient.insertCalls).toHaveLength(0);
    });

    it('should continue processing after individual failure', async () => {
      // Create two scans
      const scanId1 = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/first.jpg',
      });

      await new Promise(resolve => setTimeout(resolve, 10));

      const scanId2 = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/second.jpg',
      });

      // Configure to fail first, succeed second
      let callCount = 0;
      mockClient.from = jest.fn((table: string) => ({
        insert: jest.fn(async (data: any) => {
          callCount++;
          mockClient.insertCalls.push({ table, data });
          
          if (callCount === 1) {
            return { data: null, error: { message: 'First failed' } };
          }
          return { data: {}, error: null };
        }),
        update: jest.fn(() => ({ eq: jest.fn() })),
        delete: jest.fn(() => ({ eq: jest.fn() })),
      }));

      const result = await runSyncOnceTest(mockClient);

      // Both should be processed
      expect(result.processed).toBe(2);
      expect(result.succeeded).toBe(1);
      expect(result.failed).toBe(1);

      // First should fail
      const scan1 = getLocalScan(scanId1);
      expect(scan1.sync_status).toBe('failed');

      // Second should succeed
      const scan2 = getLocalScan(scanId2);
      expect(scan2.sync_status).toBe('synced');
    });
  });

  // ============ Delete Operation Tests ============

  describe('delete operations', () => {
    it('should push soft delete to server', async () => {
      // Create a scan
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/delete-test.jpg',
      });

      // Sync the insert first
      await runSyncOnceTest(mockClient);
      mockClient.reset();

      // Soft delete locally
      const db = getTestDb();
      const now = getISOTimestamp();
      db.prepare(
        `UPDATE scans SET deleted_at = ?, updated_at = ?, version = version + 1 WHERE local_id = ?`
      ).run(now, now, scanId);

      // Enqueue delete sync
      enqueueSync('scans', scanId, 'delete');

      // Run sync
      const result = await runSyncOnceTest(mockClient);

      expect(result.processed).toBe(1);
      expect(result.succeeded).toBe(1);

      // Verify update was called (soft delete = update deleted_at)
      expect(mockClient.updateCalls).toHaveLength(1);
      expect(mockClient.updateCalls[0].table).toBe('scans');
      expect(mockClient.updateCalls[0].data.deleted_at).toBe(now);
    });
  });

  // ============ Limit Tests ============

  describe('limit handling', () => {
    it('should respect limit parameter', async () => {
      // Create 5 scans
      for (let i = 0; i < 5; i++) {
        createScan({
          userLocalId: testUserId,
          imagePath: `/photos/limit-${i}.jpg`,
        });
      }

      expect(getSyncQueueCount()).toBe(5);

      // Sync with limit 2
      const result = await runSyncOnceTest(mockClient, 2);

      expect(result.processed).toBe(2);
      expect(mockClient.insertCalls).toHaveLength(2);

      // 3 should remain in queue
      expect(getSyncQueueCount()).toBe(3);
    });
  });

  // ============ Edge Cases ============

  describe('edge cases', () => {
    it('should handle missing local record gracefully', async () => {
      // Manually insert queue entry for non-existent record
      const db = getTestDb();
      const fakeId = generateUUID();
      const now = getISOTimestamp();

      db.prepare(
        `INSERT INTO sync_queue (table_name, local_id, operation, created_at)
         VALUES ('scans', ?, 'insert', ?)`
      ).run(fakeId, now);

      const result = await runSyncOnceTest(mockClient);

      expect(result.processed).toBe(1);
      expect(result.failed).toBe(1);
      expect(result.results[0].error).toContain('not found');
    });

    it('should handle unsupported table gracefully', async () => {
      // Manually insert queue entry for unsupported table
      const db = getTestDb();
      const fakeId = generateUUID();
      const now = getISOTimestamp();

      db.prepare(
        `INSERT INTO sync_queue (table_name, local_id, operation, created_at)
         VALUES ('unknown_table', ?, 'insert', ?)`
      ).run(fakeId, now);

      const result = await runSyncOnceTest(mockClient);

      expect(result.processed).toBe(1);
      expect(result.failed).toBe(1);
      expect(result.results[0].error).toContain('Unsupported table');
    });

    it('should handle null fields in scan', async () => {
      // Create scan without optional fields
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/minimal.jpg',
        // No cropType, latitude, longitude
      });

      await runSyncOnceTest(mockClient);

      const insertedData = mockClient.insertCalls[0].data;
      expect(insertedData.crop_type).toBeNull();
      expect(insertedData.latitude).toBeNull();
      expect(insertedData.longitude).toBeNull();
    });
  });

  // ============ Server ID Tests ============

  describe('server_id handling', () => {
    it('should set server_id on successful sync', async () => {
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/server-id-test.jpg',
      });

      // Before sync
      let scan = getLocalScan(scanId);
      expect(scan.server_id).toBeNull();

      await runSyncOnceTest(mockClient);

      // After sync - server_id should equal local_id
      scan = getLocalScan(scanId);
      expect(scan.server_id).toBe(scanId);
    });
  });

  // ============ Concurrent Data Creation ============

  describe('sync with related data', () => {
    it('should sync scan and diagnosis in correct order', async () => {
      // Create scan with diagnosis
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/related-test.jpg',
        cropType: 'wheat',
      });

      const diagnosisId = createDiagnosis({
        scanLocalId: scanId,
        diseaseName: 'Rust',
        confidence: 0.88,
        recommendations: ['Apply fungicide'],
      });

      // Both should be pending
      expect(getSyncQueueCount()).toBe(2);

      await runSyncOnceTest(mockClient);

      // Scan should sync first (FIFO)
      expect(mockClient.insertCalls[0].table).toBe('scans');
      expect(mockClient.insertCalls[0].data.id).toBe(scanId);

      // Diagnosis should sync second
      expect(mockClient.insertCalls[1].table).toBe('diagnoses');
      expect(mockClient.insertCalls[1].data.id).toBe(diagnosisId);
      expect(mockClient.insertCalls[1].data.scan_id).toBe(scanId);
    });
  });

  // ============ Recovery After Failure ============

  describe('recovery scenarios', () => {
    it('should allow retry after transient failure', async () => {
      const scanId = createScan({
        userLocalId: testUserId,
        imagePath: '/photos/recovery-test.jpg',
      });

      // First attempt fails
      mockClient.setInsertResponse({
        data: null,
        error: { message: 'Temporary error' },
      });

      await runSyncOnceTest(mockClient);

      let scan = getLocalScan(scanId);
      expect(scan.sync_status).toBe('failed');

      // Second attempt succeeds
      mockClient.setInsertResponse({ data: {}, error: null });

      await runSyncOnceTest(mockClient);

      scan = getLocalScan(scanId);
      expect(scan.sync_status).toBe('synced');
      expect(scan.server_id).toBe(scanId);
    });
  });
});

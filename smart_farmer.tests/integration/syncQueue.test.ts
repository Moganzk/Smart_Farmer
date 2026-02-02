/**
 * Sync Queue Integration Tests
 * 
 * Tests sync queue operations against a real SQLite database.
 * Uses better-sqlite3 for Node.js compatibility.
 * 
 * TEST TIER: Integration
 * RUN: npm run test:integration
 */

import {
  getTestDb,
  resetTestDb,
  closeTestDb,
  initTestDb,
  generateUUID,
  getISOTimestamp,
  enqueueSync,
  markSynced,
  markFailed,
  getPendingQueue,
  TEST_DEVICE_ID,
} from '../helpers/integrationDb';

describe('Sync Queue Operations', () => {
  beforeAll(() => {
    initTestDb();
  });

  beforeEach(() => {
    // Clear sync queue between tests
    const db = getTestDb();
    db.exec('DELETE FROM sync_queue');
    db.exec('DELETE FROM scans');
  });

  afterAll(() => {
    closeTestDb();
  });

  it('should add item to sync queue', () => {
    const entityId = generateUUID();
    
    enqueueSync('scans', entityId, 'insert');

    const db = getTestDb();
    const row = db.prepare(
      'SELECT * FROM sync_queue WHERE local_id = ?'
    ).get(entityId) as any;

    expect(row).toBeDefined();
    expect(row.table_name).toBe('scans');
    expect(row.local_id).toBe(entityId);
    expect(row.operation).toBe('insert');
    expect(row.retry_count).toBe(0);
    expect(row.last_attempted_at).toBeNull();
  });

  it('should get pending sync items', () => {
    // Add multiple items
    const id1 = generateUUID();
    const id2 = generateUUID();
    const id3 = generateUUID();
    
    enqueueSync('scans', id1, 'insert');
    enqueueSync('users', id2, 'update');
    enqueueSync('tips', id3, 'delete');

    const queue = getPendingQueue();

    expect(queue.length).toBeGreaterThanOrEqual(3);
  });

  it('should mark item as synced', () => {
    const db = getTestDb();
    const entityId = generateUUID();
    const now = getISOTimestamp();
    
    // Insert a scan first
    db.prepare(
      `INSERT INTO scans (local_id, user_local_id, image_path, scanned_at, device_id, sync_status, updated_at, version)
       VALUES (?, ?, ?, ?, ?, 'pending', ?, 1)`
    ).run(entityId, 'test_user', '/test.jpg', now, TEST_DEVICE_ID, now);
    
    enqueueSync('scans', entityId, 'insert');
    markSynced('scans', entityId);

    const queueRow = db.prepare(
      'SELECT * FROM sync_queue WHERE local_id = ?'
    ).get(entityId);

    expect(queueRow).toBeUndefined();
    
    // Check scan record is marked synced
    const scanRow = db.prepare(
      'SELECT sync_status FROM scans WHERE local_id = ?'
    ).get(entityId) as any;
    expect(scanRow.sync_status).toBe('synced');
  });

  it('should mark sync as failed and increment retry count', () => {
    const db = getTestDb();
    const entityId = generateUUID();
    const now = getISOTimestamp();
    
    // Insert a scan first
    db.prepare(
      `INSERT INTO scans (local_id, user_local_id, image_path, scanned_at, device_id, sync_status, updated_at, version)
       VALUES (?, ?, ?, ?, ?, 'pending', ?, 1)`
    ).run(entityId, 'test_user', '/test.jpg', now, TEST_DEVICE_ID, now);

    enqueueSync('scans', entityId, 'insert');
    markFailed('scans', entityId, 'Network error');

    const row = db.prepare(
      'SELECT * FROM sync_queue WHERE local_id = ?'
    ).get(entityId) as any;

    expect(row).toBeDefined();
    expect(row.retry_count).toBe(1);
    expect(row.last_error).toBe('Network error');
    expect(row.last_attempted_at).not.toBeNull();
  });

  it('should handle multiple retry increments', () => {
    const db = getTestDb();
    const entityId = generateUUID();
    const now = getISOTimestamp();
    
    // Insert a scan first
    db.prepare(
      `INSERT INTO scans (local_id, user_local_id, image_path, scanned_at, device_id, sync_status, updated_at, version)
       VALUES (?, ?, ?, ?, ?, 'pending', ?, 1)`
    ).run(entityId, 'test_user', '/test.jpg', now, TEST_DEVICE_ID, now);

    enqueueSync('scans', entityId, 'insert');
    
    // Fail multiple times
    markFailed('scans', entityId, 'Error 1');
    markFailed('scans', entityId, 'Error 2');
    markFailed('scans', entityId, 'Error 3');

    const row = db.prepare(
      'SELECT * FROM sync_queue WHERE local_id = ?'
    ).get(entityId) as any;

    expect(row).toBeDefined();
    expect(row.retry_count).toBe(3);
  });
});

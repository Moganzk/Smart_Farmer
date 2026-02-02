/**
 * Scan SQLite Integration Tests
 * 
 * Tests the scan workflow against a real SQLite database.
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
  TEST_DEVICE_ID,
} from '../helpers/integrationDb';

describe('SQLite Scan Integration', () => {
  beforeAll(() => {
    initTestDb();
  });

  beforeEach(() => {
    // Clear test data between tests
    const db = getTestDb();
    db.exec('DELETE FROM sync_queue');
    db.exec('DELETE FROM diagnoses');
    db.exec('DELETE FROM scans');
  });

  afterAll(() => {
    closeTestDb();
  });

  it('should save scan to SQLite', () => {
    const db = getTestDb();
    const localId = generateUUID();
    const userId = 'test_user_1';
    const imagePath = '/path/to/image.jpg';
    const cropType = 'Tomato';
    const now = getISOTimestamp();

    db.prepare(
      `INSERT INTO scans (local_id, user_local_id, image_path, crop_type, scanned_at, device_id, sync_status, updated_at, version)
       VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, 1)`
    ).run(localId, userId, imagePath, cropType, now, TEST_DEVICE_ID, now);

    const row = db.prepare(
      'SELECT * FROM scans WHERE local_id = ?'
    ).get(localId) as any;

    expect(row).toBeDefined();
    expect(row.local_id).toBe(localId);
    expect(row.crop_type).toBe(cropType);
    expect(row.sync_status).toBe('pending');
  });

  it('should add scan to sync queue', () => {
    const localId = generateUUID();
    
    enqueueSync('scans', localId, 'insert');

    const db = getTestDb();
    const row = db.prepare(
      'SELECT * FROM sync_queue WHERE local_id = ?'
    ).get(localId) as any;

    expect(row).toBeDefined();
    expect(row.table_name).toBe('scans');
    expect(row.operation).toBe('insert');
    expect(row.retry_count).toBe(0);
  });

  it('should load scan from diagnoses table', () => {
    const db = getTestDb();
    const scanLocalId = generateUUID();
    const diagnosisLocalId = generateUUID();
    const diseaseName = 'Test Disease';
    const confidence = 0.88;
    const recommendations = 'Test recommendations';
    const now = getISOTimestamp();

    // First insert a scan
    db.prepare(
      `INSERT INTO scans (local_id, user_local_id, image_path, scanned_at, device_id, sync_status, updated_at, version)
       VALUES (?, ?, ?, ?, ?, 'synced', ?, 1)`
    ).run(scanLocalId, 'test_user', '/test.jpg', now, TEST_DEVICE_ID, now);

    // Insert diagnosis
    db.prepare(
      `INSERT INTO diagnoses (local_id, scan_local_id, disease_name, confidence, recommendations, diagnosed_at, device_id, sync_status, updated_at, version)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'synced', ?, 1)`
    ).run(diagnosisLocalId, scanLocalId, diseaseName, confidence, recommendations, now, TEST_DEVICE_ID, now);

    const row = db.prepare(
      'SELECT * FROM diagnoses WHERE scan_local_id = ?'
    ).get(scanLocalId) as any;

    expect(row).toBeDefined();
    expect(row.disease_name).toBe(diseaseName);
    expect(row.confidence).toBe(confidence);
  });

  it('should load scan history for user', () => {
    const db = getTestDb();
    const userId = 'test_history_user';
    const now = getISOTimestamp();

    // Insert multiple scans for the user
    for (let i = 0; i < 3; i++) {
      const scanId = generateUUID();
      db.prepare(
        `INSERT INTO scans (local_id, user_local_id, image_path, scanned_at, device_id, sync_status, updated_at, version)
         VALUES (?, ?, ?, ?, ?, 'synced', ?, 1)`
      ).run(scanId, userId, `/test_${i}.jpg`, now, TEST_DEVICE_ID, now);
    }

    const rows = db.prepare(
      'SELECT * FROM scans WHERE user_local_id = ? AND deleted_at IS NULL ORDER BY scanned_at DESC'
    ).all(userId) as any[];

    expect(rows).toBeDefined();
    expect(rows.length).toBe(3);
  });
});

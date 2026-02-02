/**
 * Offline Scan → SQLite → History Integration Tests
 * 
 * Tests the complete offline loop:
 * 1. User performs a scan → data written to SQLite
 * 2. History screen reads from SQLite and displays results
 * 
 * All tests use real SQLite (better-sqlite3), no mocks.
 * 
 * TEST TIER: Integration
 * RUN: npm run test:integration
 */

import {
  getTestDb,
  closeTestDb,
  initTestDb,
  clearAllTables,
  generateUUID,
  getISOTimestamp,
  TEST_DEVICE_ID,
  // Scan service functions
  createScan,
  createDiagnosis,
  getScanHistory,
  getScanById,
  performScan,
  CreateScanInput,
  CreateDiagnosisInput,
  ScanWithDiagnosis,
} from '../helpers/integrationDb';

describe('Offline Scan → SQLite → History Flow', () => {
  const testUserId = 'test-user-' + Date.now();

  beforeAll(() => {
    initTestDb();
  });

  beforeEach(() => {
    clearAllTables();
  });

  afterAll(() => {
    closeTestDb();
  });

  // ============ Scan Creation Tests ============

  describe('Scan Creation', () => {
    it('should create a scan record with proper fields', () => {
      const scanLocalId = createScan({
        userLocalId: testUserId,
        imagePath: '/path/to/test/image.jpg',
        cropType: 'Tomato',
      });

      // Verify scan was created
      const db = getTestDb();
      const scan = db.prepare('SELECT * FROM scans WHERE local_id = ?').get(scanLocalId) as any;

      expect(scan).toBeDefined();
      expect(scan.local_id).toBe(scanLocalId);
      expect(scan.user_local_id).toBe(testUserId);
      expect(scan.image_path).toBe('/path/to/test/image.jpg');
      expect(scan.crop_type).toBe('Tomato');
      expect(scan.sync_status).toBe('pending');
      expect(scan.device_id).toBe(TEST_DEVICE_ID);
      expect(scan.version).toBe(1);
      expect(scan.deleted_at).toBeNull();
      expect(scan.scanned_at).toBeTruthy();
      expect(scan.updated_at).toBeTruthy();
    });

    it('should create a scan with optional fields null', () => {
      const scanLocalId = createScan({
        userLocalId: testUserId,
        imagePath: '/minimal/scan.jpg',
      });

      const db = getTestDb();
      const scan = db.prepare('SELECT * FROM scans WHERE local_id = ?').get(scanLocalId) as any;

      expect(scan.crop_type).toBeNull();
      expect(scan.latitude).toBeNull();
      expect(scan.longitude).toBeNull();
    });

    it('should generate unique local_id for each scan', () => {
      const id1 = createScan({ userLocalId: testUserId, imagePath: '/img1.jpg' });
      const id2 = createScan({ userLocalId: testUserId, imagePath: '/img2.jpg' });
      const id3 = createScan({ userLocalId: testUserId, imagePath: '/img3.jpg' });

      expect(id1).not.toBe(id2);
      expect(id2).not.toBe(id3);
      expect(id1).not.toBe(id3);
    });
  });

  // ============ Diagnosis Creation Tests ============

  describe('Diagnosis Creation', () => {
    it('should create a diagnosis linked to a scan', () => {
      const scanLocalId = createScan({
        userLocalId: testUserId,
        imagePath: '/test.jpg',
      });

      const diagnosisLocalId = createDiagnosis({
        scanLocalId,
        diseaseName: 'Late Blight',
        confidence: 0.92,
        severity: 'high',
        recommendations: ['Remove infected parts', 'Apply fungicide'],
      });

      const db = getTestDb();
      const diagnosis = db.prepare('SELECT * FROM diagnoses WHERE local_id = ?').get(diagnosisLocalId) as any;

      expect(diagnosis).toBeDefined();
      expect(diagnosis.scan_local_id).toBe(scanLocalId);
      expect(diagnosis.disease_name).toBe('Late Blight');
      expect(diagnosis.confidence).toBe(0.92);
      expect(diagnosis.severity).toBe('high');
      expect(diagnosis.sync_status).toBe('pending');
      expect(diagnosis.device_id).toBe(TEST_DEVICE_ID);

      // Recommendations should be JSON string
      const recs = JSON.parse(diagnosis.recommendations);
      expect(recs).toEqual(['Remove infected parts', 'Apply fungicide']);
    });

    it('should create diagnosis with null severity', () => {
      const scanLocalId = createScan({ userLocalId: testUserId, imagePath: '/t.jpg' });
      const diagnosisLocalId = createDiagnosis({
        scanLocalId,
        diseaseName: 'Unknown',
        confidence: 0.5,
        recommendations: ['Consult an expert'],
      });

      const db = getTestDb();
      const diagnosis = db.prepare('SELECT * FROM diagnoses WHERE local_id = ?').get(diagnosisLocalId) as any;

      expect(diagnosis.severity).toBeNull();
    });
  });

  // ============ Full Scan Workflow Tests ============

  describe('Full Scan Workflow (performScan)', () => {
    it('should create both scan and diagnosis records', () => {
      const scanLocalId = performScan(testUserId, '/captured/image.jpg', 'Potato');

      const db = getTestDb();

      // Check scan exists
      const scan = db.prepare('SELECT * FROM scans WHERE local_id = ?').get(scanLocalId) as any;
      expect(scan).toBeDefined();
      expect(scan.crop_type).toBe('Potato');

      // Check diagnosis exists and is linked
      const diagnosis = db.prepare('SELECT * FROM diagnoses WHERE scan_local_id = ?').get(scanLocalId) as any;
      expect(diagnosis).toBeDefined();
      expect(diagnosis.disease_name).toBe('Late Blight');
      expect(diagnosis.confidence).toBe(0.87);
    });

    it('should work with mock detection result', () => {
      const scanLocalId = performScan(testUserId, '/scan.jpg');

      const result = getScanById(scanLocalId);

      expect(result).not.toBeNull();
      expect(result!.disease_name).toBe('Late Blight');
      expect(result!.confidence).toBe(0.87);
      expect(result!.severity).toBe('medium');
    });
  });

  // ============ History Query Tests ============

  describe('History Screen Queries', () => {
    it('should return scan with diagnosis via getScanById', () => {
      const scanLocalId = performScan(testUserId, '/test/image.jpg', 'Maize');

      const result = getScanById(scanLocalId);

      expect(result).not.toBeNull();
      expect(result!.local_id).toBe(scanLocalId);
      expect(result!.image_path).toBe('/test/image.jpg');
      expect(result!.crop_type).toBe('Maize');
      expect(result!.disease_name).toBe('Late Blight');
      expect(result!.confidence).toBe(0.87);
    });

    it('should return null for non-existent scan', () => {
      const result = getScanById('non-existent-id');
      expect(result).toBeNull();
    });

    it('should return history for user', () => {
      // Create multiple scans
      performScan(testUserId, '/img1.jpg', 'Tomato');
      performScan(testUserId, '/img2.jpg', 'Potato');

      const history = getScanHistory(testUserId);

      expect(history.length).toBe(2);
      expect(history.every(h => h.disease_name === 'Late Blight')).toBe(true);
    });

    it('should return empty array for user with no scans', () => {
      const history = getScanHistory('user-with-no-scans');
      expect(history).toEqual([]);
    });

    it('should not return scans from other users', () => {
      performScan(testUserId, '/my-scan.jpg');
      performScan('other-user', '/their-scan.jpg');

      const myHistory = getScanHistory(testUserId);
      const otherHistory = getScanHistory('other-user');

      expect(myHistory.length).toBe(1);
      expect(otherHistory.length).toBe(1);
    });

    it('should order history by scanned_at descending (newest first)', () => {
      // Create scans with small delays to ensure different timestamps
      const db = getTestDb();
      
      // Insert scans with explicit timestamps
      const scan1Id = generateUUID();
      const scan2Id = generateUUID();
      const scan3Id = generateUUID();
      const oldTime = '2024-01-01T10:00:00.000Z';
      const midTime = '2024-01-01T11:00:00.000Z';
      const newTime = '2024-01-01T12:00:00.000Z';

      // Insert in non-chronological order
      db.prepare(`INSERT INTO scans (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, user_local_id, image_path, scanned_at) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, ?, ?)`).run(scan2Id, midTime, TEST_DEVICE_ID, testUserId, '/middle.jpg', midTime);
      db.prepare(`INSERT INTO scans (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, user_local_id, image_path, scanned_at) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, ?, ?)`).run(scan1Id, oldTime, TEST_DEVICE_ID, testUserId, '/oldest.jpg', oldTime);
      db.prepare(`INSERT INTO scans (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, user_local_id, image_path, scanned_at) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, ?, ?)`).run(scan3Id, newTime, TEST_DEVICE_ID, testUserId, '/newest.jpg', newTime);

      // Add diagnoses
      db.prepare(`INSERT INTO diagnoses (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, scan_local_id, disease_name, confidence, recommendations, diagnosed_at) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, 'Disease A', 0.9, '[]', ?)`).run(generateUUID(), oldTime, TEST_DEVICE_ID, scan1Id, oldTime);
      db.prepare(`INSERT INTO diagnoses (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, scan_local_id, disease_name, confidence, recommendations, diagnosed_at) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, 'Disease B', 0.8, '[]', ?)`).run(generateUUID(), midTime, TEST_DEVICE_ID, scan2Id, midTime);
      db.prepare(`INSERT INTO diagnoses (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, scan_local_id, disease_name, confidence, recommendations, diagnosed_at) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, 'Disease C', 0.7, '[]', ?)`).run(generateUUID(), newTime, TEST_DEVICE_ID, scan3Id, newTime);

      const history = getScanHistory(testUserId);

      expect(history.length).toBe(3);
      expect(history[0].image_path).toBe('/newest.jpg');  // Most recent first
      expect(history[1].image_path).toBe('/middle.jpg');
      expect(history[2].image_path).toBe('/oldest.jpg');
    });

    it('should respect limit parameter', () => {
      // Create 5 scans
      for (let i = 0; i < 5; i++) {
        performScan(testUserId, `/img${i}.jpg`);
      }

      const limitedHistory = getScanHistory(testUserId, 3);
      const fullHistory = getScanHistory(testUserId, 10);

      expect(limitedHistory.length).toBe(3);
      expect(fullHistory.length).toBe(5);
    });

    it('should not return soft-deleted scans', () => {
      const scanLocalId = performScan(testUserId, '/to-delete.jpg');
      const db = getTestDb();

      // Verify scan appears in history
      let history = getScanHistory(testUserId);
      expect(history.length).toBe(1);

      // Soft delete the scan
      db.prepare('UPDATE scans SET deleted_at = ? WHERE local_id = ?').run(getISOTimestamp(), scanLocalId);

      // Verify scan no longer appears
      history = getScanHistory(testUserId);
      expect(history.length).toBe(0);
    });

    it('should not return scans with soft-deleted diagnoses', () => {
      const scanLocalId = performScan(testUserId, '/scan-with-deleted-diagnosis.jpg');
      const db = getTestDb();

      // Verify scan appears
      expect(getScanHistory(testUserId).length).toBe(1);

      // Soft delete the diagnosis
      db.prepare('UPDATE diagnoses SET deleted_at = ? WHERE scan_local_id = ?').run(getISOTimestamp(), scanLocalId);

      // Scan should no longer appear (no valid diagnosis)
      expect(getScanHistory(testUserId).length).toBe(0);
    });
  });

  // ============ Offline Data Integrity Tests ============

  describe('Offline Data Integrity', () => {
    it('should maintain referential integrity between scan and diagnosis', () => {
      const scanLocalId = performScan(testUserId, '/ref-test.jpg');
      const db = getTestDb();

      // Both records should reference each other correctly
      const scan = db.prepare('SELECT * FROM scans WHERE local_id = ?').get(scanLocalId) as any;
      const diagnosis = db.prepare('SELECT * FROM diagnoses WHERE scan_local_id = ?').get(scanLocalId) as any;

      expect(diagnosis.scan_local_id).toBe(scan.local_id);
    });

    it('should set sync_status to pending for new records', () => {
      const scanLocalId = performScan(testUserId, '/pending-test.jpg');
      const db = getTestDb();

      const scan = db.prepare('SELECT sync_status FROM scans WHERE local_id = ?').get(scanLocalId) as any;
      const diagnosis = db.prepare('SELECT sync_status FROM diagnoses WHERE scan_local_id = ?').get(scanLocalId) as any;

      expect(scan.sync_status).toBe('pending');
      expect(diagnosis.sync_status).toBe('pending');
    });

    it('should preserve recommendations as valid JSON', () => {
      const scanLocalId = createScan({ userLocalId: testUserId, imagePath: '/json-test.jpg' });
      const recommendations = [
        'First recommendation with special chars: "quotes" & <brackets>',
        'Second recommendation',
        'Third with unicode: 🌱',
      ];

      createDiagnosis({
        scanLocalId,
        diseaseName: 'Test',
        confidence: 0.8,
        recommendations,
      });

      const result = getScanById(scanLocalId);
      const parsedRecs = JSON.parse(result!.recommendations);

      expect(parsedRecs).toEqual(recommendations);
    });
  });
});

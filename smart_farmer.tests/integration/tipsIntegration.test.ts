/**
 * Tips SQLite Integration Tests
 * 
 * Tests the tips feature against a real SQLite database.
 * Uses better-sqlite3 for Node.js compatibility.
 * 
 * TEST TIER: Integration
 * RUN: npm run test:integration
 */

import {
  getTestDb,
  closeTestDb,
  initTestDb,
  generateUUID,
  getISOTimestamp,
  TEST_DEVICE_ID,
} from '../helpers/integrationDb';

describe('Tips SQLite Integration', () => {
  beforeAll(() => {
    initTestDb();
  });

  beforeEach(() => {
    // Clear tips between tests
    const db = getTestDb();
    db.exec('DELETE FROM tips');
  });

  afterAll(() => {
    closeTestDb();
  });

  it('should load tips from SQLite', () => {
    const db = getTestDb();
    const now = getISOTimestamp();

    // Insert test tips
    const tips = [
      { title: 'Watering Tips', content: 'Water regularly', category: 'Care', language: 'en' },
      { title: 'Fertilizer Guide', content: 'Use organic', category: 'Nutrition', language: 'en' },
    ];

    for (const tip of tips) {
      const id = generateUUID();
      db.prepare(
        `INSERT INTO tips (local_id, title, content, category, language, published_at, device_id, sync_status, updated_at, version)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'synced', ?, 1)`
      ).run(id, tip.title, tip.content, tip.category, tip.language, now, TEST_DEVICE_ID, now);
    }

    const rows = db.prepare(
      'SELECT local_id, title, content, category FROM tips WHERE deleted_at IS NULL ORDER BY updated_at DESC LIMIT 20'
    ).all() as any[];

    expect(rows).toBeDefined();
    expect(rows.length).toBeGreaterThanOrEqual(2);
    
    const titles = rows.map((r: any) => r.title);
    expect(titles).toContain('Watering Tips');
    expect(titles).toContain('Fertilizer Guide');
  });

  it('should filter tips by category', () => {
    const db = getTestDb();
    const now = getISOTimestamp();

    // Insert tips with different categories
    const categories = ['Care', 'Nutrition', 'Care', 'Pest Control'];
    for (const category of categories) {
      const id = generateUUID();
      db.prepare(
        `INSERT INTO tips (local_id, title, content, category, language, published_at, device_id, sync_status, updated_at, version)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'synced', ?, 1)`
      ).run(id, `Tip for ${category}`, 'Content', category, 'en', now, TEST_DEVICE_ID, now);
    }

    const careTips = db.prepare(
      'SELECT * FROM tips WHERE category = ? AND deleted_at IS NULL'
    ).all('Care') as any[];

    expect(careTips.length).toBe(2);
  });

  it('should respect soft delete on tips', () => {
    const db = getTestDb();
    const now = getISOTimestamp();

    // Insert a tip
    const tipId = generateUUID();
    db.prepare(
      `INSERT INTO tips (local_id, title, content, category, language, published_at, device_id, sync_status, updated_at, version)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'synced', ?, 1)`
    ).run(tipId, 'Deleted Tip', 'Content', 'Care', 'en', now, TEST_DEVICE_ID, now);

    // Soft delete it
    db.prepare(
      `UPDATE tips SET deleted_at = ?, updated_at = ? WHERE local_id = ?`
    ).run(now, now, tipId);

    // Query should not return deleted tips
    const rows = db.prepare(
      'SELECT * FROM tips WHERE deleted_at IS NULL'
    ).all() as any[];

    const deletedTip = rows.find((r: any) => r.local_id === tipId);
    expect(deletedTip).toBeUndefined();
  });
});

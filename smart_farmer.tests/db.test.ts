/**
 * Smart Farmer - Database Tests
 * 
 * Tests for SQLite database initialization and sync operations.
 * Uses in-memory database for isolation.
 */

import {
  initDb,
  resetDatabase,
  closeDb,
  getDatabase,
  tableExists,
  generateUUID,
  getISOTimestamp,
  createSyncFields,
  getDeviceId,
  enqueueSync,
  markSynced,
  markFailed,
  getPendingQueue,
  softDelete,
  getPendingCount,
} from './testDb';

describe('Database Initialization', () => {
  beforeEach(() => {
    resetDatabase();
  });

  afterAll(() => {
    closeDb();
  });

  test('initDb creates all required tables', () => {
    initDb();

    expect(tableExists('users')).toBe(true);
    expect(tableExists('scans')).toBe(true);
    expect(tableExists('diagnoses')).toBe(true);
    expect(tableExists('tips')).toBe(true);
    expect(tableExists('notifications')).toBe(true);
    expect(tableExists('sync_queue')).toBe(true);
  });

  test('initDb is idempotent (can be called multiple times)', () => {
    initDb();
    initDb();
    initDb();

    // Should not throw and tables should still exist
    expect(tableExists('users')).toBe(true);
    expect(tableExists('scans')).toBe(true);
    expect(tableExists('sync_queue')).toBe(true);
  });

  test('tables have correct sync metadata columns', () => {
    initDb();
    const db = getDatabase();

    // Check users table structure
    const columns = db.pragma('table_info(users)') as Array<{
      name: string;
      type: string;
      notnull: number;
      pk: number;
    }>;

    const columnNames = columns.map((c) => c.name);
    
    // All sync fields must be present
    expect(columnNames).toContain('local_id');
    expect(columnNames).toContain('server_id');
    expect(columnNames).toContain('sync_status');
    expect(columnNames).toContain('updated_at');
    expect(columnNames).toContain('deleted_at');
    expect(columnNames).toContain('device_id');
    expect(columnNames).toContain('version');
  });

  test('sync_queue table has correct structure', () => {
    initDb();
    const db = getDatabase();

    const columns = db.pragma('table_info(sync_queue)') as Array<{
      name: string;
      type: string;
    }>;

    const columnNames = columns.map((c) => c.name);
    
    expect(columnNames).toContain('id');
    expect(columnNames).toContain('table_name');
    expect(columnNames).toContain('local_id');
    expect(columnNames).toContain('operation');
    expect(columnNames).toContain('payload');
    expect(columnNames).toContain('retry_count');
    expect(columnNames).toContain('last_error');
    expect(columnNames).toContain('created_at');
    expect(columnNames).toContain('last_attempted_at');
  });
});

describe('Sync Field Defaults', () => {
  beforeEach(() => {
    resetDatabase();
    initDb();
  });

  afterAll(() => {
    closeDb();
  });

  test('createSyncFields generates valid UUID', () => {
    const fields = createSyncFields();
    
    // UUID v4 format
    expect(fields.local_id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    );
  });

  test('createSyncFields sets correct default values', () => {
    const fields = createSyncFields();
    
    expect(fields.server_id).toBeNull();
    expect(fields.sync_status).toBe('pending');
    expect(fields.deleted_at).toBeNull();
    expect(fields.version).toBe(1);
    expect(fields.device_id).toBe(getDeviceId());
  });

  test('createSyncFields sets valid ISO timestamp', () => {
    const fields = createSyncFields();
    
    // Should be a valid ISO 8601 date
    const date = new Date(fields.updated_at);
    expect(date.toISOString()).toBe(fields.updated_at);
  });

  test('inserting a record sets default sync fields correctly', () => {
    const db = getDatabase();
    const fields = createSyncFields();
    const now = getISOTimestamp();

    db.prepare(`
      INSERT INTO users (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, phone_number, name, language, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      fields.local_id,
      fields.server_id,
      fields.sync_status,
      fields.updated_at,
      fields.deleted_at,
      fields.device_id,
      fields.version,
      '+254712345678',
      'Test User',
      'en',
      now
    );

    const user = db.prepare('SELECT * FROM users WHERE local_id = ?').get(fields.local_id) as Record<string, unknown>;

    expect(user.sync_status).toBe('pending');
    expect(user.server_id).toBeNull();
    expect(user.deleted_at).toBeNull();
    expect(user.version).toBe(1);
    expect(user.device_id).toBe(getDeviceId());
  });
});

describe('Sync Queue Operations', () => {
  beforeEach(() => {
    resetDatabase();
    initDb();
  });

  afterAll(() => {
    closeDb();
  });

  test('enqueueSync inserts a queue entry', () => {
    const localId = generateUUID();
    
    enqueueSync('users', localId, 'insert');

    const queue = getPendingQueue();
    expect(queue.length).toBe(1);
    expect(queue[0].table_name).toBe('users');
    expect(queue[0].local_id).toBe(localId);
    expect(queue[0].operation).toBe('insert');
    expect(queue[0].retry_count).toBe(0);
  });

  test('enqueueSync with payload stores JSON', () => {
    const localId = generateUUID();
    const payload = { phone_number: '+254712345678', name: 'Test' };
    
    enqueueSync('users', localId, 'insert', payload);

    const queue = getPendingQueue();
    expect(queue.length).toBe(1);
    expect(JSON.parse(queue[0].payload!)).toEqual(payload);
  });

  test('enqueueSync replaces existing entry for same record', () => {
    const localId = generateUUID();
    
    enqueueSync('users', localId, 'insert', { name: 'First' });
    enqueueSync('users', localId, 'insert', { name: 'Second' });

    const queue = getPendingQueue();
    expect(queue.length).toBe(1);
    expect(JSON.parse(queue[0].payload!).name).toBe('Second');
  });

  test('getPendingQueue respects limit', () => {
    for (let i = 0; i < 10; i++) {
      enqueueSync('users', generateUUID(), 'insert');
    }

    const queue = getPendingQueue(5);
    expect(queue.length).toBe(5);
  });

  test('getPendingQueue returns oldest first', () => {
    const id1 = generateUUID();
    const id2 = generateUUID();
    
    enqueueSync('users', id1, 'insert');
    enqueueSync('users', id2, 'insert');

    const queue = getPendingQueue();
    expect(queue[0].local_id).toBe(id1);
    expect(queue[1].local_id).toBe(id2);
  });
});

describe('Sync Status Updates', () => {
  beforeEach(() => {
    resetDatabase();
    initDb();
  });

  afterAll(() => {
    closeDb();
  });

  test('markSynced updates record and clears queue', () => {
    const db = getDatabase();
    const fields = createSyncFields();
    const now = getISOTimestamp();

    // Insert user
    db.prepare(`
      INSERT INTO users (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, phone_number, name, language, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      fields.local_id, fields.server_id, fields.sync_status, fields.updated_at,
      fields.deleted_at, fields.device_id, fields.version,
      '+254712345678', 'Test', 'en', now
    );

    // Queue it
    enqueueSync('users', fields.local_id, 'insert');
    expect(getPendingCount()).toBe(1);

    // Mark synced with server ID
    const serverId = 'server-uuid-123';
    markSynced('users', fields.local_id, serverId);

    // Check record updated
    const user = db.prepare('SELECT * FROM users WHERE local_id = ?').get(fields.local_id) as Record<string, unknown>;
    expect(user.sync_status).toBe('synced');
    expect(user.server_id).toBe(serverId);

    // Check queue cleared
    expect(getPendingCount()).toBe(0);
  });

  test('markFailed updates record and increments retry count', () => {
    const db = getDatabase();
    const fields = createSyncFields();
    const now = getISOTimestamp();

    // Insert user
    db.prepare(`
      INSERT INTO users (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, phone_number, name, language, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      fields.local_id, fields.server_id, fields.sync_status, fields.updated_at,
      fields.deleted_at, fields.device_id, fields.version,
      '+254712345678', 'Test', 'en', now
    );

    // Queue it
    enqueueSync('users', fields.local_id, 'insert');

    // Mark failed
    markFailed('users', fields.local_id, 'Network error');

    // Check record status
    const user = db.prepare('SELECT * FROM users WHERE local_id = ?').get(fields.local_id) as Record<string, unknown>;
    expect(user.sync_status).toBe('failed');

    // Check queue updated
    const queue = getPendingQueue();
    expect(queue[0].retry_count).toBe(1);
    expect(queue[0].last_error).toBe('Network error');
  });

  test('markFailed increments retry count on repeated failures', () => {
    const db = getDatabase();
    const fields = createSyncFields();
    const now = getISOTimestamp();

    db.prepare(`
      INSERT INTO users (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, phone_number, name, language, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      fields.local_id, fields.server_id, fields.sync_status, fields.updated_at,
      fields.deleted_at, fields.device_id, fields.version,
      '+254712345678', 'Test', 'en', now
    );

    enqueueSync('users', fields.local_id, 'insert');

    markFailed('users', fields.local_id, 'Error 1');
    markFailed('users', fields.local_id, 'Error 2');
    markFailed('users', fields.local_id, 'Error 3');

    const queue = getPendingQueue(50, 10); // Higher max retries to see the count
    expect(queue[0].retry_count).toBe(3);
    expect(queue[0].last_error).toBe('Error 3');
  });

  test('getPendingQueue excludes items over max retries', () => {
    const db = getDatabase();
    const fields = createSyncFields();
    const now = getISOTimestamp();

    db.prepare(`
      INSERT INTO users (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, phone_number, name, language, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      fields.local_id, fields.server_id, fields.sync_status, fields.updated_at,
      fields.deleted_at, fields.device_id, fields.version,
      '+254712345678', 'Test', 'en', now
    );

    enqueueSync('users', fields.local_id, 'insert');

    // Fail 5 times
    for (let i = 0; i < 5; i++) {
      markFailed('users', fields.local_id, `Error ${i}`);
    }

    // Default max retries is 5, so this should be excluded
    const queue = getPendingQueue();
    expect(queue.length).toBe(0);
  });
});

describe('Soft Delete (Tombstoning)', () => {
  beforeEach(() => {
    resetDatabase();
    initDb();
  });

  afterAll(() => {
    closeDb();
  });

  test('softDelete sets deleted_at timestamp', () => {
    const db = getDatabase();
    const fields = createSyncFields();
    const now = getISOTimestamp();

    db.prepare(`
      INSERT INTO users (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, phone_number, name, language, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      fields.local_id, fields.server_id, 'synced', fields.updated_at,
      fields.deleted_at, fields.device_id, fields.version,
      '+254712345678', 'Test', 'en', now
    );

    softDelete('users', fields.local_id);

    const user = db.prepare('SELECT * FROM users WHERE local_id = ?').get(fields.local_id) as Record<string, unknown>;
    expect(user.deleted_at).not.toBeNull();
    expect(user.sync_status).toBe('pending');
    expect(user.version).toBe(2); // Version incremented
  });

  test('softDelete enqueues delete operation', () => {
    const db = getDatabase();
    const fields = createSyncFields();
    const now = getISOTimestamp();

    db.prepare(`
      INSERT INTO users (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, phone_number, name, language, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      fields.local_id, fields.server_id, 'synced', fields.updated_at,
      fields.deleted_at, fields.device_id, fields.version,
      '+254712345678', 'Test', 'en', now
    );

    softDelete('users', fields.local_id);

    const queue = getPendingQueue();
    expect(queue.length).toBe(1);
    expect(queue[0].operation).toBe('delete');
    expect(queue[0].local_id).toBe(fields.local_id);
  });

  test('softDelete does not affect already deleted records', () => {
    const db = getDatabase();
    const fields = createSyncFields();
    const now = getISOTimestamp();
    const deletedAt = getISOTimestamp();

    // Insert already deleted user
    db.prepare(`
      INSERT INTO users (local_id, server_id, sync_status, updated_at, deleted_at, device_id, version, phone_number, name, language, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      fields.local_id, fields.server_id, 'synced', fields.updated_at,
      deletedAt, fields.device_id, 1,
      '+254712345678', 'Test', 'en', now
    );

    softDelete('users', fields.local_id);

    // Version should not change
    const user = db.prepare('SELECT * FROM users WHERE local_id = ?').get(fields.local_id) as Record<string, unknown>;
    expect(user.version).toBe(1);
  });
});

describe('UUID Generation', () => {
  test('generateUUID produces unique values', () => {
    const uuids = new Set<string>();
    
    for (let i = 0; i < 1000; i++) {
      uuids.add(generateUUID());
    }

    expect(uuids.size).toBe(1000);
  });

  test('generateUUID produces valid v4 format', () => {
    for (let i = 0; i < 100; i++) {
      const uuid = generateUUID();
      expect(uuid).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      );
    }
  });
});

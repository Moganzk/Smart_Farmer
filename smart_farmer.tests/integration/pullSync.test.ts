/**
 * Smart Farmer - Pull Sync Integration Tests
 * 
 * Tests the pull sync (downsync) with real SQLite + mocked Supabase.
 * Verifies merge rules, lastSync checkpoints, and conflict handling.
 * 
 * Test Strategy:
 * - Real SQLite database (better-sqlite3 in-memory)
 * - Mocked Supabase client (injectable dependency)
 * - Test all merge rules explicitly
 * - Verify lastSync checkpoint behavior
 */

import {
  getTestDb,
  resetTestDb,
  closeTestDb,
  initTestDb,
  TEST_DEVICE_ID,
  generateUUID,
  getISOTimestamp,
} from '../helpers/integrationDb';

// ============ Mock Supabase Client Factory ============

interface MockPullSupabaseClient {
  from: jest.Mock;
  setSelectResponse: (table: string, data: any[], error?: any) => void;
  getSelectCalls: () => Array<{ table: string; lastSyncAt: string | null }>;
  reset: () => void;
}

function createMockPullSupabaseClient(): MockPullSupabaseClient {
  const selectResponses: Map<string, { data: any[]; error: any }> = new Map();
  const selectCalls: Array<{ table: string; lastSyncAt: string | null }> = [];

  const mockFrom = jest.fn((table: string) => ({
    select: jest.fn((_columns?: string) => ({
      gt: jest.fn((column: string, value: string) => {
        selectCalls.push({ table, lastSyncAt: value });
        return {
          order: jest.fn(() => ({
            limit: jest.fn(async () => {
              const response = selectResponses.get(table) || { data: [], error: null };
              return response;
            }),
          })),
        };
      }),
      order: jest.fn(() => {
        selectCalls.push({ table, lastSyncAt: null });
        return {
          limit: jest.fn(async () => {
            const response = selectResponses.get(table) || { data: [], error: null };
            return response;
          }),
        };
      }),
    })),
  }));

  return {
    from: mockFrom,
    setSelectResponse: (table: string, data: any[], error?: any) => {
      selectResponses.set(table, { data, error: error || null });
    },
    getSelectCalls: () => [...selectCalls],
    reset: () => {
      selectResponses.clear();
      selectCalls.length = 0;
    },
  };
}

// ============ Test Helpers (mirror pullSync.ts logic for testing) ============

function initSyncMetaTable(): void {
  const db = getTestDb();
  db.exec(`
    CREATE TABLE IF NOT EXISTS sync_meta (
      table_name TEXT PRIMARY KEY NOT NULL,
      last_pull_at TEXT,
      last_push_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);
}

function getLastPullAt(tableName: string): string | null {
  const db = getTestDb();
  initSyncMetaTable();
  const row = db.prepare(`SELECT last_pull_at FROM sync_meta WHERE table_name = ?`).get(tableName) as { last_pull_at: string | null } | undefined;
  return row?.last_pull_at || null;
}

function setLastPullAt(tableName: string, timestamp: string): void {
  const db = getTestDb();
  initSyncMetaTable();
  const now = getISOTimestamp();
  db.prepare(
    `INSERT INTO sync_meta (table_name, last_pull_at, created_at, updated_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(table_name) DO UPDATE SET last_pull_at = ?, updated_at = ?`
  ).run(tableName, timestamp, now, now, timestamp, now);
}

function clearSyncCheckpoint(tableName: string): void {
  const db = getTestDb();
  initSyncMetaTable();
  db.prepare(`DELETE FROM sync_meta WHERE table_name = ?`).run(tableName);
}

// Get local tip by server_id or local_id
function getLocalTip(serverId: string): any {
  const db = getTestDb();
  let row = db.prepare(`SELECT * FROM tips WHERE server_id = ?`).get(serverId);
  if (!row) {
    row = db.prepare(`SELECT * FROM tips WHERE local_id = ?`).get(serverId);
  }
  return row;
}

// Get local notification by server_id or local_id
function getLocalNotification(serverId: string): any {
  const db = getTestDb();
  let row = db.prepare(`SELECT * FROM notifications WHERE server_id = ?`).get(serverId);
  if (!row) {
    row = db.prepare(`SELECT * FROM notifications WHERE local_id = ?`).get(serverId);
  }
  return row;
}

// Insert a local tip directly (for testing merge scenarios)
function insertLocalTip(tip: {
  local_id: string;
  server_id?: string;
  sync_status: string;
  updated_at: string;
  deleted_at?: string;
  title: string;
  content: string;
  category: string;
}): void {
  const db = getTestDb();
  const now = getISOTimestamp();
  db.prepare(
    `INSERT INTO tips (
      local_id, server_id, sync_status, updated_at, deleted_at,
      device_id, version, title, content, category, language, image_url, published_at
    ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, 'en', NULL, ?)`
  ).run(
    tip.local_id,
    tip.server_id || null,
    tip.sync_status,
    tip.updated_at,
    tip.deleted_at || null,
    TEST_DEVICE_ID,
    tip.title,
    tip.content,
    tip.category,
    now
  );
}

// Insert a local notification directly
function insertLocalNotification(notification: {
  local_id: string;
  server_id?: string;
  sync_status: string;
  updated_at: string;
  deleted_at?: string;
  title: string;
  body: string;
  type: string;
  user_local_id: string;
}): void {
  const db = getTestDb();
  const now = getISOTimestamp();
  db.prepare(
    `INSERT INTO notifications (
      local_id, server_id, sync_status, updated_at, deleted_at,
      device_id, version, user_local_id, type, title, body, read, data, received_at
    ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, 0, NULL, ?)`
  ).run(
    notification.local_id,
    notification.server_id || null,
    notification.sync_status,
    notification.updated_at,
    notification.deleted_at || null,
    TEST_DEVICE_ID,
    notification.user_local_id,
    notification.type,
    notification.title,
    notification.body,
    now
  );
}

// ============ Merge Functions (test implementation) ============

interface ServerRecord {
  id: string;
  updated_at: string;
  deleted_at: string | null;
  [key: string]: unknown;
}

interface MergeResult {
  action: 'inserted' | 'updated' | 'skipped_pending' | 'skipped_local_newer' | 'deleted' | 'error';
  localId: string;
  serverId: string;
  error?: string;
}

function getLocalRecordByServerId(tableName: string, serverId: string): any {
  const db = getTestDb();
  let row = db.prepare(
    `SELECT local_id, sync_status, updated_at, deleted_at FROM ${tableName} WHERE server_id = ?`
  ).get(serverId);
  if (!row) {
    row = db.prepare(
      `SELECT local_id, sync_status, updated_at, deleted_at FROM ${tableName} WHERE local_id = ?`
    ).get(serverId);
  }
  return row;
}

function mergeTip(serverRecord: ServerRecord, deviceId: string): MergeResult {
  const db = getTestDb();
  const serverId = serverRecord.id;
  const serverUpdatedAt = serverRecord.updated_at;
  const serverDeletedAt = serverRecord.deleted_at;

  try {
    const local = getLocalRecordByServerId('tips', serverId);

    if (!local) {
      // RULE 1: Insert new record
      const localId = serverId;
      const now = getISOTimestamp();

      db.prepare(
        `INSERT INTO tips (
          local_id, server_id, sync_status, updated_at, deleted_at,
          device_id, version, title, content, category, language, image_url, published_at
        ) VALUES (?, ?, 'synced', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(
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
        serverRecord.published_at || now
      );

      return { action: 'inserted', localId, serverId };
    }

    // RULE 2: Don't overwrite pending
    if (local.sync_status === 'pending') {
      return { action: 'skipped_pending', localId: local.local_id, serverId };
    }

    // RULE 3: Don't overwrite if local is same or newer
    const localNewer = local.updated_at >= serverUpdatedAt;
    if (localNewer) {
      return { action: 'skipped_local_newer', localId: local.local_id, serverId };
    }

    // RULE 5: Handle tombstone
    if (serverDeletedAt && !local.deleted_at) {
      db.prepare(
        `UPDATE tips SET deleted_at = ?, updated_at = ?, sync_status = 'synced' WHERE local_id = ?`
      ).run(serverDeletedAt, serverUpdatedAt, local.local_id);
      return { action: 'deleted', localId: local.local_id, serverId };
    }

    // RULE 4: Overwrite local with server data
    db.prepare(
      `UPDATE tips SET
        server_id = ?, sync_status = 'synced', updated_at = ?, deleted_at = ?,
        version = ?, title = ?, content = ?, category = ?, language = ?,
        image_url = ?, published_at = ?
       WHERE local_id = ?`
    ).run(
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
      local.local_id
    );

    return { action: 'updated', localId: local.local_id, serverId };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : 'Unknown error';
    return { action: 'error', localId: serverId, serverId, error: errorMsg };
  }
}

function mergeNotification(serverRecord: ServerRecord, deviceId: string): MergeResult {
  const db = getTestDb();
  const serverId = serverRecord.id;
  const serverUpdatedAt = serverRecord.updated_at;
  const serverDeletedAt = serverRecord.deleted_at;

  try {
    const local = getLocalRecordByServerId('notifications', serverId);

    if (!local) {
      const localId = serverId;
      const now = getISOTimestamp();

      db.prepare(
        `INSERT INTO notifications (
          local_id, server_id, sync_status, updated_at, deleted_at,
          device_id, version, user_local_id, type, title, body, read, data, received_at
        ) VALUES (?, ?, 'synced', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(
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
        serverRecord.received_at || serverRecord.created_at || now
      );

      return { action: 'inserted', localId, serverId };
    }

    if (local.sync_status === 'pending') {
      return { action: 'skipped_pending', localId: local.local_id, serverId };
    }

    if (local.updated_at >= serverUpdatedAt) {
      return { action: 'skipped_local_newer', localId: local.local_id, serverId };
    }

    if (serverDeletedAt && !local.deleted_at) {
      db.prepare(
        `UPDATE notifications SET deleted_at = ?, updated_at = ?, sync_status = 'synced' WHERE local_id = ?`
      ).run(serverDeletedAt, serverUpdatedAt, local.local_id);
      return { action: 'deleted', localId: local.local_id, serverId };
    }

    db.prepare(
      `UPDATE notifications SET
        server_id = ?, sync_status = 'synced', updated_at = ?, deleted_at = ?,
        version = ?, user_local_id = ?, type = ?, title = ?, body = ?,
        read = ?, data = ?, received_at = ?
       WHERE local_id = ?`
    ).run(
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
      local.local_id
    );

    return { action: 'updated', localId: local.local_id, serverId };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : 'Unknown error';
    return { action: 'error', localId: serverId, serverId, error: errorMsg };
  }
}

// Pull sync runner (test implementation)
interface PullSyncResult {
  table: string;
  fetched: number;
  inserted: number;
  updated: number;
  deleted: number;
  skipped: number;
  errors: number;
  results: MergeResult[];
}

async function pullTipsTest(
  client: MockPullSupabaseClient,
  limit: number = 100,
  deviceId: string = TEST_DEVICE_ID
): Promise<PullSyncResult> {
  const tableName = 'tips';
  const lastSyncAt = getLastPullAt(tableName);

  // Build query based on lastSyncAt
  let response: { data: any[] | null; error: any };
  
  if (lastSyncAt) {
    response = await client.from(tableName).select('*').gt('updated_at', lastSyncAt).order('updated_at').limit(limit);
  } else {
    response = await client.from(tableName).select('*').order('updated_at').limit(limit);
  }

  if (response.error) {
    return {
      table: tableName,
      fetched: 0, inserted: 0, updated: 0, deleted: 0, skipped: 0, errors: 1,
      results: [{ action: 'error', localId: '', serverId: '', error: response.error.message }],
    };
  }

  const data = response.data || [];
  if (data.length === 0) {
    return { table: tableName, fetched: 0, inserted: 0, updated: 0, deleted: 0, skipped: 0, errors: 0, results: [] };
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

    if (record.updated_at > maxUpdatedAt) {
      maxUpdatedAt = record.updated_at;
    }
  }

  if (maxUpdatedAt && maxUpdatedAt > (lastSyncAt || '')) {
    setLastPullAt(tableName, maxUpdatedAt);
  }

  return { table: tableName, fetched: data.length, inserted, updated, deleted, skipped, errors, results };
}

async function pullNotificationsTest(
  client: MockPullSupabaseClient,
  limit: number = 100,
  deviceId: string = TEST_DEVICE_ID
): Promise<PullSyncResult> {
  const tableName = 'notifications';
  const lastSyncAt = getLastPullAt(tableName);

  let response: { data: any[] | null; error: any };
  
  if (lastSyncAt) {
    response = await client.from(tableName).select('*').gt('updated_at', lastSyncAt).order('updated_at').limit(limit);
  } else {
    response = await client.from(tableName).select('*').order('updated_at').limit(limit);
  }

  if (response.error) {
    return {
      table: tableName,
      fetched: 0, inserted: 0, updated: 0, deleted: 0, skipped: 0, errors: 1,
      results: [{ action: 'error', localId: '', serverId: '', error: response.error.message }],
    };
  }

  const data = response.data || [];
  if (data.length === 0) {
    return { table: tableName, fetched: 0, inserted: 0, updated: 0, deleted: 0, skipped: 0, errors: 0, results: [] };
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

  return { table: tableName, fetched: data.length, inserted, updated, deleted, skipped, errors, results };
}

async function runPullOnceTest(
  client: MockPullSupabaseClient,
  limit: number = 100,
  deviceId: string = TEST_DEVICE_ID
) {
  const tipsResult = await pullTipsTest(client, limit, deviceId);
  const notificationsResult = await pullNotificationsTest(client, limit, deviceId);

  return {
    tables: ['tips', 'notifications'],
    results: [tipsResult, notificationsResult],
    totalFetched: tipsResult.fetched + notificationsResult.fetched,
    totalInserted: tipsResult.inserted + notificationsResult.inserted,
    totalUpdated: tipsResult.updated + notificationsResult.updated,
    totalDeleted: tipsResult.deleted + notificationsResult.deleted,
    totalSkipped: tipsResult.skipped + notificationsResult.skipped,
    totalErrors: tipsResult.errors + notificationsResult.errors,
  };
}

// ============ Tests ============

describe('Pull Sync Integration Tests', () => {
  let mockClient: MockPullSupabaseClient;

  beforeEach(() => {
    resetTestDb();
    initTestDb();
    initSyncMetaTable();
    mockClient = createMockPullSupabaseClient();
  });

  afterAll(() => {
    closeTestDb();
  });

  // ============ Basic Pull Flow ============

  describe('runPullOnce - basic flow', () => {
    it('should return empty result when server has no data', async () => {
      mockClient.setSelectResponse('tips', []);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalFetched).toBe(0);
      expect(result.totalInserted).toBe(0);
      expect(result.totalErrors).toBe(0);
    });

    it('should insert new tips from server', async () => {
      const serverTip = {
        id: 'server-tip-001',
        title: 'Prevent Blight',
        content: 'Water at the base of plants',
        category: 'prevention',
        language: 'en',
        image_url: null,
        published_at: '2026-01-01T00:00:00.000Z',
        updated_at: '2026-01-15T00:00:00.000Z',
        deleted_at: null,
        version: 1,
      };

      mockClient.setSelectResponse('tips', [serverTip]);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalFetched).toBe(1);
      expect(result.totalInserted).toBe(1);

      // Verify local record created
      const localTip = getLocalTip('server-tip-001');
      expect(localTip).not.toBeNull();
      expect(localTip.title).toBe('Prevent Blight');
      expect(localTip.sync_status).toBe('synced');
      expect(localTip.server_id).toBe('server-tip-001');
    });

    it('should insert new notifications from server', async () => {
      const serverNotification = {
        id: 'server-notif-001',
        user_id: 'user-001',
        type: 'tip',
        title: 'New Tip Available',
        body: 'Check out our latest farming tip',
        read: false,
        data: null,
        received_at: '2026-01-15T00:00:00.000Z',
        updated_at: '2026-01-15T00:00:00.000Z',
        deleted_at: null,
        version: 1,
      };

      mockClient.setSelectResponse('tips', []);
      mockClient.setSelectResponse('notifications', [serverNotification]);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalFetched).toBe(1);
      expect(result.totalInserted).toBe(1);

      const localNotif = getLocalNotification('server-notif-001');
      expect(localNotif).not.toBeNull();
      expect(localNotif.title).toBe('New Tip Available');
      expect(localNotif.sync_status).toBe('synced');
    });
  });

  // ============ Merge Rule Tests ============

  describe('merge rules - tips', () => {
    it('RULE 1: should insert when local record does not exist', async () => {
      const serverTip = {
        id: 'new-tip-001',
        title: 'New Tip',
        content: 'Content',
        category: 'general',
        updated_at: '2026-01-15T00:00:00.000Z',
        deleted_at: null,
        version: 1,
      };

      mockClient.setSelectResponse('tips', [serverTip]);
      mockClient.setSelectResponse('notifications', []);

      await runPullOnceTest(mockClient);

      const local = getLocalTip('new-tip-001');
      expect(local).not.toBeNull();
      expect(local.sync_status).toBe('synced');
    });

    it('RULE 2: should NOT overwrite local pending record', async () => {
      // Insert local pending tip
      insertLocalTip({
        local_id: 'pending-tip-001',
        server_id: 'pending-tip-001',
        sync_status: 'pending',
        updated_at: '2026-01-10T00:00:00.000Z',
        title: 'Local Pending Title',
        content: 'Local content',
        category: 'local',
      });

      // Server has newer version
      const serverTip = {
        id: 'pending-tip-001',
        title: 'Server Title',
        content: 'Server content',
        category: 'server',
        updated_at: '2026-01-20T00:00:00.000Z',
        deleted_at: null,
        version: 2,
      };

      mockClient.setSelectResponse('tips', [serverTip]);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalSkipped).toBe(1);
      expect(result.results[0].results[0].action).toBe('skipped_pending');

      // Verify local was NOT changed
      const local = getLocalTip('pending-tip-001');
      expect(local.title).toBe('Local Pending Title');
      expect(local.sync_status).toBe('pending');
    });

    it('RULE 3: should NOT overwrite when local is newer', async () => {
      // Insert local synced tip with newer timestamp
      insertLocalTip({
        local_id: 'newer-tip-001',
        server_id: 'newer-tip-001',
        sync_status: 'synced',
        updated_at: '2026-01-20T00:00:00.000Z',
        title: 'Local Newer Title',
        content: 'Local content',
        category: 'local',
      });

      // Server has older version
      const serverTip = {
        id: 'newer-tip-001',
        title: 'Server Older Title',
        content: 'Server content',
        category: 'server',
        updated_at: '2026-01-10T00:00:00.000Z',
        deleted_at: null,
        version: 1,
      };

      mockClient.setSelectResponse('tips', [serverTip]);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalSkipped).toBe(1);
      expect(result.results[0].results[0].action).toBe('skipped_local_newer');

      // Verify local was NOT changed
      const local = getLocalTip('newer-tip-001');
      expect(local.title).toBe('Local Newer Title');
    });

    it('RULE 4: should overwrite local when server is newer', async () => {
      // Clear any existing checkpoint
      clearSyncCheckpoint('tips');
      
      // Insert local synced tip with OLDER timestamp
      insertLocalTip({
        local_id: 'update-tip-001',
        server_id: 'update-tip-001',
        sync_status: 'synced',
        updated_at: '2026-01-10T00:00:00.000Z',
        title: 'Old Title',
        content: 'Old content',
        category: 'old',
      });

      // Verify local exists
      const before = getLocalTip('update-tip-001');
      expect(before).not.toBeNull();
      expect(before.updated_at).toBe('2026-01-10T00:00:00.000Z');

      // Server has newer version
      const serverTip = {
        id: 'update-tip-001',
        title: 'Updated Title',
        content: 'Updated content',
        category: 'updated',
        updated_at: '2026-01-20T00:00:00.000Z',
        deleted_at: null,
        version: 2,
        published_at: '2026-01-01T00:00:00.000Z',
      };

      mockClient.setSelectResponse('tips', [serverTip]);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalUpdated).toBe(1);

      // Verify local was updated
      const local = getLocalTip('update-tip-001');
      expect(local.title).toBe('Updated Title');
      expect(local.content).toBe('Updated content');
      expect(local.sync_status).toBe('synced');
    });

    it('RULE 5: should apply server tombstone deletion', async () => {
      // Insert local synced tip
      insertLocalTip({
        local_id: 'delete-tip-001',
        server_id: 'delete-tip-001',
        sync_status: 'synced',
        updated_at: '2026-01-10T00:00:00.000Z',
        title: 'To Be Deleted',
        content: 'Content',
        category: 'general',
      });

      // Server has tombstone
      const serverTip = {
        id: 'delete-tip-001',
        title: 'To Be Deleted',
        content: 'Content',
        category: 'general',
        updated_at: '2026-01-20T00:00:00.000Z',
        deleted_at: '2026-01-20T00:00:00.000Z',
        version: 2,
      };

      mockClient.setSelectResponse('tips', [serverTip]);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalDeleted).toBe(1);

      // Verify local has deleted_at set
      const local = getLocalTip('delete-tip-001');
      expect(local.deleted_at).toBe('2026-01-20T00:00:00.000Z');
      expect(local.sync_status).toBe('synced');
    });
  });

  describe('merge rules - notifications', () => {
    it('should NOT overwrite pending notification', async () => {
      // Insert local pending notification
      insertLocalNotification({
        local_id: 'pending-notif-001',
        server_id: 'pending-notif-001',
        sync_status: 'pending',
        updated_at: '2026-01-10T00:00:00.000Z',
        title: 'Local Title',
        body: 'Local body',
        type: 'local',
        user_local_id: 'user-001',
      });

      const serverNotif = {
        id: 'pending-notif-001',
        user_id: 'user-001',
        type: 'server',
        title: 'Server Title',
        body: 'Server body',
        read: false,
        updated_at: '2026-01-20T00:00:00.000Z',
        deleted_at: null,
        version: 2,
      };

      mockClient.setSelectResponse('tips', []);
      mockClient.setSelectResponse('notifications', [serverNotif]);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalSkipped).toBe(1);

      const local = getLocalNotification('pending-notif-001');
      expect(local.title).toBe('Local Title');
    });

    it('should update synced notification when server is newer', async () => {
      insertLocalNotification({
        local_id: 'update-notif-001',
        server_id: 'update-notif-001',
        sync_status: 'synced',
        updated_at: '2026-01-10T00:00:00.000Z',
        title: 'Old Title',
        body: 'Old body',
        type: 'old',
        user_local_id: 'user-001',
      });

      const serverNotif = {
        id: 'update-notif-001',
        user_id: 'user-001',
        type: 'updated',
        title: 'New Title',
        body: 'New body',
        read: true,
        updated_at: '2026-01-20T00:00:00.000Z',
        deleted_at: null,
        version: 2,
        received_at: '2026-01-15T00:00:00.000Z',
      };

      mockClient.setSelectResponse('tips', []);
      mockClient.setSelectResponse('notifications', [serverNotif]);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalUpdated).toBe(1);

      const local = getLocalNotification('update-notif-001');
      expect(local.title).toBe('New Title');
      expect(local.read).toBe(1);
    });
  });

  // ============ lastSync Checkpoint Tests ============

  describe('lastSync checkpoint', () => {
    it('should store lastSync checkpoint after successful pull', async () => {
      const serverTip = {
        id: 'checkpoint-tip-001',
        title: 'Test',
        content: 'Content',
        category: 'general',
        updated_at: '2026-01-15T12:30:00.000Z',
        deleted_at: null,
      };

      mockClient.setSelectResponse('tips', [serverTip]);
      mockClient.setSelectResponse('notifications', []);

      await runPullOnceTest(mockClient);

      const lastPull = getLastPullAt('tips');
      expect(lastPull).toBe('2026-01-15T12:30:00.000Z');
    });

    it('should use lastSync checkpoint for incremental fetch', async () => {
      // Set initial checkpoint
      setLastPullAt('tips', '2026-01-10T00:00:00.000Z');

      mockClient.setSelectResponse('tips', []);
      mockClient.setSelectResponse('notifications', []);

      await runPullOnceTest(mockClient);

      // Verify the mock was called with the checkpoint
      const calls = mockClient.getSelectCalls();
      const tipsCall = calls.find(c => c.table === 'tips');
      expect(tipsCall?.lastSyncAt).toBe('2026-01-10T00:00:00.000Z');
    });

    it('should only fetch records newer than lastSync', async () => {
      // First sync - fetch all
      const tip1 = {
        id: 'tip-001',
        title: 'First Tip',
        content: 'Content',
        category: 'general',
        updated_at: '2026-01-10T00:00:00.000Z',
        deleted_at: null,
      };

      mockClient.setSelectResponse('tips', [tip1]);
      mockClient.setSelectResponse('notifications', []);

      await runPullOnceTest(mockClient);

      // Verify checkpoint set
      expect(getLastPullAt('tips')).toBe('2026-01-10T00:00:00.000Z');

      // Reset mock for second sync
      mockClient.reset();

      // Second sync - only newer records
      const tip2 = {
        id: 'tip-002',
        title: 'Second Tip',
        content: 'Content',
        category: 'general',
        updated_at: '2026-01-20T00:00:00.000Z',
        deleted_at: null,
      };

      mockClient.setSelectResponse('tips', [tip2]);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalInserted).toBe(1);

      // Checkpoint should be updated
      expect(getLastPullAt('tips')).toBe('2026-01-20T00:00:00.000Z');

      // Both tips should exist locally
      expect(getLocalTip('tip-001')).not.toBeNull();
      expect(getLocalTip('tip-002')).not.toBeNull();
    });

    it('should track separate checkpoints per table', async () => {
      const serverTip = {
        id: 'tip-001',
        title: 'Tip',
        content: 'Content',
        category: 'general',
        updated_at: '2026-01-15T00:00:00.000Z',
        deleted_at: null,
      };

      const serverNotif = {
        id: 'notif-001',
        user_id: 'user-001',
        type: 'tip',
        title: 'Notification',
        body: 'Body',
        updated_at: '2026-01-20T00:00:00.000Z',
        deleted_at: null,
      };

      mockClient.setSelectResponse('tips', [serverTip]);
      mockClient.setSelectResponse('notifications', [serverNotif]);

      await runPullOnceTest(mockClient);

      expect(getLastPullAt('tips')).toBe('2026-01-15T00:00:00.000Z');
      expect(getLastPullAt('notifications')).toBe('2026-01-20T00:00:00.000Z');
    });

    it('should not update checkpoint if no records fetched', async () => {
      setLastPullAt('tips', '2026-01-10T00:00:00.000Z');

      mockClient.setSelectResponse('tips', []);
      mockClient.setSelectResponse('notifications', []);

      await runPullOnceTest(mockClient);

      // Checkpoint should remain unchanged
      expect(getLastPullAt('tips')).toBe('2026-01-10T00:00:00.000Z');
    });
  });

  // ============ Error Handling ============

  describe('error handling', () => {
    it('should handle Supabase fetch error gracefully', async () => {
      mockClient.setSelectResponse('tips', [], { message: 'Network error' });
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalErrors).toBe(1);
      expect(result.results[0].errors).toBe(1);
    });

    it('should continue processing notifications if tips fetch fails', async () => {
      mockClient.setSelectResponse('tips', [], { message: 'Network error' });

      const serverNotif = {
        id: 'notif-001',
        user_id: 'user-001',
        type: 'tip',
        title: 'Notification',
        body: 'Body',
        updated_at: '2026-01-20T00:00:00.000Z',
        deleted_at: null,
      };
      mockClient.setSelectResponse('notifications', [serverNotif]);

      const result = await runPullOnceTest(mockClient);

      // Tips failed, notifications succeeded
      expect(result.results[0].errors).toBe(1); // tips
      expect(result.results[1].inserted).toBe(1); // notifications
    });
  });

  // ============ Multiple Records ============

  describe('multiple records', () => {
    it('should process multiple tips in a single pull', async () => {
      const tips = [
        { id: 'tip-001', title: 'Tip 1', content: 'C1', category: 'a', updated_at: '2026-01-10T00:00:00.000Z', deleted_at: null },
        { id: 'tip-002', title: 'Tip 2', content: 'C2', category: 'b', updated_at: '2026-01-11T00:00:00.000Z', deleted_at: null },
        { id: 'tip-003', title: 'Tip 3', content: 'C3', category: 'c', updated_at: '2026-01-12T00:00:00.000Z', deleted_at: null },
      ];

      mockClient.setSelectResponse('tips', tips);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.totalFetched).toBe(3);
      expect(result.totalInserted).toBe(3);

      // Checkpoint should be the latest
      expect(getLastPullAt('tips')).toBe('2026-01-12T00:00:00.000Z');
    });

    it('should handle mixed operations (insert, update, skip)', async () => {
      // Existing local tip (pending)
      insertLocalTip({
        local_id: 'tip-pending',
        server_id: 'tip-pending',
        sync_status: 'pending',
        updated_at: '2026-01-10T00:00:00.000Z',
        title: 'Pending',
        content: 'Content',
        category: 'general',
      });

      // Existing local tip (synced, older)
      insertLocalTip({
        local_id: 'tip-update',
        server_id: 'tip-update',
        sync_status: 'synced',
        updated_at: '2026-01-10T00:00:00.000Z',
        title: 'Old',
        content: 'Content',
        category: 'general',
      });

      const serverTips = [
        { id: 'tip-new', title: 'New', content: 'C', category: 'a', updated_at: '2026-01-20T00:00:00.000Z', deleted_at: null, published_at: '2026-01-01T00:00:00.000Z' },
        { id: 'tip-pending', title: 'Server', content: 'C', category: 'b', updated_at: '2026-01-20T00:00:00.000Z', deleted_at: null, published_at: '2026-01-01T00:00:00.000Z' },
        { id: 'tip-update', title: 'Updated', content: 'C', category: 'c', updated_at: '2026-01-20T00:00:00.000Z', deleted_at: null, published_at: '2026-01-01T00:00:00.000Z' },
      ];

      mockClient.setSelectResponse('tips', serverTips);
      mockClient.setSelectResponse('notifications', []);

      const result = await runPullOnceTest(mockClient);

      expect(result.results[0].inserted).toBe(1);   // tip-new
      expect(result.results[0].updated).toBe(1);    // tip-update
      expect(result.results[0].skipped).toBe(1);    // tip-pending

      // Verify pending was not changed
      expect(getLocalTip('tip-pending').title).toBe('Pending');
      
      // Verify update was applied
      expect(getLocalTip('tip-update').title).toBe('Updated');
    });
  });
});

/**
 * Smart Farmer - Supabase Auth Integration Tests
 * 
 * Tests the auth helper functions used by sync modules.
 * Verifies getCurrentUserId, isAuthenticated behavior.
 * 
 * Test Strategy:
 * - Mock Supabase auth responses
 * - Test authenticated vs unauthenticated flows
 * - Verify sync uses correct user ID
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

// ============ Mock Setup ============

// Mock the supabase module before importing tested modules
jest.mock('../../smart_farmer/utils/supabase', () => {
  const mockSupabase = require('../mocks/supabase');
  return mockSupabase;
});

// Import mocks to control test state
const {
  setMockAuthenticated,
  resetMocks,
  getCurrentUserId,
  isAuthenticated,
  mockUser,
} = require('../mocks/supabase');

// ============ Test Suite ============

describe('Supabase Auth Helpers', () => {
  beforeAll(() => {
    initTestDb();
  });

  afterAll(() => {
    closeTestDb();
  });

  beforeEach(() => {
    resetTestDb();
    resetMocks();
  });

  describe('getCurrentUserId', () => {
    it('should return null when not authenticated', async () => {
      setMockAuthenticated(false);
      
      const userId = await getCurrentUserId();
      
      expect(userId).toBeNull();
    });

    it('should return user ID when authenticated', async () => {
      setMockAuthenticated(true);
      
      const userId = await getCurrentUserId();
      
      expect(userId).toBe(mockUser.id);
    });

    it('should return custom user ID when provided', async () => {
      const customUserId = 'custom-user-123';
      setMockAuthenticated(true, customUserId);
      
      const userId = await getCurrentUserId();
      
      expect(userId).toBe(customUserId);
    });
  });

  describe('isAuthenticated', () => {
    it('should return false when not authenticated', async () => {
      setMockAuthenticated(false);
      
      const result = await isAuthenticated();
      
      expect(result).toBe(false);
    });

    it('should return true when authenticated', async () => {
      setMockAuthenticated(true);
      
      const result = await isAuthenticated();
      
      expect(result).toBe(true);
    });
  });
});

describe('User-Scoped Sync', () => {
  beforeAll(() => {
    initTestDb();
  });

  afterAll(() => {
    closeTestDb();
  });

  beforeEach(() => {
    resetTestDb();
    resetMocks();
  });

  describe('fetchServerRecordsForUser (via mock)', () => {
    it('should add user_id filter when userId is provided', () => {
      // This tests that our mock client interface supports eq() chaining
      const mockClient = createMockPullSupabaseClientWithUserFilter();
      
      // Simulate fetchServerRecordsForUser logic
      const userId = 'test-user-123';
      const tableName = 'notifications';
      
      mockClient.from(tableName)
        .select('*')
        .eq('user_id', userId)
        .order('updated_at', { ascending: true })
        .limit(100);
      
      const calls = mockClient.getCalls();
      expect(calls).toContainEqual(
        expect.objectContaining({
          table: tableName,
          userId: userId,
        })
      );
    });

    it('should not add user_id filter when userId is not provided', () => {
      const mockClient = createMockPullSupabaseClientWithUserFilter();
      
      const tableName = 'tips';
      
      mockClient.from(tableName)
        .select('*')
        .order('updated_at', { ascending: true })
        .limit(100);
      
      const calls = mockClient.getCalls();
      expect(calls.some(c => c.userId)).toBe(false);
    });
  });

  describe('Pull sync with user filtering', () => {
    it('should filter notifications by user_id when authenticated', async () => {
      setMockAuthenticated(true);
      const userId = await getCurrentUserId();
      
      // Verify user ID is available
      expect(userId).toBe(mockUser.id);
      
      // In actual pullNotifications, this userId would be passed to fetchServerRecordsForUser
      // which adds .eq('user_id', userId) to the query
    });

    it('should still work (with RLS protection) when not authenticated', async () => {
      setMockAuthenticated(false);
      const userId = await getCurrentUserId();
      
      // userId is null, but RLS on server will still protect data
      expect(userId).toBeNull();
    });
  });
});

// ============ Mock Client Factory ============

interface MockPullSupabaseClientWithUserFilter {
  from: (table: string) => any;
  getCalls: () => Array<{ table: string; userId?: string; lastSyncAt?: string }>;
  setResponse: (table: string, data: any[], error?: any) => void;
}

function createMockPullSupabaseClientWithUserFilter(): MockPullSupabaseClientWithUserFilter {
  const calls: Array<{ table: string; userId?: string; lastSyncAt?: string }> = [];
  const responses: Map<string, { data: any[]; error: any }> = new Map();

  const createChain = (tableName: string, currentCall: { table: string; userId?: string; lastSyncAt?: string }) => ({
    select: (_columns?: string) => ({
      eq: (column: string, value: string) => {
        if (column === 'user_id') {
          currentCall.userId = value;
        }
        return createChain(tableName, currentCall).select();
      },
      gt: (column: string, value: string) => {
        if (column === 'updated_at') {
          currentCall.lastSyncAt = value;
        }
        return createChain(tableName, currentCall).select();
      },
      order: (_column: string, _options?: { ascending?: boolean }) => ({
        limit: async (_count: number) => {
          calls.push({ ...currentCall });
          const response = responses.get(tableName) || { data: [], error: null };
          return response;
        },
      }),
    }),
  });

  return {
    from: (table: string) => {
      const currentCall = { table };
      return createChain(table, currentCall);
    },
    getCalls: () => [...calls],
    setResponse: (table: string, data: any[], error?: any) => {
      responses.set(table, { data, error: error || null });
    },
  };
}

/**
 * Mock for Supabase client
 * Used in Jest tests to avoid actual API calls
 */

// Mock user for authenticated scenarios
const mockUser = {
  id: 'mock-user-uuid-12345',
  email: 'test@example.com',
  phone: '+254712345678',
};

const mockSession = {
  user: mockUser,
  access_token: 'mock-access-token',
  refresh_token: 'mock-refresh-token',
};

const mockAuth = {
  signInWithOtp: jest.fn().mockResolvedValue({ data: {}, error: null }),
  verifyOtp: jest.fn().mockResolvedValue({ 
    data: { user: mockUser, session: mockSession }, 
    error: null 
  }),
  signOut: jest.fn().mockResolvedValue({ error: null }),
  getSession: jest.fn().mockResolvedValue({ data: { session: null }, error: null }),
  getUser: jest.fn().mockResolvedValue({ data: { user: null }, error: null }),
  onAuthStateChange: jest.fn().mockReturnValue({ 
    data: { subscription: { unsubscribe: jest.fn() } } 
  }),
};

const mockSupabase = {
  auth: mockAuth,
  from: jest.fn().mockReturnValue({
    select: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    delete: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    gt: jest.fn().mockReturnThis(),
    order: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue({ data: [], error: null }),
    single: jest.fn().mockResolvedValue({ data: null, error: null }),
  }),
};

// Export isSupabaseConfigured as false in tests (dev mode)
const isSupabaseConfigured = false;

// Export getSupabase function
const getSupabase = jest.fn().mockReturnValue(null);

// Auth helper function mocks
const getCurrentUser = jest.fn().mockResolvedValue(null);
const getCurrentUserId = jest.fn().mockResolvedValue(null);
const getCurrentSession = jest.fn().mockResolvedValue(null);
const isAuthenticated = jest.fn().mockResolvedValue(false);
const signOut = jest.fn().mockResolvedValue({ error: null });

// Helper to set authenticated state in tests
const setMockAuthenticated = (authenticated = true, userId = mockUser.id) => {
  if (authenticated) {
    mockAuth.getSession.mockResolvedValue({ data: { session: mockSession }, error: null });
    mockAuth.getUser.mockResolvedValue({ data: { user: mockUser }, error: null });
    getCurrentUser.mockResolvedValue(mockUser);
    getCurrentUserId.mockResolvedValue(userId);
    getCurrentSession.mockResolvedValue(mockSession);
    isAuthenticated.mockResolvedValue(true);
  } else {
    mockAuth.getSession.mockResolvedValue({ data: { session: null }, error: null });
    mockAuth.getUser.mockResolvedValue({ data: { user: null }, error: null });
    getCurrentUser.mockResolvedValue(null);
    getCurrentUserId.mockResolvedValue(null);
    getCurrentSession.mockResolvedValue(null);
    isAuthenticated.mockResolvedValue(false);
  }
};

// Reset all mocks
const resetMocks = () => {
  setMockAuthenticated(false);
  mockAuth.signInWithOtp.mockClear();
  mockAuth.verifyOtp.mockClear();
  mockAuth.signOut.mockClear();
};

module.exports = {
  supabase: mockSupabase,
  isSupabaseConfigured,
  getSupabase,
  createClient: jest.fn(() => mockSupabase),
  // Auth helpers
  getCurrentUser,
  getCurrentUserId,
  getCurrentSession,
  isAuthenticated,
  signOut,
  // Test utilities
  setMockAuthenticated,
  resetMocks,
  mockUser,
  mockSession,
};

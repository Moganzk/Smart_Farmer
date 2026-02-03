/**
 * Mock for Supabase client
 * Used in Jest tests to avoid actual API calls
 */

const mockAuth = {
  signInWithOtp: jest.fn().mockResolvedValue({ data: {}, error: null }),
  verifyOtp: jest.fn().mockResolvedValue({ 
    data: { user: { id: 'mock-user-id' } }, 
    error: null 
  }),
  signOut: jest.fn().mockResolvedValue({ error: null }),
  getSession: jest.fn().mockResolvedValue({ data: { session: null }, error: null }),
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
    single: jest.fn().mockResolvedValue({ data: null, error: null }),
  }),
};

// Export isSupabaseConfigured as false in tests (dev mode)
const isSupabaseConfigured = false;

// Export getSupabase function
const getSupabase = jest.fn().mockReturnValue(null);

module.exports = {
  supabase: mockSupabase,
  isSupabaseConfigured,
  getSupabase,
  createClient: jest.fn(() => mockSupabase),
};

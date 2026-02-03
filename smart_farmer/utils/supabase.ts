
import 'react-native-url-polyfill/auto'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { createClient, SupabaseClient, User, Session } from '@supabase/supabase-js'
import { logger } from './logger'

// Environment variables with fallback for builds without EAS env vars
const SUPABASE_URL = process.env.EXPO_PUBLIC_SUPABASE_URL || ''
const SUPABASE_KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || process.env.EXPO_PUBLIC_SUPABASE_KEY || ''

// Flag to track if Supabase is properly configured
export const isSupabaseConfigured = Boolean(SUPABASE_URL && SUPABASE_KEY)

// Create a safe Supabase client that won't crash if env vars are missing
let _supabase: SupabaseClient | null = null

export function getSupabase(): SupabaseClient | null {
  if (!isSupabaseConfigured) {
    logger.warn('Supabase not configured - missing EXPO_PUBLIC_SUPABASE_URL or EXPO_PUBLIC_SUPABASE_ANON_KEY')
    return null
  }
  
  if (!_supabase) {
    _supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
      auth: {
        storage: AsyncStorage,
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false,
      },
    })
  }
  
  return _supabase
}

// For backward compatibility - but will be null if not configured
export const supabase = isSupabaseConfigured 
  ? createClient(SUPABASE_URL, SUPABASE_KEY, {
      auth: {
        storage: AsyncStorage,
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false,
      },
    })
  : null as unknown as SupabaseClient  // Type assertion for compatibility

// ===========================================
// AUTH HELPER FUNCTIONS
// ===========================================

/**
 * Get the current authenticated user from Supabase Auth.
 * Returns null if not authenticated or Supabase not configured.
 */
export async function getCurrentUser(): Promise<User | null> {
  const client = getSupabase()
  if (!client) {
    logger.warn('getCurrentUser: Supabase not configured')
    return null
  }
  
  try {
    const { data: { user }, error } = await client.auth.getUser()
    if (error) {
      logger.warn('getCurrentUser: Error getting user', { error: error.message })
      return null
    }
    return user
  } catch (error) {
    logger.error('getCurrentUser: Exception', error)
    return null
  }
}

/**
 * Get the current user's ID (auth.uid).
 * Returns null if not authenticated or Supabase not configured.
 */
export async function getCurrentUserId(): Promise<string | null> {
  const user = await getCurrentUser()
  return user?.id || null
}

/**
 * Get the current session.
 * Returns null if no active session or Supabase not configured.
 */
export async function getCurrentSession(): Promise<Session | null> {
  const client = getSupabase()
  if (!client) {
    logger.warn('getCurrentSession: Supabase not configured')
    return null
  }
  
  try {
    const { data: { session }, error } = await client.auth.getSession()
    if (error) {
      logger.warn('getCurrentSession: Error getting session', { error: error.message })
      return null
    }
    return session
  } catch (error) {
    logger.error('getCurrentSession: Exception', error)
    return null
  }
}

/**
 * Check if user is authenticated with Supabase.
 * Returns false if not authenticated or Supabase not configured.
 */
export async function isAuthenticated(): Promise<boolean> {
  const session = await getCurrentSession()
  return session !== null
}

/**
 * Sign out from Supabase.
 */
export async function signOut(): Promise<{ error: Error | null }> {
  const client = getSupabase()
  if (!client) {
    return { error: new Error('Supabase not configured') }
  }
  
  try {
    const { error } = await client.auth.signOut()
    if (error) {
      logger.error('signOut: Error', { error: error.message })
      return { error }
    }
    logger.info('signOut: Success')
    return { error: null }
  } catch (error) {
    logger.error('signOut: Exception', error)
    return { error: error instanceof Error ? error : new Error('Unknown error') }
  }
}

        
/**
 * Integration Test Setup
 * 
 * Minimal setup for integration tests.
 * Does NOT define __DEV__ or other React Native globals
 * since integration tests don't import app code that needs them.
 */

// Nothing special needed - integration tests use their own DB helper
// which doesn't require React Native globals.

// Increase timeout for database operations
jest.setTimeout(10000);

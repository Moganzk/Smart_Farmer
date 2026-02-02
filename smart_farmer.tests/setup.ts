/**
 * Smart Farmer Test Setup
 * 
 * Provides an in-memory SQLite database for testing.
 * Uses better-sqlite3 which is Node.js compatible.
 */

import Database from 'better-sqlite3';

// Define React Native __DEV__ global for testing
// @ts-ignore - __DEV__ is defined by react-native types but not available in Node
(globalThis as any).__DEV__ = true;

// Global test database instance
let testDb: Database.Database | null = null;

// Mock device ID for testing
const TEST_DEVICE_ID = 'test-device-id-12345';

/**
 * Get or create the test database (in-memory)
 */
export function getTestDatabase(): Database.Database {
  if (!testDb) {
    testDb = new Database(':memory:');
    testDb.pragma('foreign_keys = ON');
  }
  return testDb;
}

/**
 * Reset the test database (drop all tables)
 */
export function resetTestDatabase(): void {
  if (testDb) {
    testDb.close();
    testDb = null;
  }
  testDb = new Database(':memory:');
  testDb.pragma('foreign_keys = ON');
}

/**
 * Close the test database
 */
export function closeTestDatabase(): void {
  if (testDb) {
    testDb.close();
    testDb = null;
  }
}

/**
 * Get mock device ID for testing
 */
export function getTestDeviceId(): string {
  return TEST_DEVICE_ID;
}

// Clean up after all tests
afterAll(() => {
  closeTestDatabase();
});

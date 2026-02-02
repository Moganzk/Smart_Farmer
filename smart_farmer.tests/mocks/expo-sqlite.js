// Mock for expo-sqlite in tests
// Note: Actual DB tests use better-sqlite3 via testDb.ts
// This mock is for component imports that reference expo-sqlite

const openDatabaseSync = jest.fn((dbName) => {
  return {
    transaction: jest.fn((callback) => {
      const tx = {
        executeSql: jest.fn((sql, params, success, error) => {
          if (success) success(tx, { rows: { _array: [], length: 0 } });
        }),
      };
      callback(tx);
    }),
    // Synchronous methods
    execSync: jest.fn((sql) => undefined),
    runSync: jest.fn((sql, params) => ({ lastInsertRowId: 1, changes: 1 })),
    getFirstSync: jest.fn((sql, params) => null),
    getAllSync: jest.fn((sql, params) => []),
    // Async methods
    execAsync: jest.fn((sql) => Promise.resolve()),
    runAsync: jest.fn((sql, params) => Promise.resolve({ lastInsertRowId: 1, changes: 1 })),
    getFirstAsync: jest.fn((sql, params) => Promise.resolve(null)),
    getAllAsync: jest.fn((sql, params) => Promise.resolve([])),
    closeAsync: jest.fn(() => Promise.resolve()),
    closeSync: jest.fn(() => undefined),
  };
});

const openDatabaseAsync = jest.fn(async (dbName) => {
  return openDatabaseSync(dbName);
});

// Legacy openDatabase for older expo-sqlite versions
const openDatabase = jest.fn((dbName, version, description, size) => {
  return openDatabaseSync(dbName);
});

module.exports = {
  openDatabaseSync,
  openDatabaseAsync,
  openDatabase,
  // Default export for * as SQLite imports
  default: {
    openDatabaseSync,
    openDatabaseAsync,
    openDatabase,
  },
};

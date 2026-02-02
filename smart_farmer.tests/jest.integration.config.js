/**
 * Jest Configuration for Integration Tests
 * 
 * Integration tests run against a real SQLite database (better-sqlite3).
 * No Expo module mocks are used - tests interact with actual DB logic.
 * 
 * Run: npm run test:integration
 * 
 * @type {import('ts-jest').JestConfigWithTsJest}
 */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/integration'],
  testMatch: ['**/*.test.ts'],
  // No module mocks - integration tests use real implementations
  moduleNameMapper: {
    // Path aliases only
    '^@/(.*)$': '<rootDir>/../smart_farmer/$1',
    // Asset mocks (still needed for any asset imports)
    '\\.(png|jpg|jpeg|gif|svg)$': '<rootDir>/fileMock.js',
  },
  setupFilesAfterEnv: ['<rootDir>/setup.integration.ts'],
  clearMocks: true,
  // Longer timeout for DB operations
  testTimeout: 10000,
  transform: {
    '^.+\\.tsx?$': [
      'ts-jest',
      {
        tsconfig: {
          jsx: 'react',
          esModuleInterop: true,
          allowSyntheticDefaultImports: true,
          noImplicitAny: false,
          skipLibCheck: true,
        },
        isolatedModules: true,
      },
    ],
  },
};

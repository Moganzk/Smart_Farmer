/**
 * Jest Configuration for Smart Farmer Tests
 * 
 * TEST TIERS:
 * 1. Unit Tests (default) - Fast, mocked, isolated
 *    - Run: npm test or npm run test:unit
 *    - Location: *.test.ts (root level)
 * 
 * 2. Integration Tests - Real SQLite via better-sqlite3
 *    - Run: npm run test:integration
 *    - Location: integration/*.test.ts
 * 
 * 3. All Tests
 *    - Run: npm run test:all
 * 
 * @type {import('ts-jest').JestConfigWithTsJest}
 */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>'],
  // Default: unit tests only (excludes integration folder)
  testMatch: ['<rootDir>/*.test.ts'],
  testPathIgnorePatterns: ['/node_modules/', '/integration/'],
  moduleNameMapper: {
    // Path aliases
    '^@/(.*)$': '<rootDir>/../smart_farmer/$1',
    // Asset mocks
    '\\.(png|jpg|jpeg|gif|svg)$': '<rootDir>/fileMock.js',
    // React Native mocks
    '^react-native$': '<rootDir>/mocks/react-native.js',
    '^react-native-safe-area-context$': '<rootDir>/mocks/react-native-safe-area-context.js',
    // React Navigation mocks
    '^@react-navigation/(.*)$': '<rootDir>/mocks/react-navigation.js',
    // Expo module mocks
    '^expo-camera$': '<rootDir>/mocks/expo-camera.js',
    '^expo-file-system$': '<rootDir>/mocks/expo-file-system.js',
    '^expo-sqlite$': '<rootDir>/mocks/expo-sqlite.js',
    // AsyncStorage mock
    '^@react-native-async-storage/async-storage$': '<rootDir>/mocks/async-storage.js',
    // Supabase mocks
    '^react-native-url-polyfill/auto$': '<rootDir>/mocks/react-native-url-polyfill.js',
    '^@supabase/supabase-js$': '<rootDir>/mocks/supabase.js',
    '^\\.\\./utils/supabase$': '<rootDir>/mocks/supabase.js',
    '^\\.\\./.*/utils/supabase$': '<rootDir>/mocks/supabase.js',
  },
  setupFilesAfterEnv: ['<rootDir>/setup.ts'],
  clearMocks: true,
  collectCoverageFrom: [
    '../smart_farmer/db/**/*.ts',
    '!../smart_farmer/db/index.ts',
  ],
  coverageDirectory: './coverage',
  coverageReporters: ['text', 'lcov'],
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

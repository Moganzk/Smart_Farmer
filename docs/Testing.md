# Testing Guide - Smart Farmer

## Overview

Tests are located in `smart_farmer.tests/` at the repository root.
The test suite is organized into two tiers for different testing needs.

## Test Tiers

### 1. Unit Tests (Fast, Isolated)

**Location:** `smart_farmer.tests/*.test.ts`  
**Run:** `npm test` or `npm run test:unit`

Unit tests are:
- **Fast** - Run in ~3 seconds (100 tests)
- **Mocked** - All Expo modules (camera, SQLite, file system) are mocked
- **Isolated** - No external dependencies, no real database

**What's tested:**
- UI component imports and structure
- Navigation imports (23 tests)
- Logger utility (27 tests)
- Asset registry (8 tests)
- Auth context with mocked AsyncStorage (4 tests)
- Database schema using better-sqlite3 (22 tests)
- Screen background components (6 tests)
- Badge component (10 tests)

**When to write unit tests:**
- Testing component logic without rendering
- Testing utility functions
- Testing module exports
- Testing isolated business logic

### 2. Integration Tests (Real SQLite)

**Location:** `smart_farmer.tests/integration/*.test.ts`  
**Run:** `npm run test:integration`

Integration tests are:
- **Slower** - Use real database operations
- **Deterministic** - Fresh in-memory SQLite per test
- **Realistic** - Test actual SQL queries and data flow

**What's tested:**
- Scan workflow - save, load, history (4 tests)
- Sync queue operations - enqueue, mark synced, mark failed (5 tests)
- Tips CRUD operations (3 tests)

**When to write integration tests:**
- Testing SQL queries
- Testing sync queue behavior
- Testing data persistence
- Testing multi-table operations

## SQLite Test Infrastructure

### How It Works

Integration tests use **better-sqlite3**, a Node.js-native SQLite library that:
1. Is synchronous (simpler test code)
2. Runs in-memory (fast, isolated)
3. Has the same API patterns as expo-sqlite

### Test Database Helper

Located at: `smart_farmer.tests/helpers/integrationDb.ts`

```typescript
import {
  getTestDb,       // Get SQLite database instance
  initTestDb,      // Create all tables
  resetTestDb,     // Reset database completely
  closeTestDb,     // Close connection
  generateUUID,    // Generate test IDs
  getISOTimestamp, // Get current timestamp
  enqueueSync,     // Add to sync queue
  markSynced,      // Mark record synced
  markFailed,      // Mark sync failed
  getPendingQueue, // Get pending sync items
  TEST_DEVICE_ID,  // Constant test device ID
} from '../helpers/integrationDb';
```

### Test Isolation Pattern

Each integration test file should:

```typescript
describe('My Integration Tests', () => {
  beforeAll(() => {
    initTestDb();  // Create tables once
  });

  beforeEach(() => {
    // Clear relevant tables between tests
    const db = getTestDb();
    db.exec('DELETE FROM my_table');
  });

  afterAll(() => {
    closeTestDb();  // Clean up
  });

  it('should do something', () => {
    const db = getTestDb();
    // Use db.prepare().run() or db.prepare().get()
  });
});
```

## Running Tests

From the repository root:

| Command | Description | Tests |
|---------|-------------|-------|
| `npm test` | Run unit tests only (default) | 100 |
| `npm run test:unit` | Run unit tests only | 100 |
| `npm run test:integration` | Run integration tests only | 12 |
| `npm run test:all` | Run both unit and integration | 112 |
| `npm run test:watch` | Run unit tests in watch mode | - |
| `npm run test:coverage` | Run unit tests with coverage | - |

## Test Configuration Files

### Unit Tests (`jest.config.js`)

- Uses module mocks for React Native, Expo, AsyncStorage
- Excludes `/integration/` folder
- Setup file: `setup.ts` (defines `__DEV__` global)

### Integration Tests (`jest.integration.config.js`)

- No Expo module mocks
- Only runs tests in `/integration/` folder
- Setup file: `setup.integration.ts`
- Longer timeout (10s) for DB operations

## Adding New Tests

### Unit Test Example

```typescript
// myFeature.test.ts
import { myFunction } from '../smart_farmer/utils/myModule';

describe('My Feature', () => {
  it('should work correctly', () => {
    const result = myFunction('input');
    expect(result).toBe('expected');
  });
});
```

### Integration Test Example

```typescript
// integration/myFeature.test.ts
import {
  getTestDb,
  initTestDb,
  closeTestDb,
  generateUUID,
} from '../helpers/integrationDb';

describe('My Feature Integration', () => {
  beforeAll(() => initTestDb());
  afterAll(() => closeTestDb());

  it('should persist data correctly', () => {
    const db = getTestDb();
    const id = generateUUID();
    
    db.prepare('INSERT INTO table (id) VALUES (?)').run(id);
    const row = db.prepare('SELECT * FROM table WHERE id = ?').get(id);
    
    expect(row).toBeDefined();
  });
});
```

## Troubleshooting

### "Cannot find module 'expo-sqlite'"

Unit tests mock expo-sqlite. If you see this error in integration tests, make sure you're importing from `../helpers/integrationDb` instead of the app's database module.

### Tests passing locally but failing in CI

Ensure better-sqlite3 is in devDependencies and can compile native bindings in CI.

### Database state leaking between tests

Always clear relevant tables in `beforeEach()` or call `resetTestDb()` if you need a completely fresh database.

### Watch Mode
```bash
npm run test:watch
```

### Integration Tests Only
```bash
npm run test:integration
```

### Coverage Report
```bash
npm run test:coverage
```

## Test Structure

### SQLite Tests Pattern
```typescript
beforeAll(async () => {
  await initDb();
  db = getDatabase();
});

beforeEach(() => {
  // Clean test data
  db.runSync('DELETE FROM table WHERE local_id LIKE ?', ['test_%']);
});

it('should perform operation', () => {
  // Use sync methods: runSync, getFirstSync, getAllSync
  // All test IDs start with 'test_' or use generateUUID()
});
```

### Key Testing Principles
1. **Isolation**: Each test cleans up its own data
2. **Deterministic**: Use fixed device IDs and predictable UUIDs where possible
3. **Offline-first**: Test local operations first, sync second
4. **Real SQLite**: Tests use actual expo-sqlite, not mocks

## Database Schema Awareness

All tests must respect the actual schema from [database.ts](../smart_farmer/db/database.ts):

### Scans Table
- `local_id` (UUID primary key)
- `user_local_id` (foreign key to users)
- `image_path`, `crop_type`, `scanned_at`
- Standard sync fields: `sync_status`, `device_id`, `updated_at`, `version`, `deleted_at`

### Diagnoses Table
- `local_id` (UUID primary key)
- `scan_local_id` (foreign key to scans)
- `disease_name`, `confidence`, `severity`, `recommendations`
- Standard sync fields

### Tips Table
- `local_id`, `title`, `content`, `category`, `language`, `published_at`
- Standard sync fields

### Sync Queue Table
- `table_name`, `local_id`, `operation` (insert/update/delete)
- `retry_count`, `last_error`, `last_attempted_at`

## API Reference

### Database Functions
```typescript
initDb()              // Initialize all tables
getDatabase()         // Get DB instance
generateUUID()        // Generate unique ID
getISOTimestamp()     // Get ISO timestamp
```

### Sync Queue Functions
```typescript
enqueueSync(table, localId, operation)  // Add to queue
markSynced(table, localId, serverId?)   // Mark successful
markFailed(table, localId, error)       // Mark failed with retry
getPendingQueue(limit?, maxRetries?)    // Get pending items
```

## Mocking Strategy

### Required Mocks
- `@react-native-async-storage/async-storage`
- `../smart_farmer/utils/logger`
- `../smart_farmer/utils/deviceId` (returns 'test-device-123')

### NOT Mocked
- expo-sqlite (uses real implementation)
- Database functions (integration tests)

## Next Steps

1. **Complete Auth Context Tests**: Set up React context testing with `@testing-library/react`
2. **Add Camera Permission Tests**: Mock expo-camera and test permission flows
3. **Sync Background Worker Tests**: Test actual sync logic with Supabase mocks
4. **E2E Tests**: Consider Detox for full device testing after EAS build

## CI/CD Considerations

For CI pipelines:
- Tests run in Node environment
- SQLite works via better-sqlite3 polyfill
- No physical device needed for unit/integration tests
- Camera/permission tests will need mocking or E2E framework

## Troubleshooting

### "Cannot find module" errors
- Ensure all imports match actual file paths
- Check jest.config.js moduleNameMapper

### SQLite errors
- Verify initDb() is called in beforeAll
- Check schema matches actual database.ts

### Timeout errors
- Increase Jest timeout for slow operations
- Consider separating unit vs integration tests

/**
 * Smart Farmer - Logger Tests
 * 
 * Tests for the centralized logging utility.
 */

import logger, {
  debug,
  info,
  warn,
  error,
  syncLog,
  dbLog,
  authLog,
  configureLogger,
  getLoggerConfig,
  resetLoggerConfig,
  LogLevel,
} from './testLogger';

describe('Logger Configuration', () => {
  beforeEach(() => {
    resetLoggerConfig();
  });

  test('default config has logging enabled', () => {
    const config = getLoggerConfig();
    expect(config.enabled).toBe(true);
  });

  test('default config shows timestamps', () => {
    const config = getLoggerConfig();
    expect(config.showTimestamp).toBe(true);
  });

  test('configureLogger merges options', () => {
    configureLogger({ minLevel: 'error' });
    const config = getLoggerConfig();
    expect(config.minLevel).toBe('error');
    expect(config.enabled).toBe(true); // Other defaults preserved
  });

  test('configureLogger can disable logging', () => {
    configureLogger({ enabled: false });
    const config = getLoggerConfig();
    expect(config.enabled).toBe(false);
  });

  test('resetLoggerConfig restores defaults', () => {
    configureLogger({ enabled: false, minLevel: 'error' });
    resetLoggerConfig();
    const config = getLoggerConfig();
    expect(config.enabled).toBe(true);
  });
});

describe('Log Level Filtering', () => {
  let loggedEntries: Array<{ level: LogLevel; message: string }>;

  beforeEach(() => {
    loggedEntries = [];
    resetLoggerConfig();
    configureLogger({
      minLevel: 'debug',
      onLog: (entry) => {
        loggedEntries.push({ level: entry.level, message: entry.message });
      },
    });
  });

  test('debug logs when minLevel is debug', () => {
    debug('test debug');
    expect(loggedEntries).toHaveLength(1);
    expect(loggedEntries[0].level).toBe('debug');
  });

  test('debug is filtered when minLevel is info', () => {
    configureLogger({ minLevel: 'info' });
    debug('test debug');
    expect(loggedEntries).toHaveLength(0);
  });

  test('info logs when minLevel is info', () => {
    configureLogger({ minLevel: 'info' });
    info('test info');
    expect(loggedEntries).toHaveLength(1);
    expect(loggedEntries[0].level).toBe('info');
  });

  test('warn logs when minLevel is warn', () => {
    configureLogger({ minLevel: 'warn' });
    warn('test warn');
    expect(loggedEntries).toHaveLength(1);
    expect(loggedEntries[0].level).toBe('warn');
  });

  test('error always logs when minLevel is error', () => {
    configureLogger({ minLevel: 'error' });
    error('test error');
    expect(loggedEntries).toHaveLength(1);
    expect(loggedEntries[0].level).toBe('error');
  });

  test('lower priority logs are filtered', () => {
    configureLogger({ minLevel: 'warn' });
    debug('debug');
    info('info');
    warn('warn');
    error('error');
    expect(loggedEntries).toHaveLength(2);
    expect(loggedEntries[0].level).toBe('warn');
    expect(loggedEntries[1].level).toBe('error');
  });
});

describe('Log Output', () => {
  let loggedEntries: Array<{ level: LogLevel; message: string; data?: unknown }>;

  beforeEach(() => {
    loggedEntries = [];
    resetLoggerConfig();
    configureLogger({
      minLevel: 'debug',
      onLog: (entry) => {
        loggedEntries.push({
          level: entry.level,
          message: entry.message,
          data: entry.data,
        });
      },
    });
  });

  test('log includes message', () => {
    info('Hello world');
    expect(loggedEntries[0].message).toBe('Hello world');
  });

  test('log includes optional data', () => {
    const testData = { userId: '123', action: 'scan' };
    info('User action', testData);
    expect(loggedEntries[0].data).toEqual(testData);
  });

  test('log works without data', () => {
    info('Simple message');
    expect(loggedEntries[0].data).toBeUndefined();
  });
});

describe('Convenience Loggers', () => {
  let loggedEntries: Array<{ level: LogLevel; message: string }>;

  beforeEach(() => {
    loggedEntries = [];
    resetLoggerConfig();
    configureLogger({
      minLevel: 'debug',
      onLog: (entry) => {
        loggedEntries.push({ level: entry.level, message: entry.message });
      },
    });
  });

  test('syncLog start uses debug level', () => {
    syncLog('start', 'users', 'uuid-123');
    expect(loggedEntries[0].level).toBe('debug');
    expect(loggedEntries[0].message).toContain('Sync start');
    expect(loggedEntries[0].message).toContain('users');
  });

  test('syncLog fail uses error level', () => {
    syncLog('fail', 'scans', 'uuid-456');
    expect(loggedEntries[0].level).toBe('error');
  });

  test('syncLog retry uses warn level', () => {
    syncLog('retry', 'scans', 'uuid-789');
    expect(loggedEntries[0].level).toBe('warn');
  });

  test('dbLog uses debug level', () => {
    dbLog('insert', 'users');
    expect(loggedEntries[0].level).toBe('debug');
    expect(loggedEntries[0].message).toContain('DB insert');
  });

  test('authLog login uses info level', () => {
    authLog('login');
    expect(loggedEntries[0].level).toBe('info');
  });

  test('authLog error uses error level', () => {
    authLog('error', { code: 'AUTH_FAILED' });
    expect(loggedEntries[0].level).toBe('error');
  });
});

describe('Disabled Logging', () => {
  let loggedEntries: Array<{ level: LogLevel; message: string }>;

  beforeEach(() => {
    loggedEntries = [];
    resetLoggerConfig();
    configureLogger({
      enabled: false,
      onLog: (entry) => {
        loggedEntries.push({ level: entry.level, message: entry.message });
      },
    });
  });

  test('no logs when disabled', () => {
    debug('debug');
    info('info');
    warn('warn');
    error('error');
    expect(loggedEntries).toHaveLength(0);
  });
});

describe('Logger Safety', () => {
  beforeEach(() => {
    resetLoggerConfig();
  });

  test('logger never throws on normal usage', () => {
    expect(() => {
      debug('test');
      info('test');
      warn('test');
      error('test');
    }).not.toThrow();
  });

  test('logger handles undefined data', () => {
    expect(() => {
      info('test', undefined);
    }).not.toThrow();
  });

  test('logger handles null data', () => {
    expect(() => {
      info('test', null);
    }).not.toThrow();
  });

  test('logger handles circular references in data', () => {
    const circular: Record<string, unknown> = { a: 1 };
    circular.self = circular;
    expect(() => {
      info('test', circular);
    }).not.toThrow();
  });

  test('logger handles throwing onLog callback', () => {
    configureLogger({
      onLog: () => {
        throw new Error('Callback error');
      },
    });
    expect(() => {
      info('test');
    }).not.toThrow();
  });
});

describe('Default Export', () => {
  test('default export has all methods', () => {
    expect(typeof logger.debug).toBe('function');
    expect(typeof logger.info).toBe('function');
    expect(typeof logger.warn).toBe('function');
    expect(typeof logger.error).toBe('function');
    expect(typeof logger.syncLog).toBe('function');
    expect(typeof logger.dbLog).toBe('function');
    expect(typeof logger.authLog).toBe('function');
    expect(typeof logger.configure).toBe('function');
    expect(typeof logger.getConfig).toBe('function');
    expect(typeof logger.reset).toBe('function');
  });
});

/**
 * Smart Farmer - Logger Utility
 * 
 * Centralized logging for the mobile app.
 * All logging MUST go through this module - no direct console.log usage.
 * 
 * Features:
 * - Log levels: debug, info, warn, error
 * - Safe for offline usage (never blocks)
 * - Production-ready (can silence debug logs)
 * - Structured logging with timestamps
 */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  data?: unknown;
}

interface LoggerConfig {
  /** Minimum level to output. Logs below this level are silenced. */
  minLevel: LogLevel;
  /** Enable/disable all logging */
  enabled: boolean;
  /** Include timestamps in output */
  showTimestamp: boolean;
  /** Optional callback for custom log handling (e.g., crash reporting) */
  onLog?: (entry: LogEntry) => void;
}

// Log level priority (higher = more severe)
const LOG_LEVEL_PRIORITY: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

// Default configuration
let config: LoggerConfig = {
  minLevel: __DEV__ ? 'debug' : 'info', // Show debug only in dev
  enabled: true,
  showTimestamp: true,
};

// Check if we're in React Native dev mode
declare const __DEV__: boolean | undefined;

/**
 * Configure the logger.
 * Call this early in app initialization.
 */
export function configureLogger(options: Partial<LoggerConfig>): void {
  config = { ...config, ...options };
}

/**
 * Get current logger configuration
 */
export function getLoggerConfig(): Readonly<LoggerConfig> {
  return { ...config };
}

/**
 * Reset logger to default configuration
 */
export function resetLoggerConfig(): void {
  config = {
    minLevel: typeof __DEV__ !== 'undefined' && __DEV__ ? 'debug' : 'info',
    enabled: true,
    showTimestamp: true,
  };
}

/**
 * Check if a log level should be output
 */
function shouldLog(level: LogLevel): boolean {
  if (!config.enabled) return false;
  return LOG_LEVEL_PRIORITY[level] >= LOG_LEVEL_PRIORITY[config.minLevel];
}

/**
 * Format a log message with optional timestamp
 */
function formatMessage(level: LogLevel, message: string): string {
  const prefix = `[${level.toUpperCase()}]`;
  if (config.showTimestamp) {
    const timestamp = new Date().toISOString();
    return `${timestamp} ${prefix} ${message}`;
  }
  return `${prefix} ${message}`;
}

/**
 * Core logging function
 */
function log(level: LogLevel, message: string, data?: unknown): void {
  // Never throw - logging must be safe
  try {
    if (!shouldLog(level)) return;

    const entry: LogEntry = {
      level,
      message,
      timestamp: new Date().toISOString(),
      data,
    };

    // Call custom handler if provided
    if (config.onLog) {
      try {
        config.onLog(entry);
      } catch {
        // Silently ignore handler errors
      }
    }

    const formattedMessage = formatMessage(level, message);

    // Use appropriate console method
    switch (level) {
      case 'debug':
        if (data !== undefined) {
          console.debug(formattedMessage, data);
        } else {
          console.debug(formattedMessage);
        }
        break;
      case 'info':
        if (data !== undefined) {
          console.info(formattedMessage, data);
        } else {
          console.info(formattedMessage);
        }
        break;
      case 'warn':
        if (data !== undefined) {
          console.warn(formattedMessage, data);
        } else {
          console.warn(formattedMessage);
        }
        break;
      case 'error':
        if (data !== undefined) {
          console.error(formattedMessage, data);
        } else {
          console.error(formattedMessage);
        }
        break;
    }
  } catch {
    // Never let logging crash the app
  }
}

/**
 * Log a debug message.
 * Use for detailed diagnostic information during development.
 */
export function debug(message: string, data?: unknown): void {
  log('debug', message, data);
}

/**
 * Log an info message.
 * Use for general operational information.
 */
export function info(message: string, data?: unknown): void {
  log('info', message, data);
}

/**
 * Log a warning.
 * Use for potentially harmful situations that don't prevent operation.
 */
export function warn(message: string, data?: unknown): void {
  log('warn', message, data);
}

/**
 * Log an error.
 * Use for error conditions that affect functionality.
 */
export function error(message: string, data?: unknown): void {
  log('error', message, data);
}

/**
 * Log a sync-related event.
 * Convenience wrapper for sync operations.
 */
export function syncLog(
  operation: 'start' | 'success' | 'fail' | 'retry',
  table: string,
  localId: string,
  details?: unknown
): void {
  const message = `Sync ${operation}: ${table}/${localId}`;
  switch (operation) {
    case 'fail':
      error(message, details);
      break;
    case 'retry':
      warn(message, details);
      break;
    default:
      debug(message, details);
  }
}

/**
 * Log a database operation.
 * Convenience wrapper for DB operations.
 */
export function dbLog(
  operation: 'insert' | 'update' | 'delete' | 'query' | 'init',
  table: string,
  details?: unknown
): void {
  debug(`DB ${operation}: ${table}`, details);
}

/**
 * Log an authentication event.
 */
export function authLog(
  event: 'login' | 'logout' | 'session_refresh' | 'error',
  details?: unknown
): void {
  const message = `Auth: ${event}`;
  if (event === 'error') {
    error(message, details);
  } else {
    info(message, details);
  }
}

// Default export for convenience
// Also export as named export for `import { logger }` syntax
export const logger = {
  debug,
  info,
  warn,
  error,
  syncLog,
  dbLog,
  authLog,
  configure: configureLogger,
  getConfig: getLoggerConfig,
  reset: resetLoggerConfig,
};

export default logger;

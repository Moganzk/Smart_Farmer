/**
 * Smart Farmer - Test Logger Module
 * 
 * Node.js compatible version of the logger for testing.
 * Mirrors the production logger API.
 */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  data?: unknown;
}

interface LoggerConfig {
  minLevel: LogLevel;
  enabled: boolean;
  showTimestamp: boolean;
  onLog?: (entry: LogEntry) => void;
}

const LOG_LEVEL_PRIORITY: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

let config: LoggerConfig = {
  minLevel: 'debug',
  enabled: true,
  showTimestamp: true,
};

export function configureLogger(options: Partial<LoggerConfig>): void {
  config = { ...config, ...options };
}

export function getLoggerConfig(): Readonly<LoggerConfig> {
  return { ...config };
}

export function resetLoggerConfig(): void {
  config = {
    minLevel: 'debug',
    enabled: true,
    showTimestamp: true,
  };
}

function shouldLog(level: LogLevel): boolean {
  if (!config.enabled) return false;
  return LOG_LEVEL_PRIORITY[level] >= LOG_LEVEL_PRIORITY[config.minLevel];
}

function formatMessage(level: LogLevel, message: string): string {
  const prefix = `[${level.toUpperCase()}]`;
  if (config.showTimestamp) {
    const timestamp = new Date().toISOString();
    return `${timestamp} ${prefix} ${message}`;
  }
  return `${prefix} ${message}`;
}

function log(level: LogLevel, message: string, data?: unknown): void {
  try {
    if (!shouldLog(level)) return;

    const entry: LogEntry = {
      level,
      message,
      timestamp: new Date().toISOString(),
      data,
    };

    if (config.onLog) {
      try {
        config.onLog(entry);
      } catch {
        // Silently ignore handler errors
      }
    }

    const formattedMessage = formatMessage(level, message);

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

export function debug(message: string, data?: unknown): void {
  log('debug', message, data);
}

export function info(message: string, data?: unknown): void {
  log('info', message, data);
}

export function warn(message: string, data?: unknown): void {
  log('warn', message, data);
}

export function error(message: string, data?: unknown): void {
  log('error', message, data);
}

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

export function dbLog(
  operation: 'insert' | 'update' | 'delete' | 'query' | 'init',
  table: string,
  details?: unknown
): void {
  debug(`DB ${operation}: ${table}`, details);
}

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

const logger = {
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

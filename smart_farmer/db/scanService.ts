/**
 * Smart Farmer - Scan Service
 * 
 * Pure SQLite operations for scan and diagnosis records.
 * Offline-first: all operations work without network.
 * 
 * This is the service layer for scan-related DB operations.
 * Records sync intent to sync_queue but does NOT perform network sync.
 */

import { getDatabase, generateUUID, getISOTimestamp } from './database';
import { enqueueSync } from './syncQueue';
import { getDeviceId } from '../utils/deviceId';
import type { Scan, Diagnosis, SyncStatus } from './types';
import { logger } from '../utils/logger';

// ============ Types ============

/** Input for creating a new scan */
export interface CreateScanInput {
  userLocalId: string;
  imagePath: string;
  cropType?: string;
  latitude?: number;
  longitude?: number;
}

/** Input for creating a diagnosis */
export interface CreateDiagnosisInput {
  scanLocalId: string;
  diseaseName: string;
  confidence: number;
  severity?: 'low' | 'medium' | 'high';
  recommendations: string[];
}

/** Scan with joined diagnosis for history display */
export interface ScanWithDiagnosis {
  local_id: string;
  image_path: string;
  crop_type: string | null;
  scanned_at: string;
  disease_name: string;
  confidence: number;
  severity: string | null;
  recommendations: string;
}

// ============ Scan Operations ============

/**
 * Create a new scan record in SQLite.
 * Returns the generated local_id.
 * 
 * @param input - Scan creation input
 * @returns The local_id of the created scan
 */
export async function createScan(input: CreateScanInput): Promise<string> {
  const db = getDatabase();
  const localId = generateUUID();
  const now = getISOTimestamp();
  const deviceId = await getDeviceId();

  db.runSync(
    `INSERT INTO scans (
      local_id, server_id, sync_status, updated_at, deleted_at,
      device_id, version, user_local_id, image_path, image_server_url,
      crop_type, scanned_at, latitude, longitude
    ) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, ?, NULL, ?, ?, ?, ?)`,
    [
      localId,
      now,
      deviceId,
      input.userLocalId,
      input.imagePath,
      input.cropType || null,
      now, // scanned_at
      input.latitude || null,
      input.longitude || null,
    ]
  );

  // Record sync intent - does NOT perform network sync
  // Failure here should not break user flow
  try {
    enqueueSync('scans', localId, 'insert');
    logger.info('Scan queued for sync', { localId });
  } catch (error) {
    logger.error('Failed to queue scan for sync (non-blocking)', { localId, error });
  }

  logger.info('Scan created in SQLite', { localId, imagePath: input.imagePath });
  return localId;
}

/**
 * Create a diagnosis record linked to a scan.
 * Returns the generated local_id.
 * 
 * @param input - Diagnosis creation input
 * @returns The local_id of the created diagnosis
 */
export async function createDiagnosis(input: CreateDiagnosisInput): Promise<string> {
  const db = getDatabase();
  const localId = generateUUID();
  const now = getISOTimestamp();
  const deviceId = await getDeviceId();

  // Serialize recommendations array to JSON
  const recommendationsJson = JSON.stringify(input.recommendations);

  db.runSync(
    `INSERT INTO diagnoses (
      local_id, server_id, sync_status, updated_at, deleted_at,
      device_id, version, scan_local_id, disease_name, confidence,
      severity, recommendations, diagnosed_at
    ) VALUES (?, NULL, 'pending', ?, NULL, ?, 1, ?, ?, ?, ?, ?, ?)`,
    [
      localId,
      now,
      deviceId,
      input.scanLocalId,
      input.diseaseName,
      input.confidence,
      input.severity || null,
      recommendationsJson,
      now, // diagnosed_at
    ]
  );

  // Record sync intent - does NOT perform network sync
  // Failure here should not break user flow
  try {
    enqueueSync('diagnoses', localId, 'insert');
    logger.info('Diagnosis queued for sync', { localId });
  } catch (error) {
    logger.error('Failed to queue diagnosis for sync (non-blocking)', { localId, error });
  }

  logger.info('Diagnosis created in SQLite', { 
    localId, 
    scanLocalId: input.scanLocalId, 
    disease: input.diseaseName 
  });
  return localId;
}

// ============ Query Operations ============

/**
 * Get scan history for a user with joined diagnosis data.
 * Returns scans ordered by most recent first.
 * Only returns scans that have a diagnosis and are not deleted.
 * 
 * @param userLocalId - The user's local_id
 * @param limit - Maximum number of scans to return (default 50)
 * @returns Array of scans with diagnosis data
 */
export function getScanHistory(
  userLocalId: string, 
  limit: number = 50
): ScanWithDiagnosis[] {
  const db = getDatabase();
  
  const rows = db.getAllSync<ScanWithDiagnosis>(
    `SELECT 
      s.local_id,
      s.image_path,
      s.crop_type,
      s.scanned_at,
      d.disease_name,
      d.confidence,
      d.severity,
      d.recommendations
    FROM scans s
    INNER JOIN diagnoses d ON d.scan_local_id = s.local_id
    WHERE s.user_local_id = ?
      AND s.deleted_at IS NULL
      AND d.deleted_at IS NULL
    ORDER BY s.scanned_at DESC
    LIMIT ?`,
    [userLocalId, limit]
  );

  return rows || [];
}

/**
 * Get a single scan by local_id with diagnosis.
 * 
 * @param localId - The scan's local_id
 * @returns The scan with diagnosis or null if not found
 */
export function getScanById(localId: string): ScanWithDiagnosis | null {
  const db = getDatabase();
  
  const row = db.getFirstSync<ScanWithDiagnosis>(
    `SELECT 
      s.local_id,
      s.image_path,
      s.crop_type,
      s.scanned_at,
      d.disease_name,
      d.confidence,
      d.severity,
      d.recommendations
    FROM scans s
    INNER JOIN diagnoses d ON d.scan_local_id = s.local_id
    WHERE s.local_id = ?
      AND s.deleted_at IS NULL
      AND d.deleted_at IS NULL`,
    [localId]
  );

  return row || null;
}

// ============ Mocked ML Detection ============

/**
 * Mock disease detection result.
 * In a real implementation, this would call the ML model.
 * 
 * Returns a static result for offline testing.
 */
export interface MockDetectionResult {
  diseaseName: string;
  confidence: number;
  severity: 'low' | 'medium' | 'high';
  recommendations: string[];
}

export function mockDetectDisease(): MockDetectionResult {
  // Static mock result - replace with real ML inference later
  return {
    diseaseName: 'Late Blight',
    confidence: 0.87,
    severity: 'medium',
    recommendations: [
      'Remove and destroy infected plant parts',
      'Apply copper-based fungicide',
      'Improve air circulation around plants',
      'Avoid overhead watering',
      'Monitor nearby plants for signs of infection',
    ],
  };
}

/**
 * Perform a full scan workflow:
 * 1. Create scan record
 * 2. Run detection (mocked)
 * 3. Create diagnosis record
 * 
 * Returns the scan local_id for navigation.
 * 
 * @param userLocalId - The user's local_id
 * @param imagePath - Path to the captured image
 * @param cropType - Optional crop type
 * @returns The created scan's local_id
 */
export async function performScan(
  userLocalId: string,
  imagePath: string,
  cropType?: string
): Promise<string> {
  // 1. Create scan record
  const scanLocalId = await createScan({
    userLocalId,
    imagePath,
    cropType,
  });

  // 2. Get mock detection result
  const detection = mockDetectDisease();

  // 3. Create diagnosis record
  await createDiagnosis({
    scanLocalId,
    diseaseName: detection.diseaseName,
    confidence: detection.confidence,
    severity: detection.severity,
    recommendations: detection.recommendations,
  });

  logger.info('Full scan workflow completed', { scanLocalId });
  return scanLocalId;
}

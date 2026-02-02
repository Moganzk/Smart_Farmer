/**
 * Smart Farmer - Device ID Utility
 * 
 * Generates and persists a unique device identifier.
 * Used to track which device created/modified records.
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import { generateUUID } from '../db/database';

const DEVICE_ID_KEY = '@smart_farmer_device_id';

// Cached device ID to avoid repeated AsyncStorage reads
let cachedDeviceId: string | null = null;

/**
 * Get the device ID, generating one if it doesn't exist.
 * Device ID is persisted across app restarts.
 */
export async function getDeviceId(): Promise<string> {
  // Return cached value if available
  if (cachedDeviceId) {
    return cachedDeviceId;
  }

  try {
    // Try to read from AsyncStorage
    const storedId = await AsyncStorage.getItem(DEVICE_ID_KEY);
    
    if (storedId) {
      cachedDeviceId = storedId;
      return storedId;
    }

    // Generate new device ID
    const newDeviceId = generateUUID();
    
    // Persist to AsyncStorage
    await AsyncStorage.setItem(DEVICE_ID_KEY, newDeviceId);
    
    cachedDeviceId = newDeviceId;
    return newDeviceId;
  } catch (error) {
    // If AsyncStorage fails, generate a temporary ID
    // This should rarely happen, but we never want to block
    console.warn('Failed to access AsyncStorage for device ID:', error);
    const tempId = generateUUID();
    cachedDeviceId = tempId;
    return tempId;
  }
}

/**
 * Clear the cached device ID (for testing purposes)
 */
export function clearDeviceIdCache(): void {
  cachedDeviceId = null;
}

/**
 * Force a new device ID (use with caution - for testing only)
 */
export async function resetDeviceId(): Promise<string> {
  const newDeviceId = generateUUID();
  await AsyncStorage.setItem(DEVICE_ID_KEY, newDeviceId);
  cachedDeviceId = newDeviceId;
  return newDeviceId;
}

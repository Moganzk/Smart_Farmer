// Asset validation utility for Smart Farmer
// Ensures all assets in the registry resolve to valid modules
// Should be run at app startup in dev or via tests

import { Icons, Backgrounds, Overlays, Logos } from './assetsRegistry';

function validateAssetModule(mod: any, key: string, category: string) {
  if (!mod || (typeof mod !== 'number' && typeof mod !== 'object')) {
    throw new Error(`Asset validation failed: ${category}.${key} did not resolve to a valid module.`);
  }
}

export function validateAllAssets() {
  // Validate icons
  Object.entries(Icons).forEach(([key, mod]) => validateAssetModule(mod, key, 'Icons'));
  // Validate backgrounds
  Object.entries(Backgrounds).forEach(([key, mod]) => validateAssetModule(mod, key, 'Backgrounds'));
  // Validate overlays
  Object.entries(Overlays).forEach(([key, mod]) => validateAssetModule(mod, key, 'Overlays'));
  // Validate logos
  Object.entries(Logos).forEach(([key, mod]) => validateAssetModule(mod, key, 'Logos'));
}

// Optionally, call validateAllAssets() in dev mode at app startup
// (e.g., if (__DEV__) validateAllAssets(); )

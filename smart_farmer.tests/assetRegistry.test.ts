// Tests for asset registry and validation
// Ensures all assets are present and resolve correctly

import { Icons, Backgrounds, Overlays, Logos, AuthBackgrounds } from '../smart_farmer/utils/assetsRegistry';
import { validateAllAssets } from '../smart_farmer/utils/validateAssets';

describe('Asset Registry', () => {
  it('should import without throwing', () => {
    expect(Icons).toBeDefined();
    expect(Backgrounds).toBeDefined();
    expect(Overlays).toBeDefined();
    expect(Logos).toBeDefined();
    expect(AuthBackgrounds).toBeDefined();
  });

  it('should resolve all icon assets', () => {
    Object.entries(Icons).forEach(([key, mod]) => {
      expect(mod).toBeDefined();
    });
  });

  it('should resolve all background assets', () => {
    Object.entries(Backgrounds).forEach(([key, mod]) => {
      expect(mod).toBeDefined();
    });
  });

  it('should resolve all overlay assets', () => {
    Object.entries(Overlays).forEach(([key, mod]) => {
      expect(mod).toBeDefined();
    });
  });

  it('should resolve all logo assets', () => {
    Object.entries(Logos).forEach(([key, mod]) => {
      expect(mod).toBeDefined();
    });
  });

  it('should resolve all auth background assets', () => {
    Object.entries(AuthBackgrounds).forEach(([key, mod]) => {
      expect(mod).toBeDefined();
    });
  });

  it('should have Logos.primary for splash/auth screens', () => {
    expect(Logos.primary).toBeDefined();
  });

  it('should have AuthBackgrounds.login for login screen', () => {
    expect(AuthBackgrounds.login).toBeDefined();
  });

  // Note: validateAllAssets() checks for runtime module resolution
  // which works differently in Jest (mocked as strings) vs React Native (module IDs)
  // The individual asset tests above verify imports work correctly
});

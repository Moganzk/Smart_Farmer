// Tests for navigation setup and screen imports
// Ensures navigation structure is correct and all screens can be imported
// Note: These tests verify imports only, not rendering

// Screen imports - Auth
describe('Auth Flow Screens', () => {
  it('should import SplashScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/SplashScreen');
    expect(module.default).toBeDefined();
  });

  it('should import LoginScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/auth/LoginScreen');
    expect(module.default).toBeDefined();
  });

  it('should import OTPScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/auth/OTPScreen');
    expect(module.default).toBeDefined();
  });

  it('should import ProfileSetupScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/auth/ProfileSetupScreen');
    expect(module.default).toBeDefined();
  });
});

describe('Main Tab Screens', () => {
  it('should import HomeScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/main/HomeScreen');
    expect(module.default).toBeDefined();
  });

  it('should import HistoryScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/main/HistoryScreen');
    expect(module.default).toBeDefined();
  });

  it('should import TipsScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/main/TipsScreen');
    expect(module.default).toBeDefined();
  });

  it('should import SettingsScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/main/SettingsScreen');
    expect(module.default).toBeDefined();
  });
});

describe('Scan Flow Screens', () => {
  it('should import ScanScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/scan/ScanScreen');
    expect(module.default).toBeDefined();
  });

  it('should import PreviewScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/scan/PreviewScreen');
    expect(module.default).toBeDefined();
  });

  it('should import ProcessingScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/scan/ProcessingScreen');
    expect(module.default).toBeDefined();
  });

  it('should import ResultsScreen without throwing', async () => {
    const module = await import('../smart_farmer/screens/scan/ResultsScreen');
    expect(module.default).toBeDefined();
  });
});

describe('Reusable UI Components', () => {
  it('should import Button without throwing', async () => {
    const module = await import('../smart_farmer/components/Button');
    expect(module.default).toBeDefined();
  });

  it('should import Input without throwing', async () => {
    const module = await import('../smart_farmer/components/Input');
    expect(module.default).toBeDefined();
  });

  it('should import Header without throwing', async () => {
    const module = await import('../smart_farmer/components/Header');
    expect(module.default).toBeDefined();
  });

  it('should import LoadingSpinner without throwing', async () => {
    const module = await import('../smart_farmer/components/LoadingSpinner');
    expect(module.default).toBeDefined();
  });

  it('should import EmptyState without throwing', async () => {
    const module = await import('../smart_farmer/components/EmptyState');
    expect(module.default).toBeDefined();
  });
});

// Navigation smoke tests
describe('Navigation Structure', () => {
  it('should import MainNavigator without throwing', async () => {
    const module = await import('../smart_farmer/navigation/MainNavigator');
    expect(module.default).toBeDefined();
  });

  it('should import AuthNavigator without throwing', async () => {
    const module = await import('../smart_farmer/navigation/AuthNavigator');
    expect(module.default).toBeDefined();
  });

  it('should import ScanNavigator without throwing', async () => {
    const module = await import('../smart_farmer/navigation/ScanNavigator');
    expect(module.default).toBeDefined();
  });

  it('should import RootNavigator without throwing', async () => {
    const module = await import('../smart_farmer/navigation/RootNavigator');
    expect(module.default).toBeDefined();
  });

  it('MainNavigator should be a function component', async () => {
    const module = await import('../smart_farmer/navigation/MainNavigator');
    expect(typeof module.default).toBe('function');
  });

  it('RootNavigator should be a function component', async () => {
    const module = await import('../smart_farmer/navigation/RootNavigator');
    expect(typeof module.default).toBe('function');
  });
});

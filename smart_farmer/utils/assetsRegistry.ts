// Centralized runtime asset registry for Smart Farmer mobile app
// DO NOT import images via raw string paths elsewhere in the app
// Categories: icons, backgrounds, overlays, logo

// ICONS
export const Icons = {
  home: require('../assets/Icons/home_icon.png'),
  history: require('../assets/Icons/history_icon.png'),
  tips: require('../assets/Icons/tips_icon.png'),
  more: require('../assets/Icons/more_icon.png'),
  scan: require('../assets/Icons/scan_button.png'),
  notification: require('../assets/Icons/notification_icon.png'),
  profile: require('../assets/Icons/profile_icon.png'),
  settings: require('../assets/Icons/settings_icon.png'),
};

// BACKGROUNDS
export const Backgrounds = {
  splash: require('../assets/Images/Splash Screen/splash_background.png'),
  scan: require('../assets/Images/scan page/scan_background.png'),
  tips: require('../assets/Images/tips/tips_background.png'),
  notifications: require('../assets/Images/notifications/notifications_background.png'),
  history: require('../assets/Images/history page/history_background.png'),
  profile: require('../assets/Images/profile/profile_background.png'),
  settings: require('../assets/Images/settings/settings_background.png'),
  dashboard: require('../assets/Images/Dashboards/dashboard_background.png'),
};

// OVERLAYS
export const Overlays = {
  camera: require('../assets/Icons/camera_overlay.png'),
};

// LOGO
export const Logos = {
  logo: require('../assets/Logo/logo.png'),
  primary: require('../assets/Logo/logo_primary.png'),
  appIcon: require('../assets/Logo/app_icon.png'),
};

// AUTH SCREENS (reuse splash background for consistency)
export const AuthBackgrounds = {
  login: require('../assets/Images/Splash Screen/splash_background.png'),
  otp: require('../assets/Images/Splash Screen/splash_background.png'),
};

// Type exports for safety
export type IconKey = keyof typeof Icons;
export type BackgroundKey = keyof typeof Backgrounds;
export type OverlayKey = keyof typeof Overlays;
export type LogoKey = keyof typeof Logos;
export type AuthBackgroundKey = keyof typeof AuthBackgrounds;

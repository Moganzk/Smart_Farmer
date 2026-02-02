// Centralized runtime asset registry for Smart Farmer mobile app
// DO NOT import images via raw string paths elsewhere in the app
// Categories: icons, backgrounds, overlays, logo

// ICONS
export const Icons = {
  home: require('../assets/icons/home_icon.png'),
  history: require('../assets/icons/history_icon.png'),
  tips: require('../assets/icons/tips_icon.png'),
  more: require('../assets/icons/more_icon.png'),
  scan: require('../assets/icons/scan_button.png'),
  notification: require('../assets/icons/notification_icon.png'),
  profile: require('../assets/icons/profile_icon.png'),
  settings: require('../assets/icons/settings_icon.png'),
};

// BACKGROUNDS
export const Backgrounds = {
  splash: require('../assets/images/splash-screen/splash_background.png'),
  scan: require('../assets/images/scan page/scan_background.png'),
  tips: require('../assets/images/tips/tips_background.png'),
  notifications: require('../assets/images/notifications/notifications_background.png'),
  history: require('../assets/images/history page/history_background.png'),
  profile: require('../assets/images/profile/profile_background.png'),
  settings: require('../assets/images/settings/settings_background.png'),
  dashboard: require('../assets/images/Dashboards/dashboard_background.png'),
};

// OVERLAYS
export const Overlays = {
  camera: require('../assets/icons/camera_overlay.png'),
};

// LOGO
export const Logos = {
  logo: require('../assets/logo/logo.png'),
  primary: require('../assets/logo/logo_primary.png'),
  appIcon: require('../assets/logo/app_icon.png'),
};

// AUTH SCREENS (reuse splash background for consistency)
export const AuthBackgrounds = {
  login: require('../assets/images/splash-screen/splash_background.png'),
  otp: require('../assets/images/splash-screen/splash_background.png'),
};

// Type exports for safety
export type IconKey = keyof typeof Icons;
export type BackgroundKey = keyof typeof Backgrounds;
export type OverlayKey = keyof typeof Overlays;
export type LogoKey = keyof typeof Logos;
export type AuthBackgroundKey = keyof typeof AuthBackgrounds;

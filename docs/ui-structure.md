# Smart Farmer UI Structure

## Overview
The Smart Farmer mobile app uses **React Navigation** for navigation and follows an **offline-first** architecture. All screens and components are built with React Native and TypeScript.

---

## Navigation Structure

### Root Navigator (`navigation/RootNavigator.tsx`)
- Manages splash screen and authentication state
- Routes to AuthNavigator or MainNavigator based on auth status

### Auth Navigator (`navigation/AuthNavigator.tsx`)
Stack navigator for authentication flow:
- **LoginScreen**: Phone number entry
- **OTPScreen**: OTP verification
- **ProfileSetupScreen**: User profile setup

### Main Navigator (`navigation/MainNavigator.tsx`)
Bottom tab navigator with 4 tabs:
- **Home**: Dashboard and quick actions
- **History**: Scan history list
- **Tips**: Farming tips and advisories
- **More**: Settings and profile

### Scan Navigator (`navigation/ScanNavigator.tsx`)
Stack navigator for scan flow:
- **ScanScreen**: Camera interface
- **PreviewScreen**: Image review
- **ProcessingScreen**: Analysis loading
- **ResultsScreen**: Diagnosis and recommendations

---

## Screen Organization

### Auth Flow (`screens/auth/`)
- `LoginScreen.tsx`: Phone number input, navigates to OTP
- `OTPScreen.tsx`: 6-digit OTP verification
- `ProfileSetupScreen.tsx`: Name and location setup

### Main Tabs (`screens/main/`)
- `HomeScreen.tsx`: Dashboard with stats and scan button
- `HistoryScreen.tsx`: List of past scans
- `TipsScreen.tsx`: Farming tips and advisories
- `SettingsScreen.tsx`: Account and app settings

### Scan Flow (`screens/scan/`)
- `ScanScreen.tsx`: Camera view with overlay
- `PreviewScreen.tsx`: Confirm or retake image
- `ProcessingScreen.tsx`: AI analysis loading
- `ResultsScreen.tsx`: Disease diagnosis and recommendations

### Other
- `SplashScreen.tsx`: App startup screen

---

## Reusable Components (`components/`)

### Button (`Button.tsx`)
Props:
- `title: string`: Button text
- `onPress: () => void`: Click handler
- `variant?: 'primary' | 'secondary' | 'danger'`: Style variant
- `disabled?: boolean`: Disabled state

### Input (`Input.tsx`)
Props:
- `label?: string`: Input label
- `error?: string`: Error message
- Extends React Native `TextInputProps`

### Header (`Header.tsx`)
Props:
- `title: string`: Header title
- `onBackPress?: () => void`: Back button handler
- `rightAction?: { icon: any, onPress: () => void }`: Right action button

### LoadingSpinner (`LoadingSpinner.tsx`)
Props:
- `message?: string`: Optional loading message

### EmptyState (`EmptyState.tsx`)
Props:
- `icon: string`: Emoji icon
- `title: string`: Empty state title
- `message: string`: Empty state message

---

## Asset Integration

All images are imported via the **asset registry** (`utils/assetsRegistry.ts`):
```ts
import { Icons, Backgrounds, Overlays, Logos } from '../utils/assetsRegistry';

<Image source={Icons.home} />
<ImageBackground source={Backgrounds.splash} />
```

**Never import images via raw string paths.**

---

## Styling

- All styles use React Native `StyleSheet.create()`
- Primary color: `#4CAF50` (green)
- Accent color: `#2E7D32` (dark green)
- Danger color: `#F44336` (red)
- Background colors: `#F5F5F5`, `#FFFFFF`

---

## Data Flow (Offline-First)

1. **Local-first writes**: All user actions write to SQLite first
2. **Background sync**: Network operations happen asynchronously
3. **UI never blocks**: Network failures don't block user actions
4. **Logger**: All logging via `logger` utility (no direct `console.log`)

### Example: Scan Flow
1. User captures image → save locally to SQLite
2. Process image offline (or queue for sync)
3. Show results from local DB
4. Sync to Supabase in background

---

## Testing

All screens and components have import tests in `smart_farmer.tests/navigation.test.ts`.

Run tests:
```bash
npm run test -- smart_farmer.tests/navigation.test.ts
```

---

## Next Steps

1. **Camera integration**: Add `expo-camera` to ScanScreen
2. **SQLite integration**: Connect screens to database layer
3. **Auth state**: Implement auth persistence with AsyncStorage
4. **Sync logic**: Connect scan flow to sync queue
5. **Supabase sync**: Implement background sync

---

## File Structure

```
smart_farmer/
├── App.tsx (main entry with NavigationContainer)
├── navigation/
│   ├── RootNavigator.tsx
│   ├── AuthNavigator.tsx
│   ├── MainNavigator.tsx
│   └── ScanNavigator.tsx
├── screens/
│   ├── SplashScreen.tsx
│   ├── auth/
│   │   ├── LoginScreen.tsx
│   │   ├── OTPScreen.tsx
│   │   └── ProfileSetupScreen.tsx
│   ├── main/
│   │   ├── HomeScreen.tsx
│   │   ├── HistoryScreen.tsx
│   │   ├── TipsScreen.tsx
│   │   └── SettingsScreen.tsx
│   └── scan/
│       ├── ScanScreen.tsx
│       ├── PreviewScreen.tsx
│       ├── ProcessingScreen.tsx
│       └── ResultsScreen.tsx
├── components/
│   ├── Button.tsx
│   ├── Input.tsx
│   ├── Header.tsx
│   ├── LoadingSpinner.tsx
│   └── EmptyState.tsx
└── utils/
    ├── assetsRegistry.ts
    └── logger.ts
```

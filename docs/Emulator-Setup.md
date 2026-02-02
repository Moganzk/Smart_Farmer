# Android Emulator Setup for Smart Farmer

This guide explains how to test the Smart Farmer APK on an Android emulator **without Metro or localhost**.

## Prerequisites

### 1. Install Android SDK Command-Line Tools

**Windows (recommended via Android Studio):**
1. Download Android Studio from https://developer.android.com/studio
2. Open Android Studio → SDK Manager → SDK Tools tab
3. Check "Android SDK Command-line Tools"
4. Check "Android Emulator"
5. Check "Android SDK Platform-Tools"
6. Click Apply

**Or via standalone cmdline-tools:**
```powershell
# Download from: https://developer.android.com/studio#command-tools
# Extract to C:\Android\cmdline-tools\latest\
# Add to PATH:
$env:ANDROID_HOME = "C:\Android"
$env:PATH += ";$env:ANDROID_HOME\cmdline-tools\latest\bin"
$env:PATH += ";$env:ANDROID_HOME\platform-tools"
$env:PATH += ";$env:ANDROID_HOME\emulator"
```

### 2. Accept Android SDK Licenses
```powershell
sdkmanager --licenses
```

### 3. Install Required SDK Packages
```powershell
sdkmanager "platform-tools" "emulator" "platforms;android-34" "system-images;android-34;google_apis;x86_64"
```

## Create an Android Virtual Device (AVD)

```powershell
# List available system images
sdkmanager --list | Select-String "system-images"

# Create AVD (Pixel 6 with API 34)
avdmanager create avd -n Pixel_6_API_34 -k "system-images;android-34;google_apis;x86_64" -d "pixel_6"

# List created AVDs
emulator -list-avds
```

## Emulator Workflow (No Metro/Localhost)

### Step 1: Build Preview APK via EAS
```powershell
cd C:\Users\USER\Desktop\Smart_Farmer
npm run android:build:preview
# Or directly:
npx eas-cli build --profile preview --platform android
```

Wait for build to complete. Download the APK from Expo dashboard.

### Step 2: Start Emulator
```powershell
# List available emulators
npm run android:emulator:list
# Or: emulator -list-avds

# Start the emulator (in background)
Start-Process -FilePath "emulator" -ArgumentList "@Pixel_6_API_34", "-no-snapshot-load"
# Or: npm run android:emulator:start
```

### Step 3: Wait for Emulator Boot
```powershell
# Check device status
adb devices
# Should show: emulator-5554   device

# Wait for boot complete
adb wait-for-device
adb shell getprop sys.boot_completed
# Returns "1" when ready
```

### Step 4: Install APK
```powershell
# Install the downloaded APK
adb install -r "C:\path\to\smart-farmer-preview.apk"

# Or using npm script (pass path as argument):
npm run android:apk:install -- "C:\path\to\smart-farmer-preview.apk"
```

### Step 5: Launch the App
```powershell
adb shell am start -n com.smartfarmer.app/.MainActivity
```

## Debugging Startup Issues

### View Logs
```powershell
# All logs (verbose)
adb logcat

# Filter for React Native / Expo
adb logcat *:E ReactNative:V ReactNativeJS:V

# Filter for crashes
adb logcat -s AndroidRuntime:E

# Clear logs first
adb logcat -c
adb logcat *:E
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "Unable to load script" | This happens with dev builds expecting Metro. Use **preview** profile instead. |
| App crashes on startup | Check `adb logcat` for the stack trace. |
| White screen | Check if assets are bundled correctly with `npx expo export --platform android` |
| SQLite errors | Verify expo-sqlite plugin is in app.json |

### Force Stop & Clear Data
```powershell
adb shell am force-stop com.smartfarmer.app
adb shell pm clear com.smartfarmer.app
```

### Uninstall App
```powershell
adb uninstall com.smartfarmer.app
```

## Quick Reference Commands

```powershell
# Build preview APK
npm run android:build:preview

# List emulators
npm run android:emulator:list

# Start emulator
npm run android:emulator:start

# Check connected devices
npm run android:adb:devices

# Install APK
adb install -r path/to/app.apk

# View crash logs
adb logcat *:E | Select-Object -First 100

# Launch app
adb shell am start -n com.smartfarmer.app/.MainActivity
```

## Verification Checklist

- [ ] Emulator boots and shows in `adb devices`
- [ ] APK installs without errors
- [ ] App icon appears in launcher
- [ ] Splash screen displays
- [ ] Login screen loads
- [ ] No "Unable to load script" error
- [ ] Can enter phone number and proceed to OTP (dev mode: 123456)

## Notes

- **NO Metro server required** - The preview APK is self-contained
- **NO localhost/tunnel** - App runs completely offline
- **SQLite is local** - All data stays on device
- The preview build has the JS bundle embedded

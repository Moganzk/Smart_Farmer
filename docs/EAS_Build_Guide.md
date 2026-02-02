# EAS Build Configuration Guide

## Prerequisites

1. **EAS CLI Installation**
   ```bash
   npm install -g eas-cli
   ```

2. **Expo Account**
   - Create account at https://expo.dev
   - Login: `eas login`

3. **Project Setup**
   ```bash
   cd smart_farmer
   eas build:configure
   ```
   This will generate a unique project ID and update app.json

## Build Profiles

### Development Build
- Includes dev client and debugging tools
- Outputs APK for Android (direct install)
- For internal testing and development

```bash
eas build --profile development --platform android
```

### Preview Build
- Production-like build without app store optimization
- Outputs APK for Android
- For stakeholder testing and demos

```bash
eas build --profile preview --platform android
```

### Production Build
- App bundle format (AAB for Android)
- Ready for Google Play Store submission
- Fully optimized

```bash
eas build --profile production --platform android
```

## First Build Steps

### 1. Initialize EAS Project
```bash
cd smart_farmer
eas login
eas build:configure
```

This creates a project ID and links it to your Expo account.

### 2. Update app.json
After `eas build:configure`, copy the generated project ID into app.json:
```json
"extra": {
  "eas": {
    "projectId": "your-actual-project-id-here"
  }
}
```

### 3. Create Development Build
```bash
eas build --profile development --platform android
```

**What happens:**
- EAS servers pull your code
- Install all dependencies
- Compile native Android project
- Generate APK file
- Provide download link

**Duration**: 10-20 minutes for first build

### 4. Install on Device

**Option A: Direct Download**
1. EAS provides a QR code and URL
2. Open URL on Android device
3. Install APK (may need to allow "Install from unknown sources")

**Option B: EAS CLI**
```bash
eas build:run --profile development --platform android
```

## Environment Variables

Create `.env` file in `smart_farmer/`:

```bash
EXPO_PUBLIC_SUPABASE_URL=your_supabase_url
EXPO_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

For EAS builds, add secrets:
```bash
eas secret:create --scope project --name EXPO_PUBLIC_SUPABASE_URL --value "your_url"
eas secret:create --scope project --name EXPO_PUBLIC_SUPABASE_ANON_KEY --value "your_key"
```

## Testing Checklist

After installing development build on device:

### ✅ Camera & Permissions
- [ ] Camera permission prompt appears
- [ ] Camera view loads correctly
- [ ] Image capture works
- [ ] Preview shows captured image
- [ ] Image saves to file system

### ✅ SQLite & Offline
- [ ] Database initializes on first launch
- [ ] Auth flow saves to SQLite
- [ ] Scans save locally without network
- [ ] History loads from SQLite
- [ ] Tips load from SQLite
- [ ] App works in airplane mode

### ✅ Sync Queue
- [ ] Scans added to sync queue after save
- [ ] Queue processes when online
- [ ] Retry logic works on failure
- [ ] Sync status updates correctly

### ✅ Auth Flow
- [ ] Phone login works
- [ ] OTP verification works
- [ ] Profile setup saves to SQLite
- [ ] Auth persists after app restart
- [ ] Logout clears auth state

### ✅ Navigation
- [ ] All bottom tabs work
- [ ] Scan flow navigation works
- [ ] Back button behavior correct
- [ ] Deep linking (if implemented)

## Local Build (Alternative)

For faster iteration during development:

```bash
eas build --profile development --platform android --local
```

**Requirements:**
- Android Studio installed
- Android SDK configured
- JDK 17+ installed
- More disk space (10GB+)

**Pros:** Faster builds (5-10 minutes), no queue wait
**Cons:** More setup, machine-specific issues

## Build Optimization

### Reduce Build Time
1. Use `--local` flag for development
2. Cache dependencies: `eas build:configure`
3. Use `preview` profile for testing (skips dev client)

### Reduce APK Size
1. Enable Hermes engine (default in Expo SDK 50+)
2. Remove unused assets
3. Use production profile for final builds

## Troubleshooting

### Build Fails
- Check logs: `eas build:list` → click failed build
- Common issues:
  - Missing permissions in app.json
  - Invalid package name
  - Dependency version conflicts

### Can't Install APK
- Enable "Install from unknown sources" in Android settings
- Check device API level (min 21)
- Verify APK downloaded completely

### Camera Not Working
- Check permissions in app.json
- Verify expo-camera plugin is configured
- Test on physical device (not emulator)

### SQLite Issues
- Check if initDb() is called in App.tsx
- Verify database.ts exports are correct
- Test queries with actual device storage

## Next Steps After First Build

1. **Set up CI/CD**: Use EAS Build with GitHub Actions
2. **Internal Distribution**: Use EAS Submit for Play Store internal testing
3. **OTA Updates**: Configure EAS Update for JS-only changes
4. **Production Release**: Submit to Google Play Store

## Commands Reference

```bash
# View all builds
eas build:list

# View specific build
eas build:view [build-id]

# Cancel running build
eas build:cancel

# Configure new project
eas build:configure

# Run build on device
eas build:run --profile development --platform android

# View project info
eas project:info

# Manage secrets
eas secret:list
eas secret:create
eas secret:delete
```

## Resources

- [EAS Build Documentation](https://docs.expo.dev/build/introduction/)
- [App Config Reference](https://docs.expo.dev/versions/latest/config/app/)
- [Expo Camera Docs](https://docs.expo.dev/versions/latest/sdk/camera/)
- [SQLite with Expo](https://docs.expo.dev/versions/latest/sdk/sqlite/)

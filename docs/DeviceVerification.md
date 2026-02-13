# Device Verification Checklist

Use this checklist when running Smart Farmer on a **physical Android device**
to verify all fixes are working correctly.

---

## Prerequisites

```bash
cd smart_farmer
flutter pub get
flutter run          # connect device via USB / wireless debug
```

---

## 1. Firebase Diagnostics (logcat)

Open Android Studio Logcat or run `adb logcat -s flutter` and look for:

```
[Firebase] App name: [DEFAULT]
[Firebase] Project ID: <your-project-id>
[Firebase] Current user UID: <uid>
[Firebase] Firestore write OK
[Firebase] Firestore read OK — diagnostics doc exists
```

**Pass** ✅: All lines appear and no errors.
**Fail** ❌: `Firestore write FAILED` or `permission-denied` → check Security Rules
  and ensure the named database `smart-farmer-kenya` exists.

---

## 2. Auth — Registration / Login

| Step | Expected |
|------|----------|
| Sign up with new email + password | `AuthStatus.authenticated`, HomeScreen shows |
| Kill app & reopen | Auto-signed-in (Firebase persists session) |
| Sign out → Sign in with same creds | Success, no error banner |
| Sign up while offline | Auth may fail (expected) but app should not crash |

**Key log line** (debug):
```
[AuthProvider] Profile write failed (will retry): ...
```
This is **OK** — it means auth succeeded but Firestore was temporarily unavailable.
The yellow "Profile sync pending" banner should appear on HomeScreen.

---

## 3. AI Diagnosis (Scan)

| Step | Expected |
|------|----------|
| Take a photo of a leaf | "Analyzing…" spinner appears |
| Wait for result | Diagnosis card with name, confidence > 0, severity |
| Check logcat | `[Gemini] Status: 200`, confidence and name logged |

**If confidence = 0 or result = "Unanalyzed"**, check:
- `.env` has `GEMINI_API_KEY=...` (not empty)
- Logcat for `[Gemini] API key present (...)` — first 6 chars should show
- Logcat for `[Gemini] HTTP 4xx/5xx` — quota exceeded or bad key

---

## 4. Weather

| Step | Expected |
|------|----------|
| Open Weather tab | Current temp, city name, 5-day forecast |
| Toggle airplane mode → reopen tab | Stale data with "Offline" chip |
| Check logcat | `[Weather] API key present`, `[Weather] HTTP 200` |

**If error screen**:
- Check `.env` has `WEATHER_API_KEY=...`
- Check location permissions granted
- Logcat: `[Weather] _fetchCurrent lat=... lon=... → status 401` means invalid key

---

## 5. Notifications

| Step | Expected |
|------|----------|
| Open Notifications tab | List of notifications (or "No notifications yet") |
| Pull to refresh | Loading spinner, then updated list |

If empty and Firestore has data, check logcat for Firestore error codes.
Use **More → Seed Data** (debug builds) to populate test notifs.

---

## 6. Tips

| Step | Expected |
|------|----------|
| Open Tips tab | Grid/List of tips with categories |
| Check error banner | Should not appear if Firestore is reachable |

Use **More → Seed Data** to add 3 sample tips.

---

## 7. Offline Sync

| Step | Expected |
|------|----------|
| Scan a leaf **offline** | Result saved locally with `syncStatus: local_only` |
| Reconnect to network | Connectivity banner disappears, pending scans sync |
| Check History tab | Record's `syncStatus` changes to `synced` |

---

## 8. History Screen

| Step | Expected |
|------|----------|
| Open History tab first time | Shimmer loading placeholder, then list |
| Pull to refresh | List stays visible (no blink), updates in-place |
| Delete a scan | Card removed from list |

---

## 9. Permissions

The app requests at runtime:
- **Camera** — for scanning leaves
- **Location** — for weather (city detection)
- **Storage / Photos** — for picking images from gallery

Verify each permission dialog appears on first use. If denied, the
corresponding feature should show a user-friendly error, not crash.

---

## Quick command reference

```bash
# Run all unit tests
flutter test

# Run a single test file
flutter test test/gemini_parse_test.dart

# Run on device with verbose logs
flutter run --verbose

# Filter logcat for app logs
adb logcat -s flutter | grep -E "\[Firebase\]|\[Gemini\]|\[Weather\]|\[Auth\]"
```

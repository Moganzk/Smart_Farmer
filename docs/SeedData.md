# Seed Data — Firestore Collections

This document describes the Firestore structure expected by Smart Farmer,
and how to populate it for development and testing.

> **Database**: Named Firestore database `smart-farmer-kenya`
> (not the `(default)` database).

---

## 1. `tips` collection

Each document in `tips` represents a farming tip shown in the **Tips** tab.

| Field       | Type      | Description                                  |
|-------------|-----------|----------------------------------------------|
| `title`     | `string`  | Short headline (e.g. "Mulch your beds")      |
| `body`      | `string`  | Full tip text                                |
| `category`  | `string`  | Category key: `soil`, `pest`, `water`, etc.  |
| `createdAt` | `timestamp` | Firestore server timestamp                 |

### Example document

```json
{
  "title": "Rotate your crops",
  "body": "Alternate between legumes and cereals each season to preserve soil nutrients.",
  "category": "soil",
  "createdAt": "2025-06-01T00:00:00Z"
}
```

---

## 2. `notifications/{uid}/items` sub-collection

Per-user notifications. Each document is one notification.

| Field       | Type      | Description                       |
|-------------|-----------|-----------------------------------|
| `title`     | `string`  | Notification headline             |
| `body`      | `string`  | Detailed message text             |
| `read`      | `bool`    | Whether the user has seen it      |
| `createdAt` | `timestamp` | Firestore server timestamp      |

### Example document (under `notifications/<USER_UID>/items`)

```json
{
  "title": "Rain expected tomorrow",
  "body": "Consider covering seed beds.",
  "read": false,
  "createdAt": "2025-06-15T08:00:00Z"
}
```

---

## 3. Quick-seed from the app (debug only)

In **debug builds**, open **More → Seed Data**.
This writes 3 sample tips and 3 sample notifications into the named database.

Alternatively, use the Firebase Console:

1. Open <https://console.firebase.google.com/> → your project.
2. Select **Firestore Database** → choose the **`smart-farmer-kenya`** database.
3. Manually add documents following the schemas above.

---

## 4. Firestore Security Rules

Ensure the named database has rules that allow authenticated reads:

```
rules_version = '2';
service cloud.firestore {
  match /databases/smart-farmer-kenya/documents {
    // Tips: any authenticated user can read
    match /tips/{tipId} {
      allow read: if request.auth != null;
      allow write: if false; // admin-only in production
    }

    // Notifications: user can read/write own items
    match /notifications/{uid}/items/{itemId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // User profiles
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Scans
    match /scans/{scanId} {
      allow read, write: if request.auth != null;
    }

    // Diagnostics (debug)
    match /diagnostics/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

---

## 5. Firebase Console checklist

- [ ] Named database `smart-farmer-kenya` exists
  (Firestore → *Create database* → Database ID: `smart-farmer-kenya`)
- [ ] Security rules deployed for the named database
- [ ] At least 1 tip document exists in `tips`
- [ ] Auth sign-in methods enabled (Email/Password, Phone)

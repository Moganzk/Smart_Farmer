📱 Crop Disease Detection & Advisory App

An offline-first mobile application that enables farmers to detect crop diseases using images, receive expert advisories, and access farming tips — with seamless synchronization to an online backend for analytics, notifications, and administration.

This project is designed to work fully offline on the farmer’s device and sync intelligently when connectivity is available.
## 🚀 Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- EAS CLI (`npm install -g eas-cli`)
- Physical Android device (no emulators - offline-first testing)

### Installation

```bash
# Clone the repository
git clone https://github.com/Moganzk/Smart_Farmer.git
cd Smart_Farmer

# Install root dependencies
npm install

# Install mobile app dependencies
cd smart_farmer && npm install && cd ..

# Install test dependencies
cd smart_farmer.tests && npm install && cd ..
```

### Environment Setup

```bash
# Copy example env files and fill in your Supabase credentials
cp smart_farmer/.env.example smart_farmer/.env
cp smart_farmer/.env.local.example smart_farmer/.env.local

# Edit the files with your Supabase project details
```

### Running Tests

```bash
# From repo root
npm test              # Unit tests (100 tests)
npm run test:integration  # Integration tests (88 tests)
npm run test:all      # All tests (188 tests)
```

### Building for Device

```bash
# Build Android development build (requires EAS account)
cd smart_farmer
npm run android:build

# Or from root
npm run android:build
```

> ⚠️ **No localhost testing** - This app is designed for physical device testing only. Use `eas build` to create development builds.

---
🚀 Core Philosophy

This system follows a strict Offline-First Architecture.

The mobile device is the source of truth.
The backend exists for synchronization, analytics, admin tools, and notifications — not for basic app functionality.

The app must:

Work without internet

Never block the user due to connectivity

Sync data safely when online

Avoid localhost, tunnels, or dev-only environments

🧠 High-Level Architecture
Mobile App (Primary System)

Runs fully offline

Stores all operational data locally using SQLite

Handles scans, history, tips, notifications, and user profile locally

Queues sync operations when offline

Backend (Sync + Admin System)

Built using Supabase

Acts as:

Sync target

Admin dashboard data source

Notification trigger engine

Cloud image storage

Never required for basic app usage

🧱 Technology Stack
Frontend (Mobile App)

React Native (Expo)

SQLite (local database)

Expo Camera & Media APIs

Expo Updates (OTA UI updates)

Runs as a standalone build on physical devices

No localhost testing

No tunnels

Backend

Supabase

Postgres Database

Authentication

Storage (images)

Edge Functions (optional)

Admin dashboard consumes Supabase data only

📴 Offline-First Data Strategy
Local Database (SQLite)

All data is written locally first:

Users

Scans

Diagnoses

Tips

Notifications

Sync queue

No operation depends on network availability.

Sync Behavior

Each record includes:

Local ID

Device ID

Sync status

Versioning metadata

When online:

Unsynced records are pushed to Supabase

Remote updates are pulled down

Conflicts are resolved using last-write-wins or version checks

📲 Application Features
Farmer App Features

Phone number authentication

Crop disease scanning via camera or gallery

Offline image storage

AI-based disease detection (local or server-side)

Clear diagnosis results with confidence scores

Treatment & prevention advisories

Scan history (fully offline)

Farming tips & educational content

In-app notifications

Language selection

Profile management

Offline status awareness

Admin Dashboard Features

View registered users

View disease statistics

View scan analytics

Manage advisories & tips

Trigger notifications

Monitor system activity

🧭 App Navigation Overview
Bottom Navigation (Farmer App)

Home (Dashboard)

History

Tips

More (Settings)

Stack Navigation

Authentication flow

Scan → Preview → Processing → Results

Notifications

Profile editing

Help & support

🔔 Notifications System
Types of Notifications

New disease detected

Updated advisory

Farming tips

Offline scans processed

System messages

Behavior

Stored locally in SQLite

Synced from Supabase when online

Unread/read state maintained locally

Badge count shown in UI

📷 Image Handling

Images are captured or selected locally

Stored locally immediately

Compressed before upload

Uploaded to Supabase Storage when online

Linked to scan records via metadata

App never blocks if upload fails

🔐 Authentication & Security

Phone number authentication

Session stored securely on device

Backend rules restrict access by user ID

Admin access is role-based

No sensitive logic lives on the client

🌍 Localization & Accessibility

Multi-language support (English, Kiswahili)

Language preference stored locally

Content cached for offline access

Simple, readable UI for low-literacy users

Large buttons, minimal text, visual cues

🧪 Testing Strategy
Development & Testing Rules

❌ No localhost testing

❌ No tunnels

✅ Test only on physical devices

✅ Use production-like builds

Testing Workflow

Build app using Expo/EAS

Install directly on phone

Test offline scenarios

Test online sync behavior

Push UI updates via OTA when needed

🔄 Data Sync Rules (Non-Negotiable)

Local write always succeeds

Sync never blocks UI

Sync failures are retried

User is informed but not interrupted

Backend data must never override unsynced local data

📦 Deployment Strategy
Mobile App

Built using Expo Application Services

Distributed as APK / AAB

OTA updates used for UI & logic changes

Backend

Supabase project deployed once

Schema changes versioned

Admin dashboard reads from Supabase only

🧩 Future-Ready Design

This system is designed to support:

More crops

More disease models

Expert chat

SMS alerts

Government or NGO dashboards

Regional analytics

Multi-device sync per user

Without rewriting the core architecture.

🧠 Key Design Decisions (Why This Works)

SQLite ensures true offline capability

Supabase accelerates backend delivery

Sync-first thinking prevents data loss

Device-centric design fits rural environments

No reliance on unstable networks

Clear separation between farmer app and admin tools

📌 Final Note

This is not a demo app.
This is a field-ready, rural-proof, offline-first system designed for real-world usage where connectivity is unreliable and user patience is limited.

If the app works offline, it works everywhere.
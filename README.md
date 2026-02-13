# 🌾 Smart Farmer Kenya

A Flutter + Firebase mobile application for smallholder farmers in Kenya. Provides AI-powered crop disease diagnosis, real-time weather forecasts, and offline-first data synchronization.

![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)
![License](https://img.shields.io/badge/License-MIT-green)
![Tests](https://img.shields.io/badge/Tests-140%20passing-brightgreen)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **AI Crop Diagnosis** | Capture or upload images; AI (Gemini/Groq) identifies diseases & recommends treatments |
| **Pluggable Weather** | Real-time 5-day forecasts from Google Weather API, OpenWeatherMap, or Open-Meteo |
| **Auto-Notifications** | System-generated alerts for scan events, sync status, and severe weather |
| **Offline-First Sync** | Local SQLite cache with background Firestore synchronization |
| **Firebase Auth** | Email/password authentication with secure session management |
| **Dashboard Analytics** | Scan history, disease statistics, and weather trends |

---

## 🛠 Tech Stack

- **Framework:** Flutter SDK ^3.11.0 (Dart)
- **Backend:** Firebase (Auth, Firestore, Storage)
- **State Management:** Provider ^6.1.4
- **Local Database:** SQLite via `sqflite`
- **Weather APIs:** Google Weather (default), OpenWeatherMap, Open-Meteo
- **AI Providers:** Google Gemini, Groq
- **Testing:** 140 unit tests

---

## 📁 Project Structure

```
smart_farmer/
├── lib/
│   ├── main.dart                 # App entry point + Providers
│   ├── firebase_options.dart     # Firebase config
│   ├── core/                     # Shared utilities & services
│   │   ├── services/             # AI, Weather, Sync, Notifications
│   │   └── utils/                # Validators, Logger, Extensions
│   ├── features/                 # Feature modules
│   │   ├── auth/                 # Authentication screens & logic
│   │   ├── diagnosis/            # Scan flow & AI diagnosis
│   │   ├── weather/              # Weather providers & UI
│   │   ├── notifications/        # Notifications system
│   │   └── tips/                 # Farming tips
│   └── shell/                    # Navigation shell & bottom nav
├── test/                         # Unit tests (140 tests)
├── assets/                       # Icons, logos
└── android/, ios/, web/, ...     # Platform-specific code
```

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.11+
- Dart SDK (bundled with Flutter)
- Firebase project configured
- API keys for weather and AI services

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/smart-farmer.git
cd smart-farmer/smart_farmer

# Install dependencies
flutter pub get

# Create .env file (copy from example)
cp .env.example .env
# Edit .env with your API keys

# Run the app
flutter run
```

---

## 🔐 Environment Variables

Create a `.env` file in `smart_farmer/` with the following:

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key for AI diagnosis | Yes |
| `GROQ_API_KEY` | Groq API key (fallback AI provider) | Optional |
| `WEATHER_PROVIDER` | Weather provider: `google`, `openweathermap`, or `openmeteo` | Yes |
| `GOOGLE_WEATHER_API_KEY` | Google Weather API key | If provider=google |
| `WEATHER_API_KEY` | OpenWeatherMap API key | If provider=openweathermap |

**Example `.env`:**
```env
GEMINI_API_KEY=your_gemini_key
GROQ_API_KEY=your_groq_key
WEATHER_PROVIDER=google
GOOGLE_WEATHER_API_KEY=your_google_weather_key
WEATHER_API_KEY=your_owm_key
```

> ⚠️ Never commit `.env` to version control. Use `.env.example` as a template.

---

## 🧪 Running Tests

```bash
cd smart_farmer

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/auth_provider_test.dart
```

**Current Status:** 140 tests passing ✅

---

## 📱 Build & Release

### Debug APK
```bash
flutter build apk --debug
```

### Release APK
```bash
flutter build apk --release
```

### App Bundle (Play Store)
```bash
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🗄 Firestore Schema

Database: `smart-farmer-kenya`

| Collection | Document Fields |
|------------|-----------------|
| `users` | `uid`, `email`, `displayName`, `createdAt` |
| `scans` | `id`, `userId`, `imagePath`, `diagnosis`, `confidence`, `recommendations`, `timestamp`, `location` |
| `notifications` | `id`, `userId`, `title`, `body`, `type`, `read`, `timestamp` |
| `tips` | `id`, `title`, `content`, `category`, `timestamp` |

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Weather 401 Unauthorized | Check API key validity; ensure Weather API is enabled in Google Cloud |
| Firebase connection error | Verify `google-services.json` is in `android/app/`; check Firebase project config |
| AI diagnosis timeout | Check internet connection; API may be rate-limited |
| Offline sync not working | Ensure Firestore rules allow authenticated writes |
| Tests failing on CI | Install `sqflite_common_ffi` for headless SQLite |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -m "Add your feature"`
4. Push to branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Copyright © 2025 Samuel Mogaka Nyamwange (Moganzk)**

---

## 👨‍💻 Author

**Samuel Mogaka Nyamwange**  
GitHub: [@Moganzk](https://github.com/Moganzk)

---

<p align="center">
  <i>Empowering Kenyan farmers with AI-driven agriculture 🌱</i>
</p>

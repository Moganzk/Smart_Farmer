# App Icon

Place your app icon images in this directory:

- `app_icon.png` — 1024×1024 main icon (used for iOS and Android legacy)
- `app_icon_foreground.png` — 1024×1024 foreground layer for Android adaptive icons

The background color for the adaptive icon is set to `#0A0E1A` (app background) in `pubspec.yaml`.

## Generate Icons

After placing your images, run:

```bash
dart run flutter_launcher_icons
```

This will auto-generate all platform-specific icon sizes.

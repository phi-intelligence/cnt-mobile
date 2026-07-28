# CNT Media Platform — Mobile

Cross-platform **Flutter** mobile app for the **Christ New Tabernacle (CNT) Media Platform** — a
faith-based media and community application for the Christ New Tabernacle church.

It combines on-demand media streaming (podcasts, music, movies, Bible stories), creator tools
(recording + on-device audio/video editing), real-time communication (live streaming, video
meetings, an AI voice agent), a social community feed, events with maps, Stripe giving, push
notifications, and a full admin/moderation back office — all in one app.

> 📄 **Full developer documentation:** [`mobile/frontend/dev_docs/APPLICATION_SUMMARY.md`](mobile/frontend/dev_docs/APPLICATION_SUMMARY.md)

---

## Highlights

- **Platforms:** Android + iOS (mobile-first; web is deployed separately)
- **App ID:** `com.christtabernacle.cntmedia` · **Version:** `1.0.0+1`
- **Auth:** email/password, OTP-verified signup, Google Sign-In, JWT access + refresh tokens
- **Media:** podcasts, music, movies/animated Bible stories, Bible PDF reader, playlists,
  favorites, offline downloads, global audio player
- **Create:** audio/video podcast recording, FFmpeg-based on-device editing, resumable drafts,
  community posts, quotes
- **Real-time:** LiveKit video meetings (with Picture-in-Picture), live streaming, AI voice agent
- **More:** community feed, events with map location picker, Stripe donations, in-app support
  center, push notifications, admin dashboard + Google Drive content import

## Tech stack

Flutter · `provider` / `flutter_riverpod` · `http` / `dio` / WebSockets · `livekit_client` ·
`just_audio` / `video_player` · `ffmpeg_kit_flutter_new` · Firebase Cloud Messaging ·
`flutter_stripe` · `flutter_map` / `geolocator` · `flutter_secure_storage` / `sqflite` ·
Google Sign-In + Drive APIs.

## Repository layout

```
cnt-mobile/
└── mobile/
    └── frontend/            # Flutter application
        ├── lib/             # Dart source (config, navigation, theme, models,
        │                    #   services, providers, screens, widgets, utils)
        ├── android/ ios/ web/
        ├── assets/
        ├── dev_docs/        # Developer documentation (see APPLICATION_SUMMARY.md)
        ├── env.example      # Environment template
        └── pubspec.yaml
```

## Getting started

```bash
cd mobile/frontend

# 1. Configure environment (set ENVIRONMENT=development for local backend)
cp env.example .env

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device / emulator
flutter run
```

### Configuration

All backend URLs are resolved at runtime via `.env` (precedence: `--dart-define` > `.env` >
development defaults). Key variables:

| Variable | Purpose |
|----------|---------|
| `ENVIRONMENT` | `development` or `production` |
| `API_BASE_URL` | REST API base (`.../api/v1`) |
| `WEBSOCKET_URL` | Real-time WebSocket endpoint |
| `MEDIA_BASE_URL` | Media/CDN base URL |
| `LIVEKIT_WS_URL` / `LIVEKIT_HTTP_URL` | LiveKit meeting + streaming endpoints |

In `development`, URLs auto-default to `localhost` (or `10.0.2.2` on the Android emulator). Push
notifications require Firebase platform config files (`google-services.json` /
`GoogleService-Info.plist`).

For architecture, feature breakdowns, the services layer, and API surface, see
[`mobile/frontend/dev_docs/APPLICATION_SUMMARY.md`](mobile/frontend/dev_docs/APPLICATION_SUMMARY.md).

---

## Release builds (Android)

Release APKs/AABs must be signed with an upload keystore (not the debug key).

### 1. One-time signing setup

```bash
cd mobile/frontend
chmod +x scripts/setup_android_signing.sh scripts/release_build.sh
./scripts/setup_android_signing.sh
```

This creates (gitignored):

| File | Purpose |
|------|---------|
| `android/upload-keystore.jks` | Upload keystore for Play Store |
| `android/key.properties` | Gradle signing config |
| `android/keystore.credentials` | Local password backup |

**Back up the keystore and passwords.** You need the same key for every Play Store update.

Register the release **SHA-1** / **SHA-256** (printed by the setup script) in Firebase and Google Cloud Console for Google Sign-In on release builds.

### 2. Configure production URLs

```bash
cp env.example .env
# Set ENVIRONMENT=production and your API / media / LiveKit URLs
```

`release_build.sh` reads `.env` and passes values as `--dart-define` for release builds.

### 3. Build

```bash
# Universal + per-ABI APKs (sideload / testing)
./scripts/release_build.sh apk

# Google Play upload
./scripts/release_build.sh appbundle
```

Outputs:

- APK: `build/app/outputs/flutter-apk/`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

Debug symbols for crash deobfuscation: `build/obfuscation/` (store securely, do not commit).

### Custom passwords (CI / team)

```bash
CNT_KEYSTORE_STORE_PASSWORD='...' CNT_KEYSTORE_KEY_PASSWORD='...' ./scripts/setup_android_signing.sh
```

### iOS

iOS release signing requires Xcode on macOS (Apple Developer certificate + provisioning profile). Use `flutter build ipa` from a Mac with signing configured in `ios/Runner.xcworkspace`.

### App icon

Launcher icons are copied into the project (Android `mipmap-*`, iOS `AppIcon.appiconset`, web `web/icons/`). Source master: `assets/images/icon.png` (512×512 from IconKitchen).

To replace icons: generate a new IconKitchen pack, then copy:

- `android/res/mipmap-*` → `android/app/src/main/res/mipmap-*`
- `ios/*.png` + `Contents.json` → `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `web/*` → `web/icons/` and `web/favicon.png`

Do **not** run `dart run flutter_launcher_icons` unless you intend to regenerate from `assets/images/icon.png` (it is disabled in `pubspec.yaml`).

### Firebase & Google Sign-In

The app uses Firebase for push notifications and Google Sign-In on Android.

**If you see Firebase / OAuth errors on release builds:**

1. Open [Firebase Console](https://console.firebase.google.com/) → project **cnt-media-platform**
2. Project Settings → Your apps → Android (`com.christtabernacle.cntmedia`)
3. Add **SHA-1** and **SHA-256** for your **debug** and **release** signing keys
4. Download a new `google-services.json` and replace `android/app/google-services.json`
5. Confirm `oauth_client` is **not empty** in the new file (required for Google Sign-In)

Print release keystore fingerprints:

```bash
cd mobile/frontend
keytool -list -v -keystore android/upload-keystore.jks -alias upload \
  -storepass "$(grep storePassword android/key.properties | cut -d= -f2)"
```

Debug keystore:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

Firebase options are also in `lib/firebase_options.dart` (from `google-services.json`). After replacing `google-services.json`, regenerate with FlutterFire CLI or update that file manually.

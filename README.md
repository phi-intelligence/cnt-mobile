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

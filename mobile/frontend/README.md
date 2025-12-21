# CNT Media Platform Frontend

Flutter application for the Christ New Tabernacle media platform.

## Setup

1. Install Flutter if not already installed: https://flutter.dev/docs/get-started/install

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run -d chrome  # For web
flutter run            # For mobile
```

## Project Structure

```
lib/
  models/         # Data models
  services/       # API, WebSocket, Storage services
  providers/      # State management
  screens/        # Page screens
  widgets/        # Reusable widgets
  utils/          # Helpers and constants
  theme/          # Theme configuration
main.dart        # Entry point
```


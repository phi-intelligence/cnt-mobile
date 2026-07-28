#!/usr/bin/env bash
# Production release build with Dart obfuscation and env from .env or environment.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ANDROID_KEY_PROPS="$ROOT/android/key.properties"
OBFUSCATE_DIR="${OBFUSCATE_DIR:-build/obfuscation}"
TARGET="${1:-apk}" # apk | appbundle

if [[ ! -f "$ANDROID_KEY_PROPS" ]]; then
  echo "Missing $ANDROID_KEY_PROPS"
  echo "Run: ./scripts/setup_android_signing.sh"
  exit 1
fi

# Build --dart-define flags from .env (production URLs) when present.
DART_DEFINES=()
ENV_FILE="$ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" || "$line" != *=* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      ENVIRONMENT|API_BASE_URL|WEBSOCKET_URL|MEDIA_BASE_URL|LIVEKIT_WS_URL|LIVEKIT_HTTP_URL|ORGANIZATION_RECIPIENT_USER_ID)
        DART_DEFINES+=(--dart-define="${key}=${value}")
        ;;
    esac
  done <"$ENV_FILE"
fi

# Default to production when no ENVIRONMENT dart-define was loaded.
has_environment=false
for arg in "${DART_DEFINES[@]}"; do
  [[ "$arg" == --dart-define=ENVIRONMENT=* ]] && has_environment=true
done
if [[ "$has_environment" == false ]]; then
  DART_DEFINES+=(--dart-define=ENVIRONMENT=production)
fi

COMMON_FLAGS=(
  --release
  --obfuscate
  --split-debug-info="$OBFUSCATE_DIR"
  "${DART_DEFINES[@]}"
)

case "$TARGET" in
  apk)
    flutter build apk "${COMMON_FLAGS[@]}" "${@:2}"
    echo ""
    echo "Release APK(s): build/app/outputs/flutter-apk/"
    ;;
  appbundle)
    flutter build appbundle "${COMMON_FLAGS[@]}" "${@:2}"
    echo ""
    echo "Release AAB: build/app/outputs/bundle/release/app-release.aab"
    ;;
  *)
    echo "Usage: $0 [apk|appbundle] [extra flutter build args...]"
    exit 1
    ;;
esac

echo "Store debug symbols from $OBFUSCATE_DIR securely (not in git)."

#!/usr/bin/env bash
# Production release build with Dart obfuscation.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OBFUSCATE_DIR="${OBFUSCATE_DIR:-build/obfuscation}"

flutter build apk --release \
  --obfuscate \
  --split-debug-info="$OBFUSCATE_DIR" \
  "$@"

echo "Release APK built. Store debug symbols from $OBFUSCATE_DIR securely (not in git)."

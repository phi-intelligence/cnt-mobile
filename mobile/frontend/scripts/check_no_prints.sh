#!/usr/bin/env bash
# CI gate: fail if raw print() is used in lib/ (use AppLogger instead).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MATCHES=$(grep -R --include='*.dart' --exclude='app_logger.dart' -n '\bprint(' lib/ 2>/dev/null || true)
if [ -n "$MATCHES" ]; then
  echo "$MATCHES"
  echo "ERROR: print() found in lib/. Use AppLogger.debug/info/warning/error instead."
  exit 1
fi

echo "OK: no print() in lib/"

#!/usr/bin/env bash
# Generate Android upload keystore + android/key.properties for release builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/android"
KEYSTORE="$ANDROID_DIR/upload-keystore.jks"
KEY_PROPS="$ANDROID_DIR/key.properties"
CREDENTIALS_FILE="$ANDROID_DIR/keystore.credentials"

KEY_ALIAS="${CNT_KEY_ALIAS:-upload}"
STORE_PASSWORD="${CNT_KEYSTORE_STORE_PASSWORD:-}"
KEY_PASSWORD="${CNT_KEYSTORE_KEY_PASSWORD:-}"
VALIDITY_DAYS="${CNT_KEYSTORE_VALIDITY_DAYS:-10000}"
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
  esac
done

if [[ -f "$KEYSTORE" && -f "$KEY_PROPS" && "$FORCE" != true ]]; then
  echo "Android signing already configured:"
  echo "  $KEYSTORE"
  echo "  $KEY_PROPS"
  echo "Run with --force to regenerate (destroys existing keystore)."
  exit 0
fi

if [[ "$FORCE" == true ]]; then
  rm -f "$KEYSTORE" "$KEY_PROPS" "$CREDENTIALS_FILE"
fi

if [[ -z "$STORE_PASSWORD" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    STORE_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"
  else
    echo "Set CNT_KEYSTORE_STORE_PASSWORD (and optionally CNT_KEYSTORE_KEY_PASSWORD), or install openssl."
    exit 1
  fi
fi
if [[ -z "$KEY_PASSWORD" ]]; then
  KEY_PASSWORD="$STORE_PASSWORD"
fi
# Modern keytool writes PKCS12 (.jks); store and key password must match.
KEY_PASSWORD="$STORE_PASSWORD"

mkdir -p "$ANDROID_DIR"

keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY_DAYS" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -dname "CN=Christ New Tabernacle, OU=Mobile, O=Christ New Tabernacle, L=Unknown, ST=Unknown, C=US"

cat >"$KEY_PROPS" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=upload-keystore.jks
EOF

cat >"$CREDENTIALS_FILE" <<EOF
# Local-only backup of Android signing credentials (gitignored).
# Back up this file securely — you need it for every Play Store update.
storeFile=$KEYSTORE
keyAlias=$KEY_ALIAS
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
EOF
chmod 600 "$CREDENTIALS_FILE" "$KEY_PROPS" "$KEYSTORE"

echo ""
echo "Android release signing configured."
echo "  Keystore:      $KEYSTORE"
echo "  Properties:    $KEY_PROPS"
echo "  Credentials:   $CREDENTIALS_FILE"
echo ""
echo "Release keystore SHA-1 (register in Firebase / Google Cloud for release builds):"
keytool -list -v -keystore "$KEYSTORE" -alias "$KEY_ALIAS" -storepass "$STORE_PASSWORD" 2>/dev/null \
  | awk '/SHA1:|SHA256:/{print "  " $0}'
echo ""
echo "Build release APK:"
echo "  ./scripts/release_build.sh apk"
echo "Build Play Store bundle:"
echo "  ./scripts/release_build.sh appbundle"

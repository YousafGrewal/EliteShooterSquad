#!/bin/bash
set -euo pipefail  # safer strict mode

echo "🚀 Starting upload to App Store Connect..."

# --- Configuration ---
IPA_DIR="${WORKSPACE:-$PWD}/.build/last"
IPA_PATH="${IPA_PATH:-}"

# Auto-detect IPA if not provided
if [ -z "$IPA_PATH" ]; then
  IPA_PATH=$(find "$IPA_DIR" -type f -name "*.ipa" | head -n 1 || true)
fi

API_KEY_ID="${APP_STORE_CONNECT_API_KEY:-}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-}"
PRIVATE_KEY="${APP_STORE_CONNECT_PRIVATE_KEY:-}"

# --- Validate Required Secrets ---
if [ -z "$API_KEY_ID" ]; then
  echo "❌ Missing APP_STORE_CONNECT_API_KEY"
  exit 1
fi

if [ -z "$ISSUER_ID" ]; then
  echo "❌ Missing APP_STORE_CONNECT_ISSUER_ID"
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "❌ Missing APP_STORE_CONNECT_PRIVATE_KEY"
  exit 1
fi

# --- Debug IPA Directory ---
if [ ! -d "$IPA_DIR" ]; then
  echo "❌ IPA directory not found: $IPA_DIR"
  exit 1
fi

echo "📁 IPA directory contents:"
find "$IPA_DIR" -type f -name "*.ipa" -exec ls -lh {} \;

# --- Validate IPA File ---
if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
  echo "❌ No .ipa file found in $IPA_DIR"
  echo "💡 Ensure Unity build produces an IPA archive."
  exit 1
fi

echo "✅ IPA found: $IPA_PATH"

# --- Save Private Key ---
KEY_DIR="$HOME/.appstoreconnect/private_keys"
KEY_FILE="$KEY_DIR/AuthKey_$API_KEY_ID.p8"

mkdir -p "$KEY_DIR"

echo "🔐 Writing private key to: $KEY_FILE"
# Replace literal \n with actual newlines
echo "${PRIVATE_KEY//\\n/$'\n'}" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# Validate PKCS#8 format
if ! openssl pkcs8 -nocrypt -in "$KEY_FILE" -out /dev/null 2>/dev/null; then
  echo "❌ Invalid private key format. Check your Unity Cloud Build secret."
  exit 1
fi

echo "✅ Private key saved and validated."

# --- Upload with iTMSTransporter (supported tool) ---
echo "📤 Uploading IPA to TestFlight via iTMSTransporter..."

if xcrun iTMSTransporter -m upload \
  -assetFile "$IPA_PATH" \
  -apiKey "$API_KEY_ID" \
  -apiIssuer "$ISSUER_ID"; then
  echo "✅ Successfully uploaded to App Store Connect!"
  echo "📲 Your build is now processing. Check TestFlight dashboard:"
  echo "👉 https://appstoreconnect.apple.com/apps"
else
  echo "❌ Upload failed! See error above."
  exit 1
fi

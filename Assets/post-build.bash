#!/bin/bash
set -euo pipefail

echo "🚀 Starting upload to App Store Connect..."

# --- Install Fastlane if not present ---
if ! command -v fastlane &> /dev/null; then
  echo "📦 Installing fastlane..."
  gem install fastlane --no-document
fi

# --- Configuration ---
IPA_DIR="${WORKSPACE:-$PWD}/.build/last}"
IPA_PATH="${IPA_PATH:-}"

# Auto-detect IPA if not provided
if [ -z "$IPA_PATH" ]; then
  IPA_PATH=$(find "$IPA_DIR" -type f -name "*.ipa" | head -n 1 || true)
fi

# Load credentials
API_KEY_ID="${APP_STORE_CONNECT_KEY_ID:-}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-}"
PRIVATE_KEY="${APP_STORE_CONNECT_PRIVATE_KEY:-}"

# --- Validate Required Secrets ---
if [ -z "$API_KEY_ID" ]; then
  echo "❌ Missing environment variable: APP_STORE_CONNECT_KEY_ID"
  exit 1
fi

if [ -z "$ISSUER_ID" ]; then
  echo "❌ Missing environment variable: APP_STORE_CONNECT_ISSUER_ID"
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "❌ Missing environment variable: APP_STORE_CONNECT_PRIVATE_KEY"
  exit 1
fi

# --- Validate IPA File ---
if [ ! -d "$IPA_DIR" ]; then
  echo "❌ IPA directory not found: $IPA_DIR"
  exit 1
fi

echo "📁 IPA directory contents:"
find "$IPA_DIR" -type f -name "*.ipa" -exec ls -lh {} \;

if [ ! -f "$IPA_PATH" ]; then
  echo "❌ No .ipa file found at: $IPA_PATH"
  exit 1
fi

echo "✅ IPA found: $IPA_PATH"

# --- Write .p8 Key File ---
KEY_DIR="$HOME/.appstoreconnect"
KEY_P8_FILE="$KEY_DIR/AuthKey.p8"

mkdir -p "$KEY_DIR"

echo "🔐 Writing API key to $KEY_P8_FILE..."

# Use printf instead of echo -e (more reliable)
printf '%b\n' "${PRIVATE_KEY}" > "$KEY_P8_FILE"

# Verify it was written
if ! grep -q "PRIVATE KEY" "$KEY_P8_FILE"; then
  echo "❌ Failed to write valid private key! Content:"
  cat "$KEY_P8_FILE"
  exit 1
fi

echo "✅ Key written successfully."

chmod 600 "$KEY_P8_FILE"
echo "🔒 Set permissions on $KEY_P8_FILE"

# --- Upload to App Store Connect ---
echo "📤 Uploading IPA via Fastlane..."

if fastlane deliver \
  --api_key_path "$KEY_P8_FILE" \
  --key_id "$API_KEY_ID" \
  --issuer_id "$ISSUER_ID" \
  --ipa "$IPA_PATH" \
  --skip_metadata true \
  --skip_screenshots true \
  --force \
  --verbose; then

  echo "✅ Successfully uploaded to App Store Connect!"
  echo "📲 Check TestFlight: https://appstoreconnect.apple.com/apps"

else
  echo "❌ Upload failed!"
  echo "💡 Check:"
  echo "   • API key ID, issuer ID, and private key are correct"
  echo "   • Bundle ID matches your app"
  echo "   • You have App Manager access in App Store Connect"
  exit 1
fi

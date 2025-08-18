#!/bin/bash
set -euo pipefail

# Ensure fastlane exists
if ! command -v fastlane &> /dev/null; then
  echo "📦 Installing fastlane..."
  gem install fastlane --no-document
fi

echo "🚀 Starting upload to App Store Connect..."

# --- Configuration ---
IPA_DIR="${WORKSPACE:-$PWD}/.build/last"
IPA_PATH="${IPA_PATH:-}"

# Auto-detect IPA if not provided
if [ -z "$IPA_PATH" ]; then
  IPA_PATH=$(find "$IPA_DIR" -type f -name "*.ipa" | head -n 1 || true)
fi

API_KEY_ID="${APP_STORE_CONNECT_API_KEY:-}"       # ✅ correct variable
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

# --- Save Private Key as JSON for Fastlane ---
KEY_DIR="$HOME/.appstoreconnect"
KEY_FILE="$KEY_DIR/api_key.json"

mkdir -p "$KEY_DIR"

echo "🔐 Writing App Store Connect API key JSON to: $KEY_FILE"

# Decode escaped \n into real newlines
PRIVATE_KEY=$(echo "$PRIVATE_KEY" | sed 's|\\n|\n|g')

cat > "$KEY_FILE" <<EOF
{
  "key_id": "$API_KEY_ID",
  "issuer_id": "$ISSUER_ID",
  "key": "$PRIVATE_KEY"
}
EOF

# Validate JSON
if ! jq -e . "$KEY_FILE" >/dev/null 2>&1; then
  echo "❌ Invalid JSON generated in $KEY_FILE"
  cat "$KEY_FILE"
  exit 1
fi

chmod 600 "$KEY_FILE"
echo "✅ API key JSON created."

# --- Upload with Fastlane ---
echo "📤 Uploading IPA to TestFlight via Fastlane Deliver..."

if fastlane deliver \
  --api_key_path "$KEY_FILE" \
  --ipa "$IPA_PATH" \
  --skip_metadata true \
  --skip_screenshots true \
  --force; then
  echo "✅ Successfully uploaded to App Store Connect!"
  echo "📲 Your build is now processing. Check TestFlight dashboard:"
  echo "👉 https://appstoreconnect.apple.com/apps"
else
  echo "❌ Upload failed! See error above."
  exit 1
fi

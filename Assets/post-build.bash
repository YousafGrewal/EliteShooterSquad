#!/bin/bash
set -e  # Exit on any error
set -u  # Fail if undefined variable is used

echo "🚀 Starting upload to App Store Connect..."

# --- CONFIGURATION ---
IPA_DIR="$WORKSPACE/.build/last"
IPA_PATH="${IPA_PATH:-$(find "$IPA_DIR" -name "*.ipa" -type f | head -n 1)}"

API_KEY_ID="${APP_STORE_CONNECT_API_KEY}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID}"
PRIVATE_KEY="${APP_STORE_CONNECT_PRIVATE_KEY}"

# --- VALIDATE REQUIRED VARIABLES ---
if [ -z "$API_KEY_ID" ] || [ -z "$ISSUER_ID" ] || [ -z "$PRIVATE_KEY" ]; then
  echo "❌ Missing required environment variables:"
  echo "   APP_STORE_CONNECT_API_KEY, APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_PRIVATE_KEY"
  exit 1
fi

# --- DEBUG: List files in .build/last (helps diagnose missing IPA)
echo "📁 Checking contents of $IPA_DIR:"
find "$IPA_DIR" -type f || echo "No files found in $IPA_DIR"

# --- VALIDATE IPA EXISTS ---
if [ -z "$IPA_PATH" ]; then
  echo "❌ No .ipa file found in $IPA_DIR"
  echo "💡 Tip: Make sure Unity is set to build an Archive (.ipa), not just .app"
  exit 1
fi

if [ ! -f "$IPA_PATH" ]; then
  echo "❌ IPA file does not exist: $IPA_PATH"
  exit 1
fi

echo "✅ IPA found: $IPA_PATH"
echo "📤 Uploading to TestFlight..."

# --- SAVE PRIVATE KEY TO TEMP FILE ---
PRIVATE_KEY_FILE=$(mktemp -t appstore-key.XXXXXX.p8)
trap 'rm -f "$PRIVATE_KEY_FILE"' EXIT

# Write private key (use printf to avoid echo interpretation issues)
if ! printf '%s' "$PRIVATE_KEY" > "$PRIVATE_KEY_FILE"; then
  echo "❌ Failed to write private key to file"
  exit 1
fi

chmod 600 "$PRIVATE_KEY_FILE"  # Secure permissions

# --- UPLOAD TO APP STORE CONNECT ---
echo "📦 Uploading... (this may take a few minutes)"

if xcrun altool --upload-app \
  --file "$IPA_PATH" \
  --type ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$ISSUER_ID"; then
  echo "✅ Successfully uploaded to App Store Connect!"
  echo "📲 Check TestFlight: https://appstoreconnect.apple.com/apps/-/testflight"
else
  echo "❌ Upload failed! Check error above."
  exit 1
fi

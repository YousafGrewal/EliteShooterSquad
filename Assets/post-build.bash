#!/bin/bash
set -e  # Exit immediately if a command fails
set -u  # Error on undefined variables

echo "🚀 Starting upload to App Store Connect..."

# --- Configuration ---
IPA_DIR="$WORKSPACE/.build/last"
IPA_PATH="${IPA_PATH:-$(find "$IPA_DIR" -name "*.ipa" -type f | head -n 1)}"

API_KEY_ID="${APP_STORE_CONNECT_API_KEY}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID}"
PRIVATE_KEY="${APP_STORE_CONNECT_PRIVATE_KEY}"

# --- Validate Required Secrets ---
if [ -z "$API_KEY_ID" ]; then
  echo "❌ Error: APP_STORE_CONNECT_API_KEY is missing!"
  exit 1
fi

if [ -z "$ISSUER_ID" ]; then
  echo "❌ Error: APP_STORE_CONNECT_ISSUER_ID is missing!"
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "❌ Error: APP_STORE_CONNECT_PRIVATE_KEY is missing!"
  exit 1
fi

# --- Debug: List files in build directory ---
echo "📁 Checking contents of $IPA_DIR:"
if [ -d "$IPA_DIR" ]; then
  find "$IPA_DIR" -type f -name "*.ipa" -o -name "*.app" | xargs ls -la
else
  echo "❌ Directory not found: $IPA_DIR"
  exit 1
fi

# --- Validate IPA File ---
if [ -z "$IPA_PATH" ]; then
  echo "❌ No .ipa file found in $IPA_DIR"
  echo "💡 Ensure Unity is set to 'Create IPA' and builds an Archive."
  exit 1
fi

if [ ! -f "$IPA_PATH" ]; then
  echo "❌ IPA file does not exist: $IPA_PATH"
  exit 1
fi

echo "✅ IPA found: $IPA_PATH"

# --- Save Private Key to Temp File ---
PRIVATE_KEY_FILE=$(mktemp -t authkey-XXXXXX.p8)
trap 'rm -f "$PRIVATE_KEY_FILE"' EXIT

# Write key with proper newline (handles \n escaped newlines)
echo "${PRIVATE_KEY//\\n/$'\n'}" > "$PRIVATE_KEY_FILE"

# Ensure file was written
if [ ! -s "$PRIVATE_KEY_FILE" ]; then
  echo "❌ Failed to write private key to $PRIVATE_KEY_FILE"
  exit 1
fi

chmod 600 "$PRIVATE_KEY_FILE"  # Secure permissions

echo "🔐 Private key saved to: $PRIVATE_KEY_FILE"

# Optional: Verify it's valid PEM (helps catch formatting issues)
if ! openssl pkcs8 -nocrypt -in "$PRIVATE_KEY_FILE" -out /dev/null 2>/dev/null; then
  echo "❌ Invalid private key format. Check your .p8 file content."
  exit 1
fi

# --- Upload to App Store Connect ---
echo "📤 Uploading IPA to TestFlight..."

if xcrun altool --upload-app \
  --file "$IPA_PATH" \
  --type ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$ISSUER_ID" \
  --apiKeyFile "$PRIVATE_KEY_FILE"; then
  echo "✅ Successfully uploaded to App Store Connect!"
  echo "📲 View in TestFlight: https://appstoreconnect.apple.com/apps/-/testflight"
else
  echo "❌ Upload failed! Check the error above."
  exit 1
fi

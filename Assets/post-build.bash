#!/bin/bash
set -euo pipefail

echo "🚀 Starting upload to App Store Connect..."

# --- Install Fastlane if not present ---
if ! command -v fastlane &> /dev/null; then
  echo "📦 Installing fastlane..."
  gem install fastlane --no-document
fi

# --- Configuration ---
IPA_DIR="${WORKSPACE:-$PWD}/.build/last"
IPA_PATH="${IPA_PATH:-}"

# Auto-detect IPA if not provided
if [ -z "$IPA_PATH" ]; then
  IPA_PATH=$(find "$IPA_DIR" -type f -name "*.ipa" | head -n 1 || true)
fi

# Load credentials from environment variables
API_KEY_ID="${APP_STORE_CONNECT_KEY_ID:-}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-}"
PRIVATE_KEY="${APP_STORE_CONNECT_PRIVATE_KEY:-}"  # Should contain \n for newlines

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
  echo "💡 Ensure your Unity or Xcode build produces an IPA archive."
  exit 1
fi

echo "✅ IPA found: $IPA_PATH"

# --- Prepare App Store Connect API Key JSON ---
KEY_DIR="$HOME/.appstoreconnect"
KEY_FILE="$KEY_DIR/api_key.json"
KEY_P8_FILE="$KEY_DIR/AuthKey.p8"

mkdir -p "$KEY_DIR"

echo "🔐 Preparing App Store Connect API key..."

# Convert escaped \n to actual newlines
PRIVATE_KEY_PROCESSED=$(echo -e "${PRIVATE_KEY}")

# Write the private key to a .p8 file (required by Fastlane/App Store Connect)
cat > "$KEY_P8_FILE" <<< "$PRIVATE_KEY_PROCESSED"

# Write JSON config for Fastlane (with embedded key)
cat > "$KEY_FILE" <<EOF
{
  "key_id": "$API_KEY_ID",
  "issuer_id": "$ISSUER_ID",
  "key": "$PRIVATE_KEY_PROCESSED"
}
EOF

# Validate JSON
if command -v jq &> /dev/null; then
  if ! jq -e . "$KEY_FILE" >/dev/null 2>&1; then
    echo "❌ Invalid JSON generated in $KEY_FILE"
    cat "$KEY_FILE"
    exit 1
  fi
  echo "✅ API key JSON is valid."
fi

# --- Validate Private Key Format ---
if command -v openssl &> /dev/null; then
  echo "🔑 Validating private key (PKCS#8 format)..."
  echo "$PRIVATE_KEY_PROCESSED" | openssl pkcs8 -noout -text 2>/dev/null || {
    echo "❌ Failed to parse private key. Is it a valid PKCS#8 EC key?"
    echo "📎 Common issues:"
    echo "   • The key is missing newlines (ensure \\n is used and processed with echo -e)"
    echo "   • Extra spaces or text around the key"
    echo "   • Using a certificate (.pem) instead of a .p8 private key"
    echo "   • Key was corrupted during copy-paste"
    echo ""
    echo "Preview of processed key:"
    echo "$PRIVATE_KEY_PROCESSED" | cat -A  # Show hidden chars
    exit 1
  }
  echo "✅ Private key validated successfully."
fi

chmod 600 "$KEY_P8_FILE"
chmod 600 "$KEY_FILE"
echo "✅ API key files created at: $KEY_P8_FILE and $KEY_FILE"

# --- Upload to App Store Connect ---
echo "📤 Uploading IPA to App Store Connect via Fastlane..."

if fastlane deliver \
  --api_key_path "$KEY_FILE" \
  --ipa "$IPA_PATH" \
  --skip_metadata true \
  --skip_screenshots true \
  --force; then

  echo "✅ Successfully uploaded to App Store Connect!"
  echo "📲 Your build is now processing. Check TestFlight:"
  echo "👉 https://appstoreconnect.apple.com/apps"

else
  echo "❌ Upload to App Store Connect failed!"
  echo "💡 Common causes:"
  echo "   • Invalid API key ID, issuer ID, or permissions"
  echo "   • Expired, malformed, or misformatted private key"
  echo "   • Network issues or Apple server outages"
  echo "   • Bundle ID mismatch or app not registered in App Store Connect"
  exit 1
fi

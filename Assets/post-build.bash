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

# Load credentials
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

# --- Prepare App Store Connect API Key (.p8 file) ---
KEY_DIR="$HOME/.appstoreconnect"
KEY_P8_FILE="$KEY_DIR/AuthKey.p8"

mkdir -p "$KEY_DIR"

echo "🔐 Preparing App Store Connect API key (.p8)..."

# Convert escaped \n to actual newlines
echo -e "${PRIVATE_KEY}" > "$KEY_P8_FILE"

# Verify file was created
if [ ! -f "$KEY_P8_FILE" ] || [ ! -s "$KEY_P8_FILE" ]; then
  echo "❌ Failed to write private key to $KEY_P8_FILE"
  exit 1
fi

echo "✅ Wrote API key to: $KEY_P8_FILE"

# --- Validate Private Key Format ---
if command -v openssl &> /dev/null; then
  echo "🔑 Validating private key (PKCS#8 format)..."
  if openssl pkcs8 -noout -text < "$KEY_P8_FILE" 2>/dev/null; then
    echo "✅ Private key is valid PKCS#8 format."
  else
    echo "❌ Failed to parse private key. Must be a valid PKCS#8 EC key."
    echo "📎 Common issues:"
    echo "   • The key is not from a .p8 file"
    echo "   • Extra text or spaces around the key"
    echo "   • Newlines not properly converted (\n not processed)"
    echo "   • Using a certificate instead of a private key"
    echo ""
    echo "📄 Preview of key file:"
    cat "$KEY_P8_FILE" | cat -A  # Show hidden characters
    exit 1
  fi
else
  echo "⚠️ Warning: 'openssl' not available. Skipping key validation."
fi

chmod 600 "$KEY_P8_FILE"
echo "🔒 Permissions set to 600 on $KEY_P8_FILE"

# --- Upload to App Store Connect ---
echo "📤 Uploading IPA to App Store Connect via Fastlane..."

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
  echo "📲 Your build is now processing. Check TestFlight:"
  echo "👉 https://appstoreconnect.apple.com/apps"

else
  echo "❌ Upload to App Store Connect failed!"
  echo "💡 Common causes:"
  echo "   • Invalid API key ID, issuer ID, or permissions"
  echo "   • Expired, malformed, or misformatted private key"
  echo "   • Network issues or Apple server errors"
  echo "   • Bundle ID does not match the app in App Store Connect"
  exit 1
fi

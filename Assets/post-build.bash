#!/bin/bash
set -e  # Exit on any error

echo "🚀 Starting upload to App Store Connect..."

# --- CONFIGURATION (Set via Environment Variables) ---
# These should be set in your CI as secrets
IPA_PATH="${IPA_PATH:-$WORKSPACE/.build/last/$TARGET_NAME/build.ipa}"
API_KEY_ID="${APP_STORE_CONNECT_API_KEY}"         # e.g., Z23FQSZ2D7
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID}"        # e.g., 78a9a50f-0660-4eaa-9a92-9299f1024190
PRIVATE_KEY="${APP_STORE_CONNECT_PRIVATE_KEY}"    # Full content of .p8 file

# Validate required variables
if [ -z "$API_KEY_ID" ] || [ -z "$ISSUER_ID" ] || [ -z "$PRIVATE_KEY" ]; then
  echo "❌ Missing required environment variables:"
  echo "   APP_STORE_CONNECT_API_KEY, APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_PRIVATE_KEY"
  exit 1
fi

# Check if IPA exists
if [ ! -f "$IPA_PATH" ]; then
  echo "❌ IPA file not found at: $IPA_PATH"
  echo "   Make sure your build generates an IPA."
  exit 1
fi

echo "✅ IPA found: $IPA_PATH"
echo "📤 Uploading to TestFlight..."

# Save private key to a temporary file (required by xcrun)
PRIVATE_KEY_FILE=$(mktemp -t appstore-keyXXXXXX.p8)
trap 'rm -f "$PRIVATE_KEY_FILE"' EXIT  # Auto cleanup

# Write private key content (preserving newlines)
echo "$PRIVATE_KEY" > "$PRIVATE_KEY_FILE"

# Use altool to upload
if xcrun altool --upload-app \
  --file "$IPA_PATH" \
  --type ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$ISSUER_ID"; then
  echo "✅ Successfully uploaded to App Store Connect!"
  echo "📲 Check TestFlight: https://appstoreconnect.apple.com/apps/-/testflight"
else
  echo "❌ Upload failed!"
  exit 1
fi

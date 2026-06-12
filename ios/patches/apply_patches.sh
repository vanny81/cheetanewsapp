#!/bin/bash

# Path to pub cache
PUB_CACHE="$HOME/.pub-cache"
PLUGIN_PATH="$PUB_CACHE/hosted/pub.dev/permission_handler_apple-9.4.7"

# Verify plugin exists
if [ ! -d "$PLUGIN_PATH" ]; then
  echo "Error: permission_handler_apple plugin not found at $PLUGIN_PATH"
  echo "Make sure you've run 'flutter pub get' first."
  exit 1
fi

# Apply patches
echo "Applying iOS permission handler patch for iOS 18 support..."
cp "$(dirname "$0")/permission_handler_apple/ContactPermissionStrategy.m" "$PLUGIN_PATH/ios/Classes/strategies/"

echo "Applying flutter_webrtc EXC_BAD_ACCESS fix patch..."
bash "$(dirname "$0")/apply_flutter_webrtc_patch.sh"

echo "All patches applied successfully!"

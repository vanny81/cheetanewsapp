#!/bin/bash

# Apply flutter_webrtc patch to fix EXC_BAD_ACCESS during logout
# This patch fixes the postEvent function to check for null sink

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🔧 Applying flutter_webrtc EXC_BAD_ACCESS fix patch..."

# Find flutter_webrtc in .pub-cache (prioritize the version actually being used)
FLUTTER_WEBRTC_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "flutter_webrtc-0.12.12*" -type d | head -1)
if [ -z "$FLUTTER_WEBRTC_PATH" ]; then
    # Fallback to any flutter_webrtc version
    FLUTTER_WEBRTC_PATH=$(find ~/.pub-cache/hosted/pub.dev -name "flutter_webrtc-*" -type d | head -1)
fi

if [ -z "$FLUTTER_WEBRTC_PATH" ]; then
    echo "❌ flutter_webrtc not found in .pub-cache"
    exit 1
fi

echo "📁 Found flutter_webrtc at: $FLUTTER_WEBRTC_PATH"

TARGET_FILE="$FLUTTER_WEBRTC_PATH/ios/Classes/FlutterWebRTCPlugin.m"
PATCH_FILE="$SCRIPT_DIR/flutter_webrtc/FlutterWebRTCPlugin.m.patch"

if [ ! -f "$TARGET_FILE" ]; then
    echo "❌ Target file not found: $TARGET_FILE"
    exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
    echo "❌ Patch file not found: $PATCH_FILE"
    exit 1
fi

# Check if already patched
if grep -q "Robust null safety checks to prevent EXC_BAD_ACCESS crashes" "$TARGET_FILE"; then
    echo "✅ Enhanced patch already applied"
    exit 0
elif grep -q "Check if sink is valid before dispatching" "$TARGET_FILE"; then
    echo "🔧 Old patch found, upgrading to enhanced version..."
    # Continue to apply enhanced patch
else
    echo "🔧 Applying enhanced patch..."
fi

# Create backup
cp "$TARGET_FILE" "$TARGET_FILE.backup"

# Apply patch manually since standard patch might not work with pub-cache
echo "🔧 Applying patch to $TARGET_FILE..."

# Use sed to replace the function with enhanced version
sed -i.orig '/void postEvent/,/^}/c\
void postEvent(FlutterEventSink _Nonnull sink, id _Nullable event) {\
    // Robust null safety checks to prevent EXC_BAD_ACCESS crashes\
    if (sink == nil) {\
        NSLog(@"[FlutterWebRTC] Warning: Attempted to post event to nil sink");\
        return;\
    }\
    \
    // Capture sink in a local variable to avoid race conditions\
    FlutterEventSink localSink = sink;\
    dispatch_async(dispatch_get_main_queue(), ^{\
        if (localSink != nil) {\
            localSink(event);\
        }\
    });\
}' "$TARGET_FILE"

# Verify patch was applied
if grep -q "Robust null safety checks to prevent EXC_BAD_ACCESS crashes" "$TARGET_FILE"; then
    echo "✅ Enhanced patch successfully applied to flutter_webrtc"
    echo "🔧 Fixed EXC_BAD_ACCESS issue during logout with enhanced protection"
else
    echo "❌ Failed to apply enhanced patch, restoring backup"
    cp "$TARGET_FILE.backup" "$TARGET_FILE"
    exit 1
fi

# Clean up temp files
rm -f /tmp/new_postEvent.m "$TARGET_FILE.orig"

echo "✅ flutter_webrtc patch complete"
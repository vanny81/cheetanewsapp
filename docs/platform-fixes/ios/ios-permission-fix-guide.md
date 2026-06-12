# iOS Contact Permission Fix for iOS 18

## Issue
When building the Flutter app for iOS 18, the permission_handler_apple plugin (v9.4.7) fails with:
- Error: `Use of undeclared identifier 'CNAuthorizationStatusLimited'`
- Error: `Duplicate case value 'CNAuthorizationStatusDenied'`

## Root Cause
iOS 18 introduced a new contacts permission status `CNAuthorizationStatusLimited`, but the permission_handler_apple plugin (v9.4.7) doesn't correctly handle this when compiled with Xcode versions that don't recognize this new enum value.

## Solution

### Option 1: Quick Fix (Patch the file directly)

1. Locate the problematic file in your pub cache:
```
~/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/ContactPermissionStrategy.m
```

2. Replace the `permissionStatus` method with the fixed version that uses conditional compilation:

```objective-c
+ (PermissionStatus)permissionStatus {
    if (@available(iOS 18.0, *)) {
        CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
        switch (status) {
            case CNAuthorizationStatusNotDetermined:
                return PermissionStatusDenied;
            case CNAuthorizationStatusRestricted:
                return PermissionStatusRestricted;
            case CNAuthorizationStatusDenied:
                return PermissionStatusPermanentlyDenied;
            case CNAuthorizationStatusAuthorized:
                return PermissionStatusGranted;
            #ifdef __IPHONE_18_0
            // Only include this case when the iOS 18 SDK is available
            case CNAuthorizationStatusLimited:
                return PermissionStatusLimited;
            #endif
            default:
                return PermissionStatusDenied;
        }
    } else {
        CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
        switch (status) {
            case CNAuthorizationStatusNotDetermined:
                return PermissionStatusDenied;
            case CNAuthorizationStatusRestricted:
                return PermissionStatusRestricted;
            case CNAuthorizationStatusDenied:
                return PermissionStatusPermanentlyDenied;
            case CNAuthorizationStatusAuthorized:
                return PermissionStatusGranted;
            default:
                return PermissionStatusDenied;
        }
    }
}
```

You can directly edit this file using:
```bash
open -e ~/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.7/ios/Classes/strategies/ContactPermissionStrategy.m
```

### Option 2: Setup a Patches System (Project with spaces in path)

For projects with spaces in the path (like "/Users/primocys/Flutter projects/rabtah_saj"), use the following commands:

1. Create the patches directory:
```bash
mkdir -p "/Users/primocys/Flutter projects/rabtah_saj/ios/patches/permission_handler_apple"
```

2. Create the fixed file:
```bash
touch "/Users/primocys/Flutter projects/rabtah_saj/ios/patches/permission_handler_apple/ContactPermissionStrategy.m"
```
   Then paste the complete fixed code into this file.

3. Create the script:
```bash
cat > "/Users/primocys/Flutter projects/rabtah_saj/ios/patches/apply_patches.sh" << 'EOF'
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

echo "Patches applied successfully!"
EOF
```

4. Make the script executable:
```bash
chmod +x "/Users/primocys/Flutter projects/rabtah_saj/ios/patches/apply_patches.sh"
```

5. Run the script:
```bash
"/Users/primocys/Flutter projects/rabtah_saj/ios/patches/apply_patches.sh"

# If you're already in the project directory
sh ios/patches/apply_patches.sh
```

For easier execution, you could add an alias to your .bash_profile or .zshrc:
```bash
alias fix-contacts-permission='"/Users/primocys/Flutter projects/rabtah_saj/ios/patches/apply_patches.sh"'
```

### Option 3: Use a Dependency Override (Most Flutter-like)

1. Create a fork of the permission_handler_apple plugin on GitHub

2. Apply the fix to your fork

3. In your `pubspec.yaml`, add a dependency override:

```yaml
dependency_overrides:
  permission_handler_apple:
    git:
      url: https://github.com/your-username/permission_handler_apple.git
      ref: fix-ios-18-limited-contacts
```

## Document This Fix For Your Team

Create a file called `IOS_FIXES.md` in your project's `docs` folder to document this issue and solution:
```bash
mkdir -p "/Users/primocys/Flutter projects/rabtah_saj/docs"
touch "/Users/primocys/Flutter projects/rabtah_saj/docs/IOS_FIXES.md"
```

Then add this documentation content to that file.

## Testing the Fix

1. After applying any of the above solutions, clean your project:
```bash
flutter clean
cd ios && pod install && cd ..
flutter pub get
```

2. If you used Option 2 or 3, run the patch script again after pub get:
```bash
"/Users/primocys/Flutter projects/rabtah_saj/ios/patches/apply_patches.sh"
```

3. Rebuild the iOS app:
```bash
flutter run
```

## Future-Proofing

- Check for newer versions of the plugin that might have this issue fixed
- Consider submitting a pull request to the original plugin with your fix

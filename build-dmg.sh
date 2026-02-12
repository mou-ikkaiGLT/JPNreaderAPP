#!/bin/bash
set -e

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/JPNReader-*/Build/Products/Release -name "JPNReader.app" -maxdepth 1 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: No Release build found. Build with Release configuration in Xcode first."
    exit 1
fi

echo "Found app at: $APP_PATH"

# Work on a copy so we don't modify the Xcode build output
STAGING="/tmp/JPNReader-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/JPNReader.app"
STAGED_APP="$STAGING/JPNReader.app"

# 1. Fix libtesseract framework structure for code signing
#    macOS requires: Versions/Current must be a symlink to A,
#    and root-level Resources/libtesseract must be symlinks into Versions/Current/
FRAMEWORK="$STAGED_APP/Contents/Frameworks/libtesseract.framework"
if [ -d "$FRAMEWORK" ]; then
    echo "Fixing framework structure..."

    # Ensure Versions/A exists with the actual content
    mkdir -p "$FRAMEWORK/Versions/A"

    # Move binary into Versions/A if it's only in Current
    if [ ! -f "$FRAMEWORK/Versions/A/libtesseract" ] && [ -f "$FRAMEWORK/Versions/Current/libtesseract" ]; then
        cp "$FRAMEWORK/Versions/Current/libtesseract" "$FRAMEWORK/Versions/A/libtesseract"
    fi

    # Move Resources into Versions/A if needed
    if [ -d "$FRAMEWORK/Versions/Current/Resources" ] && [ ! -d "$FRAMEWORK/Versions/A/Resources" ]; then
        cp -R "$FRAMEWORK/Versions/Current/Resources" "$FRAMEWORK/Versions/A/Resources"
    fi

    # Remove the real Current directory and replace with symlink
    rm -rf "$FRAMEWORK/Versions/Current"
    ln -sfn A "$FRAMEWORK/Versions/Current"

    # Remove real Resources dir at root and replace with symlink
    rm -rf "$FRAMEWORK/Resources"
    ln -sfn Versions/Current/Resources "$FRAMEWORK/Resources"

    # Ensure root libtesseract is a symlink
    rm -f "$FRAMEWORK/libtesseract"
    ln -sfn Versions/Current/libtesseract "$FRAMEWORK/libtesseract"

    # Remove any stale _CodeSignature
    rm -rf "$FRAMEWORK/Versions/A/_CodeSignature"

    echo "Signing framework..."
    codesign --force --sign - "$FRAMEWORK/Versions/A"
fi

# 2. Sign the main app bundle
echo "Signing app bundle..."
codesign --force --sign - "$STAGED_APP"

# 3. Verify
echo "Verifying signature..."
codesign --verify --verbose "$STAGED_APP"

# 4. Build DMG
echo "Creating DMG..."
DMG_DIR="/tmp/JPNReader-dmg"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$STAGED_APP" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

DMG_OUTPUT=~/Desktop/JPNReader.dmg
rm -f "$DMG_OUTPUT"
hdiutil create -volname "JPNReader" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_OUTPUT"

# Clean up
rm -rf "$STAGING" "$DMG_DIR"

echo ""
echo "Done! DMG created at: $DMG_OUTPUT"
echo ""
echo "Note: Recipients should right-click → Open on first launch."
echo "If they still get 'damaged' error, they can run:"
echo "  xattr -cr /Applications/JPNReader.app"

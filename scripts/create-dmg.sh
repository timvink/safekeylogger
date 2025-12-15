#!/bin/bash

# SafeKeylogger DMG Creation Script
# Usage: ./Scripts/create-dmg.sh

set -e

APP_NAME="SafeKeylogger"
VERSION="1.0.0"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

echo "🔨 Building ${APP_NAME}..."

# Navigate to project directory
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Clean previous builds
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build the app using Swift Package Manager
cd SafeKeylogger
swift build -c release

# Create app bundle structure
APP_BUNDLE="${PROJECT_ROOT}/${BUILD_DIR}/${APP_NAME}.app"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp .build/release/SafeKeylogger "${APP_BUNDLE}/Contents/MacOS/"

# Copy Info.plist
cp SafeKeylogger/Info.plist "${APP_BUNDLE}/Contents/"

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Create minimal entitlements (no sandbox)
cat > "${PROJECT_ROOT}/${BUILD_DIR}/entitlements.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
EOF

echo "✅ App bundle created at ${APP_BUNDLE}"

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
    echo "📦 Creating DMG with create-dmg..."

    cd "${PROJECT_ROOT}/${BUILD_DIR}"

    # Remove existing DMG
    rm -f "${DMG_NAME}"

    create-dmg \
        --volname "${VOLUME_NAME}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 185 \
        --app-drop-link 450 185 \
        "${DMG_NAME}" \
        "${APP_NAME}.app"

    echo "✅ DMG created: ${BUILD_DIR}/${DMG_NAME}"
else
    echo "📦 Creating DMG with hdiutil (basic)..."

    cd "${PROJECT_ROOT}/${BUILD_DIR}"

    # Create temporary directory for DMG contents
    DMG_TEMP="dmg-temp"
    rm -rf "${DMG_TEMP}"
    mkdir -p "${DMG_TEMP}"

    # Copy app to temp directory
    cp -R "${APP_NAME}.app" "${DMG_TEMP}/"

    # Create symlink to Applications
    ln -s /Applications "${DMG_TEMP}/Applications"

    # Create DMG
    rm -f "${DMG_NAME}"
    hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDZO "${DMG_NAME}"

    # Cleanup
    rm -rf "${DMG_TEMP}"

    echo "✅ DMG created: ${BUILD_DIR}/${DMG_NAME}"
    echo ""
    echo "💡 Tip: Install 'create-dmg' for a prettier DMG:"
    echo "   brew install create-dmg"
fi

echo ""
echo "📍 Output location: ${PROJECT_ROOT}/${BUILD_DIR}/${DMG_NAME}"
echo ""
echo "⚠️  Note: For distribution outside App Store, consider notarizing:"
echo "   xcrun notarytool submit ${BUILD_DIR}/${DMG_NAME} --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID"

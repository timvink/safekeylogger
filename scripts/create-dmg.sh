#!/bin/bash

# SafeKeylogger DMG Creation Script
# Usage: ./scripts/create-dmg.sh

set -e

APP_NAME="SafeKeylogger"
VERSION="1.1.0"
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

# Codesign the app with entitlements
ENTITLEMENTS_PATH="SafeKeylogger/SafeKeylogger.entitlements"
echo "🔏 Codesigning app..."

# Check if we have the development certificate (preserves permissions across rebuilds)
DEV_CERT="SafeKeylogger Development"
if security find-identity -v -p codesigning | grep -q "${DEV_CERT}"; then
    echo "   Using '${DEV_CERT}' certificate..."
    codesign --force --deep --sign "${DEV_CERT}" --entitlements "${ENTITLEMENTS_PATH}" "${APP_BUNDLE}"
else
    echo "   Using ad-hoc signing (run scripts/setup-dev-cert.sh to preserve permissions across rebuilds)..."
    codesign --force --deep --sign - --entitlements "${ENTITLEMENTS_PATH}" "${APP_BUNDLE}"
fi

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

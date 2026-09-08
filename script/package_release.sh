#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PROJECT="$ROOT_DIR/Grove.xcodeproj"
SCHEME="Grove"
BUILD_ROOT="$ROOT_DIR/build/ReleaseDerivedData"
APP_NAME="Grove"
EXECUTABLE_NAME="Grove"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
SOURCE_VERSION="$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Grove/GroveApp.swift")"
VERSION="${GROVE_VERSION:-$SOURCE_VERSION}"
BUILD_NUMBER="${GROVE_BUILD_NUMBER:?Set GROVE_BUILD_NUMBER to an increasing positive integer.}"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid build number." >&2; exit 1; }

if [[ -z "$SOURCE_VERSION" || "$VERSION" != "$SOURCE_VERSION" ]]; then
  echo "Release version must match Grove.version in Grove/GroveApp.swift." >&2
  exit 1
fi

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity.}"
: "${APPLE_ID:?Set APPLE_ID for notarization.}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID for notarization.}"
: "${NOTARYTOOL_PASSWORD:?Set NOTARYTOOL_PASSWORD for notarization.}"

rm -rf "$APP_BUNDLE" "$BUILD_ROOT" "$DIST_DIR/Grove-$VERSION.zip" "$DIST_DIR/SHA256SUMS"
mkdir -p "$DIST_DIR"

build_arch() {
  local arch="$1"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "platform=macOS,arch=$arch" \
    -derivedDataPath "$BUILD_ROOT/$arch" \
    -sdk macosx \
    ARCHS="$arch" \
    ONLY_ACTIVE_ARCH=YES \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGNING_ALLOWED=NO \
    build
}

build_arch arm64
ARM_APP="$BUILD_ROOT/arm64/Build/Products/Release/$APP_NAME.app"
ARM_BINARY="$ARM_APP/Contents/MacOS/$EXECUTABLE_NAME"

build_arch x86_64
X86_APP="$BUILD_ROOT/x86_64/Build/Products/Release/$APP_NAME.app"
X86_BINARY="$X86_APP/Contents/MacOS/$EXECUTABLE_NAME"

ditto "$ARM_APP" "$APP_BUNDLE"
lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$APP_BINARY"

# Sign nested Sparkle code from the inside out for hardened runtime.
SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
for component in \
  "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
  "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
  "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate" \
  "$SPARKLE_FRAMEWORK/Versions/B/Updater.app" \
  "$SPARKLE_FRAMEWORK"; do
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$component"
done
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

ZIP_PATH="$DIST_DIR/Grove-$VERSION.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$NOTARYTOOL_PASSWORD" \
  --wait
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
# Recreate the archive so the downloaded app includes the notarization ticket.
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

(cd "$DIST_DIR" && shasum -a 256 "Grove-$VERSION.zip" > SHA256SUMS)
bash "$ROOT_DIR/script/generate_appcast.sh" "$ZIP_PATH"
echo "Created $ZIP_PATH"

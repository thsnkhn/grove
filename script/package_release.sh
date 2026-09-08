#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Grove"
EXECUTABLE_NAME="grove"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
SOURCE_VERSION="$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Sources/Grove/main.swift")"
VERSION="${GROVE_VERSION:-$SOURCE_VERSION}"

if [[ -z "$SOURCE_VERSION" || "$VERSION" != "$SOURCE_VERSION" ]]; then
  echo "Release version must match Grove.version in Sources/Grove/main.swift." >&2
  exit 1
fi

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity.}"
: "${APPLE_ID:?Set APPLE_ID for notarization.}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID for notarization.}"
: "${NOTARYTOOL_PASSWORD:?Set NOTARYTOOL_PASSWORD for notarization.}"

rm -rf "$APP_BUNDLE" "$DIST_DIR/Grove-$VERSION.zip" "$DIST_DIR/SHA256SUMS"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

swift build -c release --arch arm64
ARM_BINARY="$(swift build -c release --arch arm64 --show-bin-path)/$EXECUTABLE_NAME"

swift build -c release --arch x86_64
X86_BINARY="$(swift build -c release --arch x86_64 --show-bin-path)/$EXECUTABLE_NAME"

lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$APP_BINARY"
cp "$ROOT_DIR/Support/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE_NAME" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$APP_BUNDLE/Contents/Info.plist"

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

shasum -a 256 "$ZIP_PATH" > "$DIST_DIR/SHA256SUMS"
echo "Created $ZIP_PATH"

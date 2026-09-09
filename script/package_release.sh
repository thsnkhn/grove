#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PROJECT="$ROOT_DIR/Grove.xcodeproj"
SCHEME="Grove"
BUILD_ROOT="$ROOT_DIR/build/ReleaseDerivedData"
APP_NAME="Grove"
EXECUTABLE_NAME="Grove"
APPLE_SILICON_APP_BUNDLE="$DIST_DIR/Grove-Apple-Silicon.app"
INTEL_APP_BUNDLE="$DIST_DIR/Grove-Intel.app"
APPLE_SILICON_DMG="$DIST_DIR/Grove-Apple-Silicon.dmg"
INTEL_DMG="$DIST_DIR/Grove-Intel.dmg"
SOURCE_VERSION="$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Grove/GroveApp.swift")"
VERSION="${GROVE_VERSION:-$SOURCE_VERSION}"
BUILD_NUMBER="${GROVE_BUILD_NUMBER:?Set GROVE_BUILD_NUMBER to an increasing positive integer.}"
WAIT_FOR_NOTARIZATION="${WAIT_FOR_NOTARIZATION:-YES}"
NOTARY_PROFILE="${NOTARY_PROFILE-}"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid build number." >&2; exit 1; }
[[ "$WAIT_FOR_NOTARIZATION" == "YES" || "$WAIT_FOR_NOTARIZATION" == "NO" ]] || {
  echo "WAIT_FOR_NOTARIZATION must be YES or NO." >&2
  exit 1
}

if [[ -z "$SOURCE_VERSION" || "$VERSION" != "$SOURCE_VERSION" ]]; then
  echo "Release version must match Grove.version in Grove/GroveApp.swift." >&2
  exit 1
fi

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity.}"

if [[ -n "$NOTARY_PROFILE" ]]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
else
  : "${APPLE_ID:?Set APPLE_ID for notarization when NOTARY_PROFILE is empty.}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID for notarization when NOTARY_PROFILE is empty.}"
  : "${NOTARYTOOL_PASSWORD:?Set NOTARYTOOL_PASSWORD for notarization when NOTARY_PROFILE is empty.}"
  NOTARY_ARGS=(
    --apple-id "$APPLE_ID"
    --team-id "$APPLE_TEAM_ID"
    --password "$NOTARYTOOL_PASSWORD"
  )
fi

APPLE_SILICON_RECORD="$DIST_DIR/notarization-apple-silicon.json"
INTEL_RECORD="$DIST_DIR/notarization-intel.json"

rm -rf \
  "$APPLE_SILICON_APP_BUNDLE" \
  "$INTEL_APP_BUNDLE" \
  "$BUILD_ROOT" \
  "$APPLE_SILICON_DMG" \
  "$INTEL_DMG" \
  "$DIST_DIR/SHA256SUMS" \
  "$APPLE_SILICON_RECORD" \
  "$INTEL_RECORD"
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

ditto "$ARM_APP" "$APPLE_SILICON_APP_BUNDLE"
ditto "$X86_APP" "$INTEL_APP_BUNDLE"

sign_app() {
  local app_bundle="$1"
  local sparkle_framework="$app_bundle/Contents/Frameworks/Sparkle.framework"

  # Sign nested Sparkle code from the inside out for hardened runtime.
  for component in \
    "$sparkle_framework/Versions/B/XPCServices/Downloader.xpc" \
    "$sparkle_framework/Versions/B/XPCServices/Installer.xpc" \
    "$sparkle_framework/Versions/B/Autoupdate" \
    "$sparkle_framework/Versions/B/Updater.app" \
    "$sparkle_framework"; do
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$component"
  done
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$app_bundle"
  codesign --verify --deep --strict "$app_bundle"
}

if ! lipo -archs "$APPLE_SILICON_APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" | grep -qw arm64; then
  echo "Apple silicon app does not contain an arm64 executable." >&2
  exit 1
fi
if ! lipo -archs "$INTEL_APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" | grep -qw x86_64; then
  echo "Intel app does not contain an x86_64 executable." >&2
  exit 1
fi
sign_app "$APPLE_SILICON_APP_BUNDLE"
sign_app "$INTEL_APP_BUNDLE"

bash "$ROOT_DIR/script/create_dmg.sh" "$APPLE_SILICON_APP_BUNDLE" "$APPLE_SILICON_DMG"
bash "$ROOT_DIR/script/create_dmg.sh" "$INTEL_APP_BUNDLE" "$INTEL_DMG"

submit_notarization() {
  local archive="$1"
  local record="$2"

  if [[ "$WAIT_FOR_NOTARIZATION" == "YES" ]]; then
    xcrun notarytool submit "$archive" "${NOTARY_ARGS[@]}" --wait
  else
    xcrun notarytool submit "$archive" "${NOTARY_ARGS[@]}" \
      --output-format json > "$record"
    echo "Notarization submitted for $(basename "$archive"). Request: $record"
  fi
}

submit_notarization "$APPLE_SILICON_DMG" "$APPLE_SILICON_RECORD"
submit_notarization "$INTEL_DMG" "$INTEL_RECORD"

if [[ "$WAIT_FOR_NOTARIZATION" == "NO" ]]; then
  echo "Notarization is pending. Run script/check_notarization.sh later."
  exit 0
fi

staple_app() {
  local app_bundle="$1"
  xcrun stapler staple "$app_bundle"
  xcrun stapler validate "$app_bundle"
}

staple_app "$APPLE_SILICON_APP_BUNDLE"
staple_app "$INTEL_APP_BUNDLE"

# Recreate each disk image so it contains the stapled app, then staple the image.
bash "$ROOT_DIR/script/create_dmg.sh" "$APPLE_SILICON_APP_BUNDLE" "$APPLE_SILICON_DMG"
bash "$ROOT_DIR/script/create_dmg.sh" "$INTEL_APP_BUNDLE" "$INTEL_DMG"
xcrun stapler staple "$APPLE_SILICON_DMG"
xcrun stapler validate "$APPLE_SILICON_DMG"
xcrun stapler staple "$INTEL_DMG"
xcrun stapler validate "$INTEL_DMG"

(cd "$DIST_DIR" && shasum -a 256 "Grove-Apple-Silicon.dmg" "Grove-Intel.dmg" > SHA256SUMS)
bash "$ROOT_DIR/script/generate_appcast.sh" "$APPLE_SILICON_DMG" appcast-arm64.xml
bash "$ROOT_DIR/script/generate_appcast.sh" "$INTEL_DMG" appcast-intel.xml
echo "Created $APPLE_SILICON_DMG"
echo "Created $INTEL_DMG"
echo "Created $DIST_DIR/appcast-arm64.xml"
echo "Created $DIST_DIR/appcast-intel.xml"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APPLE_SILICON_APP_BUNDLE="$DIST_DIR/Grove-Apple-Silicon.app"
INTEL_APP_BUNDLE="$DIST_DIR/Grove-Intel.app"
VERSION="$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Grove/GroveApp.swift")"
NOTARY_PROFILE="${NOTARY_PROFILE:-XCode Notary}"
APPLE_SILICON_ZIP="$DIST_DIR/Grove-Apple-Silicon.zip"
INTEL_ZIP="$DIST_DIR/Grove-Intel.zip"

for app_bundle in "$APPLE_SILICON_APP_BUNDLE" "$INTEL_APP_BUNDLE"; do
  [[ -d "$app_bundle" ]] || { echo "Prepared app not found: $app_bundle" >&2; exit 1; }
done

RECORDS=(
  "$DIST_DIR/notarization-apple-silicon.json"
  "$DIST_DIR/notarization-intel.json"
)

for record in "${RECORDS[@]}"; do
  [[ -f "$record" ]] || { echo "Notarization record not found: $record" >&2; exit 1; }

  SUBMISSION_ID="$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$record" | head -n 1)"
  [[ -n "$SUBMISSION_ID" ]] || { echo "No submission ID found in $record." >&2; exit 1; }

  STATUS_OUTPUT="$(xcrun notarytool info "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE")"
  printf '%s\n' "$STATUS_OUTPUT"

  if ! grep -q 'status: Accepted' <<< "$STATUS_OUTPUT"; then
    if grep -q 'status: Invalid' <<< "$STATUS_OUTPUT"; then
      echo "Apple rejected the notarization. Fetch the log with:" >&2
      echo "xcrun notarytool log $SUBMISSION_ID --keychain-profile \"$NOTARY_PROFILE\"" >&2
    else
      echo "Notarization is not accepted yet. Run this script again later." >&2
    fi
    exit 2
  fi
done

staple_app() {
  local app_bundle="$1"
  xcrun stapler staple "$app_bundle"
  xcrun stapler validate "$app_bundle"
}

staple_app "$APPLE_SILICON_APP_BUNDLE"
staple_app "$INTEL_APP_BUNDLE"

ditto -c -k --keepParent "$APPLE_SILICON_APP_BUNDLE" "$APPLE_SILICON_ZIP"
ditto -c -k --keepParent "$INTEL_APP_BUNDLE" "$INTEL_ZIP"
(cd "$DIST_DIR" && shasum -a 256 "Grove-Apple-Silicon.zip" "Grove-Intel.zip" > SHA256SUMS)
bash "$ROOT_DIR/script/generate_appcast.sh" "$APPLE_SILICON_ZIP" appcast-arm64.xml
bash "$ROOT_DIR/script/generate_appcast.sh" "$INTEL_ZIP" appcast-intel.xml

echo "Finalized notarized Grove $VERSION."
echo "Run PREPARED_RELEASE=YES script/release-sparkle.sh $VERSION <build> to publish it."

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Grove.app"
VERSION="$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Grove/GroveApp.swift")"
RECORD_PATH="${1:-$DIST_DIR/notarization.json}"
NOTARY_PROFILE="${NOTARY_PROFILE:-XCode Notary}"
ZIP_PATH="$DIST_DIR/Grove-$VERSION.zip"

[[ -d "$APP_BUNDLE" ]] || { echo "Prepared app not found: $APP_BUNDLE" >&2; exit 1; }
[[ -f "$RECORD_PATH" ]] || { echo "Notarization record not found: $RECORD_PATH" >&2; exit 1; }

SUBMISSION_ID="$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RECORD_PATH" | head -n 1)"
[[ -n "$SUBMISSION_ID" ]] || { echo "No submission ID found in $RECORD_PATH." >&2; exit 1; }

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

xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
(cd "$DIST_DIR" && shasum -a 256 "Grove-$VERSION.zip" > SHA256SUMS)
bash "$ROOT_DIR/script/generate_appcast.sh" "$ZIP_PATH"

echo "Finalized notarized Grove $VERSION."
echo "Run PREPARED_RELEASE=YES script/release-sparkle.sh $VERSION <build> to publish it."

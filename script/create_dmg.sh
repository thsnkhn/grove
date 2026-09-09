#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:?Pass the app bundle path.}"
DMG_PATH="${2:?Pass the output DMG path.}"
VOLUME_NAME="${3:-Grove}"
STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/grove-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_ROOT"' EXIT

[[ -d "$APP_BUNDLE" ]] || { echo "App bundle not found: $APP_BUNDLE" >&2; exit 1; }

mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
ditto "$APP_BUNDLE" "$STAGING_ROOT/Grove.app"
ln -s /Applications "$STAGING_ROOT/Applications"

# TODO: Add a custom Finder window layout if the installer needs more guidance.
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_ROOT" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG_PATH"
